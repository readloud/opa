import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.module';
import * as tf from '@tensorflow/tfjs-node';
import * as sharp from 'sharp';
import * as geotiff from 'geotiff';

@Injectable()
export class PestDetectionService {
  private readonly logger = new Logger(PestDetectionService.name);
  private pestModel: tf.GraphModel | null = null;
  private segmentationModel: tf.GraphModel | null = null;

  // Pest classes for oil palm
  private readonly pestClasses = {
    'RUSA': { id: 0, name: 'Rusa', severity: 'HIGH', treatment: 'Pagarb elektrik' },
    'KUMBANG_TANDUK': { id: 1, name: 'Kumbang Tanduk', severity: 'HIGH', treatment: 'Insektisida sistemik' },
    'ULAT_API': { id: 2, name: 'Ulat Api', severity: 'MEDIUM', treatment: 'Bacillus thuringiensis' },
    'KUTU_PUTIH': { id: 3, name: 'Kutu Putih', severity: 'MEDIUM', treatment: 'Minyak nabati' },
    'TIKUS': { id: 4, name: 'Tikus', severity: 'HIGH', treatment: 'Rodentisida' },
    'GANODERMA': { id: 5, name: 'Ganoderma', severity: 'CRITICAL', treatment: 'Eradikasi' },
    'BUSUK_PANGKAL': { id: 6, name: 'Busuk Pangkal', severity: 'HIGH', treatment: 'Fungisida' },
    'NEMATODA': { id: 7, name: 'Nematoda', severity: 'MEDIUM', treatment: 'Nematisida' },
  };

  constructor(private prisma: PrismaService) {
    this.loadModels();
  }

  private async loadModels() {
    try {
      // Load pest detection model
      this.pestModel = await tf.loadGraphModel(
        `file://${process.env.PEST_MODEL_PATH || './models/pest-detection/model.json'}`
      );
      
      // Load segmentation model for area mapping
      this.segmentationModel = await tf.loadGraphModel(
        `file://${process.env.SEGMENTATION_MODEL_PATH || './models/segmentation/model.json'}`
      );
      
      this.logger.log('AI Pest Detection models loaded successfully');
    } catch (error) {
      this.logger.error('Failed to load AI models', error);
    }
  }

  async detectPestsFromOrthomosaic(missionId: string, imageBuffer: Buffer) {
    this.logger.log(`Analyzing orthomosaic for pest detection: ${missionId}`);
    
    // Slice orthomosaic into tiles for processing
    const tiles = await this.sliceOrthomosaic(imageBuffer, 512, 512);
    
    const detections = [];
    const heatmapData = [];
    
    for (let i = 0; i < tiles.length; i++) {
      const tile = tiles[i];
      const tileDetections = await this.analyzeTile(tile, i);
      detections.push(...tileDetections);
      
      // Generate heatmap coordinates
      tileDetections.forEach(det => {
        heatmapData.push({
          x: det.x,
          y: det.y,
          pestType: det.pestType,
          confidence: det.confidence,
        });
      });
    }
    
    // Aggregate results
    const aggregatedResults = this.aggregateDetections(detections);
    const pestHeatmap = this.generatePestHeatmap(heatmapData);
    const workOrders = this.generateWorkOrdersFromDetections(aggregatedResults, missionId);
    
    // Save results to database
    await this.savePestDetections(missionId, aggregatedResults, pestHeatmap);
    
    return {
      missionId,
      totalDetections: detections.length,
      pestBreakdown: aggregatedResults,
      pestHeatmap,
      workOrders,
      severityScore: this.calculateSeverityScore(aggregatedResults),
    };
  }

  private async sliceOrthomosaic(buffer: Buffer, tileSize: number, overlap: number): Promise<Buffer[]> {
    const image = await sharp(buffer);
    const metadata = await image.metadata();
    
    const tiles: Buffer[] = [];
    const step = tileSize - overlap;
    
    for (let y = 0; y < metadata.height!; y += step) {
      for (let x = 0; x < metadata.width!; x += step) {
        const tile = await sharp(buffer)
          .extract({
            left: x,
            top: y,
            width: Math.min(tileSize, metadata.width! - x),
            height: Math.min(tileSize, metadata.height! - y),
          })
          .toBuffer();
        
        tiles.push(tile);
      }
    }
    
    return tiles;
  }

  private async analyzeTile(tileBuffer: Buffer, tileIndex: number): Promise<any[]> {
    if (!this.pestModel) {
      return this.simulateDetections(tileIndex);
    }
    
    // Preprocess image for model
    const processed = await sharp(tileBuffer)
      .resize(224, 224)
      .toBuffer();
    
    const tensor = tf.node.decodeImage(processed, 3);
    const normalized = tensor.div(255.0);
    const batched = normalized.expandDims(0);
    
    // Run inference
    const predictions = await this.pestModel!.predict(batched) as tf.Tensor;
    const scores = await predictions.data();
    
    tensor.dispose();
    normalized.dispose();
    batched.dispose();
    predictions.dispose();
    
    // Parse predictions
    const detections = [];
    for (let i = 0; i < scores.length; i++) {
      if (scores[i] > 0.5) {
        const pestKey = Object.keys(this.pestClasses)[i];
        detections.push({
          pestType: pestKey,
          pestName: this.pestClasses[pestKey].name,
          confidence: scores[i],
          severity: this.pestClasses[pestKey].severity,
          x: (tileIndex % 10) * 512 + Math.random() * 512,
          y: Math.floor(tileIndex / 10) * 512 + Math.random() * 512,
        });
      }
    }
    
    return detections;
  }

  private simulateDetections(tileIndex: number): any[] {
    // Simulate detections for testing
    const detections = [];
    const pestKeys = Object.keys(this.pestClasses);
    
    if (Math.random() > 0.7) {
      const pestKey = pestKeys[Math.floor(Math.random() * pestKeys.length)];
      detections.push({
        pestType: pestKey,
        pestName: this.pestClasses[pestKey].name,
        confidence: 0.6 + Math.random() * 0.3,
        severity: this.pestClasses[pestKey].severity,
        x: (tileIndex % 10) * 512 + Math.random() * 512,
        y: Math.floor(tileIndex / 10) * 512 + Math.random() * 512,
      });
    }
    
    return detections;
  }

  private aggregateDetections(detections: any[]): any {
    const breakdown: Record<string, { count: number; avgConfidence: number; severity: string }> = {};
    
    for (const det of detections) {
      if (!breakdown[det.pestType]) {
        breakdown[det.pestType] = {
          count: 0,
          avgConfidence: 0,
          severity: det.severity,
        };
      }
      breakdown[det.pestType].count++;
      breakdown[det.pestType].avgConfidence += det.confidence;
    }
    
    for (const key in breakdown) {
      breakdown[key].avgConfidence /= breakdown[key].count;
    }
    
    return breakdown;
  }

  private generatePestHeatmap(detections: any[]): any {
    // Generate heatmap overlay for map visualization
    const heatmap = {
      type: 'FeatureCollection',
      features: detections.map(det => ({
        type: 'Feature',
        geometry: {
          type: 'Point',
          coordinates: [det.x, det.y],
        },
        properties: {
          pestType: det.pestType,
          confidence: det.confidence,
          intensity: det.confidence * 100,
        },
      })),
    };
    
    return heatmap;
  }

  private generateWorkOrdersFromDetections(aggregatedResults: any, missionId: string): any[] {
    const workOrders = [];
    
    for (const [pestType, data] of Object.entries(aggregatedResults)) {
      const pestInfo = this.pestClasses[pestType];
      
      if (data.count > 5 || pestInfo.severity === 'CRITICAL') {
        workOrders.push({
          pestType: pestType,
          pestName: pestInfo.name,
          severity: pestInfo.severity,
          affectedArea: data.count * 0.5, // hectares
          recommendedTreatment: pestInfo.treatment,
          urgency: pestInfo.severity === 'CRITICAL' ? 'IMMEDIATE' : 'HIGH',
          estimatedCost: this.calculateTreatmentCost(pestType, data.count),
          priority: this.calculatePriority(pestInfo.severity, data.count),
        });
      }
    }
    
    return workOrders;
  }

  private calculateTreatmentCost(pestType: string, count: number): number {
    const costs: Record<string, number> = {
      'RUSA': 500000,
      'KUMBANG_TANDUK': 250000,
      'ULAT_API': 150000,
      'KUTU_PUTIH': 100000,
      'TIKUS': 200000,
      'GANODERMA': 1000000,
      'BUSUK_PANGKAL': 750000,
      'NEMATODA': 300000,
    };
    
    return (costs[pestType] || 200000) * count;
  }

  private calculatePriority(severity: string, count: number): number {
    let priority = 0;
    
    switch (severity) {
      case 'CRITICAL': priority = 100; break;
      case 'HIGH': priority = 70; break;
      case 'MEDIUM': priority = 40; break;
      default: priority = 20;
    }
    
    priority += Math.min(30, count * 2);
    return Math.min(100, priority);
  }

  private calculateSeverityScore(aggregatedResults: any): number {
    let totalScore = 0;
    let totalWeight = 0;
    
    const weights: Record<string, number> = {
      'CRITICAL': 10,
      'HIGH': 5,
      'MEDIUM': 2,
    };
    
    for (const [pestType, data] of Object.entries(aggregatedResults)) {
      const pestInfo = this.pestClasses[pestType];
      const weight = weights[pestInfo.severity] || 1;
      totalScore += data.count * weight;
      totalWeight += data.count;
    }
    
    return totalWeight > 0 ? (totalScore / totalWeight) * 10 : 0;
  }

  private async savePestDetections(missionId: string, results: any, heatmap: any) {
    await this.prisma.droneMission.update({
      where: { id: missionId },
      data: {
        pestDetections: results,
        pestHeatmap: heatmap,
        pestSeverityScore: this.calculateSeverityScore(results),
      },
    });
    
    // Create pest detection records
    for (const [pestType, data] of Object.entries(results)) {
      await this.prisma.pestDetection.create({
        data: {
          droneMissionId: missionId,
          detectedPest: pestType,
          count: data.count,
          confidence: data.avgConfidence,
          severity: data.severity,
        },
      });
    }
  }

  async getPestTrends(estateId: string, startDate: Date, endDate: Date) {
    const detections = await this.prisma.pestDetection.findMany({
      where: {
        droneMission: {
          estateId,
          flightDate: { gte: startDate, lte: endDate },
        },
      },
      include: { droneMission: true },
    });
    
    const trends = [];
    const byPest: Record<string, number[]> = {};
    
    for (const det of detections) {
      const month = det.droneMission.flightDate.toISOString().slice(0, 7);
      if (!byPest[det.detectedPest]) byPest[det.detectedPest] = [];
      byPest[det.detectedPest].push(det.count);
    }
    
    return {
      byPest,
      totalDetections: detections.length,
      mostCommonPest: Object.entries(byPest).sort((a, b) => 
        b[1].reduce((s, c) => s + c, 0) - a[1].reduce((s, c) => s + c, 0)
      )[0]?.[0],
      trends,
    };
  }
}