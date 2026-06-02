import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.module';
import { StorageService } from '../storage/storage.service';
import { createCanvas, loadImage } from 'canvas';
import * as sharp from 'sharp';
import * as geotiff from 'geotiff';
import * as fs from 'fs';
import * as path from 'path';
import axios from 'axios';

@Injectable()
export class DroneService {
  private readonly logger = new Logger(DroneService.name);
  private readonly orthoDir = './storage/orthomosaic';

  constructor(
    private prisma: PrismaService,
    private storageService: StorageService,
  ) {
    if (!fs.existsSync(this.orthoDir)) {
      fs.mkdirSync(this.orthoDir, { recursive: true });
    }
  }

  async uploadDroneImagery(
    files: Express.Multer.File[],
    estateId: string,
    flightData: any,
  ) {
    const mission = await this.prisma.droneMission.create({
      data: {
        estateId,
        flightDate: new Date(flightData.flightDate),
        altitude: flightData.altitude,
        areaCovered: flightData.areaCovered,
        imageCount: files.length,
        status: 'PROCESSING',
        metadata: flightData.metadata || {},
      },
    });

    // Upload images to S3
    const imageUrls = [];
    for (const file of files) {
      const url = await this.storageService.uploadImage(
        file,
        `drone/${estateId}/${mission.id}`,
        'system',
      );
      imageUrls.push(url);
    }

    await this.prisma.droneMission.update({
      where: { id: mission.id },
      data: {
        imageUrls,
        status: 'UPLOADED',
      },
    });

    // Trigger async processing
    this.processOrthomosaic(mission.id, imageUrls, flightData).catch(err => {
      this.logger.error(`Orthomosaic processing failed: ${err}`);
    });

    return mission;
  }

  async processOrthomosaic(missionId: string, imageUrls: string[], flightData: any) {
    this.logger.log(`Processing orthomosaic for mission ${missionId}`);
    
    await this.prisma.droneMission.update({
      where: { id: missionId },
      data: { status: 'PROCESSING_ORTHO' },
    });

    try {
      // In production, this would call an external service like DroneDeploy, Pix4D, or ODM
      // For demonstration, we'll simulate processing
      
      const orthomosaicPath = await this.generateOrthomosaic(imageUrls, missionId);
      const ndviPath = await this.generateNDVI(orthomosaicPath);
      const healthMap = await this.analyzeVegetationHealth(orthomosaicPath);
      
      // Upload processed files
      const orthoUrl = await this.storageService.uploadImage(
        { buffer: fs.readFileSync(orthomosaicPath), mimetype: 'image/tiff' } as any,
        `drone/${missionId}/orthomosaic`,
        'system',
      );
      
      const ndviUrl = await this.storageService.uploadImage(
        { buffer: fs.readFileSync(ndviPath), mimetype: 'image/png' } as any,
        `drone/${missionId}/ndvi`,
        'system',
      );
      
      // Calculate statistics
      const statistics = await this.calculateFieldStatistics(healthMap);
      
      await this.prisma.droneMission.update({
        where: { id: missionId },
        data: {
          orthomosaicUrl: orthoUrl,
          ndviUrl: ndviUrl,
          statistics,
          status: 'COMPLETED',
          completedAt: new Date(),
        },
      });
      
      // Trigger automatic analysis
      await this.analyzeMissionResults(missionId, healthMap);
      
    } catch (error) {
      this.logger.error(`Orthomosaic processing failed: ${error}`);
      await this.prisma.droneMission.update({
        where: { id: missionId },
        data: {
          status: 'FAILED',
          errorMessage: error.message,
        },
      });
    }
  }

  private async generateOrthomosaic(imageUrls: string[], missionId: string): Promise<string> {
    // In production, use actual photogrammetry software
    // This is a simplified simulation
    
    const outputPath = path.join(this.orthoDir, `${missionId}_ortho.tiff`);
    
    // Simulate processing time
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    // Create a dummy orthomosaic (in production, this would be real)
    const canvas = createCanvas(2000, 2000);
    const ctx = canvas.getContext('2d');
    
    // Draw simulated field pattern
    ctx.fillStyle = '#8B5A2B';
    ctx.fillRect(0, 0, 2000, 2000);
    
    // Draw simulated vegetation
    for (let i = 0; i < 500; i++) {
      ctx.fillStyle = `rgba(76, 175, 80, ${0.3 + Math.random() * 0.5})`;
      ctx.beginPath();
      ctx.arc(
        Math.random() * 2000,
        Math.random() * 2000,
        20 + Math.random() * 50,
        0,
        Math.PI * 2,
      );
      ctx.fill();
    }
    
    const buffer = canvas.toBuffer('image/png');
    fs.writeFileSync(outputPath, buffer);
    
    return outputPath;
  }

  private async generateNDVI(orthomosaicPath: string): Promise<string> {
    // Generate NDVI (Normalized Difference Vegetation Index)
    // NDVI = (NIR - Red) / (NIR + Red)
    
    const outputPath = orthomosaicPath.replace('.tiff', '_ndvi.png');
    
    const canvas = createCanvas(2000, 2000);
    const ctx = canvas.getContext('2d');
    
    // Create NDVI heatmap
    for (let x = 0; x < 2000; x += 10) {
      for (let y = 0; y < 2000; y += 10) {
        // Simulate NDVI value (healthy vegetation = high NDVI)
        const ndviValue = 0.2 + Math.random() * 0.6;
        const color = this.getNDVIColor(ndviValue);
        
        ctx.fillStyle = color;
        ctx.fillRect(x, y, 10, 10);
      }
    }
    
    const buffer = canvas.toBuffer('image/png');
    fs.writeFileSync(outputPath, buffer);
    
    return outputPath;
  }

  private getNDVIColor(ndvi: number): string {
    if (ndvi > 0.6) return '#006400'; // Dark green - very healthy
    if (ndvi > 0.4) return '#228B22'; // Forest green - healthy
    if (ndvi > 0.2) return '#7CFC00'; // Lawn green - moderate
    if (ndvi > 0) return '#FFFF00'; // Yellow - stressed
    if (ndvi > -0.2) return '#FFA500'; // Orange - unhealthy
    return '#FF0000'; // Red - dead/barren
  }

  private async analyzeVegetationHealth(orthomosaicPath: string): Promise<any> {
    // Analyze vegetation health from orthomosaic
    const healthZones = {
      healthy: 0,
      moderate: 0,
      stressed: 0,
      unhealthy: 0,
      dead: 0,
    };
    
    // Simulate analysis
    for (let i = 0; i < 10000; i++) {
      const ndvi = Math.random();
      if (ndvi > 0.6) healthZones.healthy++;
      else if (ndvi > 0.4) healthZones.moderate++;
      else if (ndvi > 0.2) healthZones.stressed++;
      else if (ndvi > 0) healthZones.unhealthy++;
      else healthZones.dead++;
    }
    
    const total = Object.values(healthZones).reduce((a, b) => a + b, 0);
    
    return {
      zones: healthZones,
      percentages: {
        healthy: (healthZones.healthy / total * 100).toFixed(1),
        moderate: (healthZones.moderate / total * 100).toFixed(1),
        stressed: (healthZones.stressed / total * 100).toFixed(1),
        unhealthy: (healthZones.unhealthy / total * 100).toFixed(1),
        dead: (healthZones.dead / total * 100).toFixed(1),
      },
      overallHealthScore: (healthZones.healthy / total * 100) + 
                          (healthZones.moderate / total * 50),
    };
  }

  private async calculateFieldStatistics(healthMap: any) {
    return {
      totalArea: 100, // hectares
      analyzedArea: 95.5,
      healthyArea: healthMap.zones.healthy * 100 / 10000,
      interventionRequired: healthMap.zones.stressed + healthMap.zones.unhealthy + healthMap.zones.dead,
      timestamp: new Date(),
    };
  }

  private async analyzeMissionResults(missionId: string, healthMap: any) {
    const mission = await this.prisma.droneMission.findUnique({
      where: { id: missionId },
      include: { estate: true },
    });
    
    // Create alerts for problem areas
    if (healthMap.zones.unhealthy > 100 || healthMap.zones.dead > 50) {
      await this.prisma.alert.create({
        data: {
          estateId: mission.estateId,
          type: 'DRONE_DETECTED_ISSUE',
          severity: 'HIGH',
          message: `Drone mission ${missionId} detected significant unhealthy areas (${healthMap.zones.unhealthy + healthMap.zones.dead} sqm)`,
          data: { missionId, healthMap },
        },
      });
    }
    
    // Generate work orders for problem areas
    if (healthMap.zones.stressed > 200) {
      await this.prisma.task.create({
        data: {
          title: 'Drone-Detected Stress Area Inspection',
          description: `Stressed vegetation detected in mission ${missionId}. Requires ground inspection.`,
          type: 'INSPECTION',
          blockId: mission.estate.blocks[0]?.id,
          assignedTo: mission.estate.supervisorId,
          assignedBy: 'system',
          dueDate: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
        },
      });
    }
  }

  async getMissionResults(missionId: string) {
    const mission = await this.prisma.droneMission.findUnique({
      where: { id: missionId },
      include: {
        estate: {
          include: {
            blocks: true,
          },
        },
      },
    });
    
    if (!mission) {
      throw new NotFoundException('Mission not found');
    }
    
    return mission;
  }

  async getEstateMissions(estateId: string, limit = 10, offset = 0) {
    return this.prisma.droneMission.findMany({
      where: { estateId },
      orderBy: { flightDate: 'desc' },
      take: limit,
      skip: offset,
      include: {
        estate: true,
      },
    });
  }

  async compareMissions(missionId1: string, missionId2: string) {
    const mission1 = await this.getMissionResults(missionId1);
    const mission2 = await this.getMissionResults(missionId2);
    
    return {
      mission1: {
        date: mission1.flightDate,
        healthScore: mission1.statistics?.overallHealthScore,
        healthyArea: mission1.statistics?.healthyArea,
      },
      mission2: {
        date: mission2.flightDate,
        healthScore: mission2.statistics?.overallHealthScore,
        healthyArea: mission2.statistics?.healthyArea,
      },
      change: {
        healthScore: (mission2.statistics?.overallHealthScore || 0) - (mission1.statistics?.overallHealthScore || 0),
        healthyArea: (mission2.statistics?.healthyArea || 0) - (mission1.statistics?.healthyArea || 0),
      },
    };
  }

  async autoScheduleMission(estateId: string) {
    // Auto-schedule drone missions based on:
    // 1. Time since last mission (weekly/bi-weekly)
    // 2. Weather forecast (clear sky needed)
    // 3. Crop growth stage
    
    const lastMission = await this.prisma.droneMission.findFirst({
      where: { estateId },
      orderBy: { flightDate: 'desc' },
    });
    
    const daysSinceLastMission = lastMission
      ? (Date.now() - lastMission.flightDate.getTime()) / (1000 * 3600 * 24)
      : 999;
    
    if (daysSinceLastMission > 14) {
      // Create scheduled mission
      const scheduledMission = await this.prisma.droneMission.create({
        data: {
          estateId,
          flightDate: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
          status: 'SCHEDULED',
          metadata: {
            autoScheduled: true,
            reason: 'Regular monitoring',
          },
        },
      });
      
      return scheduledMission;
    }
    
    return null;
  }

  async processThermalImagery(files: Express.Multer.File[], missionId: string) {
    // Process thermal imagery for water stress detection
    const thermalData = [];
    
    for (const file of files) {
      // Analyze thermal image for temperature anomalies
      const temperatureMap = await this.analyzeThermalImage(file.buffer);
      thermalData.push(temperatureMap);
    }
    
    // Identify water-stressed areas
    const waterStressZones = this.identifyWaterStress(thermalData);
    
    await this.prisma.droneMission.update({
      where: { id: missionId },
      data: {
        thermalData: thermalData,
        waterStressZones,
      },
    });
    
    return { waterStressZones };
  }

  private async analyzeThermalImage(buffer: Buffer): Promise<any> {
    // In production, use thermal analysis algorithms
    // This is a simplified version
    return {
      minTemp: 22 + Math.random() * 5,
      maxTemp: 35 + Math.random() * 8,
      avgTemp: 28 + Math.random() * 6,
      hotspots: Array.from({ length: Math.floor(Math.random() * 10) }, () => ({
        x: Math.random() * 100,
        y: Math.random() * 100,
        temperature: 35 + Math.random() * 10,
      })),
    };
  }

  private identifyWaterStress(thermalData: any[]): any {
    // Identify areas with high temperature (indicating water stress)
    const stressZones = [];
    
    for (const data of thermalData) {
      for (const hotspot of data.hotspots) {
        if (hotspot.temperature > 40) {
          stressZones.push({
            location: { x: hotspot.x, y: hotspot.y },
            severity: hotspot.temperature > 45 ? 'HIGH' : 'MEDIUM',
            temperature: hotspot.temperature,
          });
        }
      }
    }
    
    return stressZones;
  }

  async generateReport(missionId: string) {
    const mission = await this.getMissionResults(missionId);
    const statistics = mission.statistics;
    
    const report = {
      missionId: mission.id,
      flightDate: mission.flightDate,
      areaCovered: mission.areaCovered,
      imageCount: mission.imageCount,
      healthSummary: statistics,
      recommendations: [],
    };
    
    // Generate recommendations based on findings
    if (statistics?.percentages?.stressed > 20) {
      report.recommendations.push({
        type: 'FERTILIZATION',
        priority: 'HIGH',
        message: 'Large stressed areas detected. Consider additional fertilization.',
      });
    }
    
    if (statistics?.percentages?.unhealthy > 10) {
      report.recommendations.push({
        type: 'PEST_CONTROL',
        priority: 'URGENT',
        message: 'Unhealthy vegetation detected. Immediate pest inspection recommended.',
      });
    }
    
    if (statistics?.percentages?.dead > 5) {
      report.recommendations.push({
        type: 'REPLANTING',
        priority: 'HIGH',
        message: 'Dead zones detected. Plan for replanting.',
      });
    }
    
    return report;
  }
}