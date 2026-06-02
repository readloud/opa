import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.module';
import { exec } from 'child_process';
import { promisify } from 'util';
import * as fs from 'fs';
import * as path from 'path';
import * as three from 'three';

const execAsync = promisify(exec);

@Injectable()
export class ThreeDModelService {
  private readonly logger = new Logger(ThreeDModelService.name);
  private readonly modelsDir = './storage/3d-models';

  constructor(private prisma: PrismaService) {
    if (!fs.existsSync(this.modelsDir)) {
      fs.mkdirSync(this.modelsDir, { recursive: true });
    }
  }

  async generate3DModel(missionId: string, imageUrls: string[]): Promise<string> {
    this.logger.log(`Generating 3D model for mission ${missionId}`);
    
    // In production, use ODM or Pix4D for 3D reconstruction
    // This is a simplified simulation
    
    const modelPath = path.join(this.modelsDir, `${missionId}.gltf`);
    
    // Simulate 3D reconstruction
    await this.simulate3DReconstruction(modelPath);
    
    // Generate contour lines from DEM
    const contourLines = await this.generateContourLines(modelPath);
    
    // Calculate terrain statistics
    const terrainStats = await this.calculateTerrainStatistics(modelPath);
    
    // Save model info to database
    await this.prisma.threeDModel.create({
      data: {
        droneMissionId: missionId,
        modelUrl: `/storage/3d-models/${missionId}.gltf`,
        thumbnailUrl: `/storage/3d-models/${missionId}.png`,
        contourLines,
        terrainStats,
        fileSize: fs.statSync(modelPath).size,
      },
    });
    
    return modelPath;
  }

  private async simulate3DReconstruction(outputPath: string): Promise<void> {
    // Create a simple 3D model (in production, use actual photogrammetry)
    const scene = new three.Scene();
    const camera = new three.PerspectiveCamera(75, 1, 0.1, 1000);
    const renderer = new three.WebGLRenderer();
    
    // Generate terrain mesh
    const geometry = new three.PlaneGeometry(100, 100, 100, 100);
    const material = new three.MeshStandardMaterial({ color: 0x8B5A2B, wireframe: false });
    const plane = new three.Mesh(geometry, material);
    
    // Add random elevation (simulate terrain)
    const positions = geometry.attributes.position.array;
    for (let i = 0; i < positions.length; i += 3) {
      const x = positions[i];
      const z = positions[i + 2];
      positions[i + 1] = Math.sin(x * 0.5) * Math.cos(z * 0.5) * 5 + Math.random() * 2;
    }
    
    geometry.computeVertexNormals();
    scene.add(plane);
    
    // Add camera and lights
    camera.position.set(50, 50, 50);
    camera.lookAt(0, 0, 0);
    
    const ambientLight = new three.AmbientLight(0x404040);
    scene.add(ambientLight);
    
    const directionalLight = new three.DirectionalLight(0xffffff, 1);
    directionalLight.position.set(1, 2, 1);
    scene.add(directionalLight);
    
    // Save as GLTF
    const gltfExporter = new (require('three/examples/jsm/exporters/GLTFExporter')).GLTFExporter();
    
    return new Promise((resolve) => {
      gltfExporter.parse(scene, (result) => {
        const output = typeof result === 'string' ? result : JSON.stringify(result);
        fs.writeFileSync(outputPath, output);
        resolve();
      });
    });
  }

  private async generateContourLines(modelPath: string): Promise<any[]> {
    // Generate contour lines from DEM
    const contours = [];
    const elevationLevels = [0, 5, 10, 15, 20, 25, 30, 35, 40];
    
    for (const level of elevationLevels) {
      contours.push({
        elevation: level,
        points: this.generateContourPoints(level),
        color: this.getContourColor(level),
      });
    }
    
    return contours;
  }

  private generateContourPoints(elevation: number): any[] {
    // Simulate contour points
    const points = [];
    for (let i = 0; i < 50; i++) {
      points.push({
        x: Math.random() * 100,
        y: elevation,
        z: Math.random() * 100,
      });
    }
    return points;
  }

  private getContourColor(elevation: number): string {
    if (elevation < 10) return '#8B5A2B'; // Low - Brown
    if (elevation < 20) return '#228B22'; // Medium - Green
    if (elevation < 30) return '#2E7D32'; // High - Dark Green
    return '#1B5E20'; // Very High - Very Dark Green
  }

  private async calculateTerrainStatistics(modelPath: string): Promise<any> {
    return {
      minElevation: 15.2,
      maxElevation: 42.8,
      averageElevation: 28.5,
      slopeDistribution: {
        flat: 25,
        gentle: 40,
        moderate: 25,
        steep: 10,
      },
      aspectDistribution: {
        north: 20,
        south: 25,
        east: 30,
        west: 25,
      },
    };
  }

  async get3DModel(missionId: string) {
    return this.prisma.threeDModel.findFirst({
      where: { droneMissionId: missionId },
    });
  }

  async getTerrainAnalysis(missionId: string) {
    const model = await this.get3DModel(missionId);
    if (!model) return null;
    
    return {
      contourLines: model.contourLines,
      terrainStats: model.terrainStats,
      suitabilityZones: this.calculateSuitabilityZones(model.terrainStats),
    };
  }

  private calculateSuitabilityZones(terrainStats: any): any {
    return {
      optimal: {
        area: 45.5,
        percentage: 45.5,
        conditions: 'Elevasi 20-30m, kemiringan 0-8%',
      },
      suitable: {
        area: 35.2,
        percentage: 35.2,
        conditions: 'Elevasi 15-20m atau 30-35m, kemiringan 8-15%',
      },
      marginal: {
        area: 14.8,
        percentage: 14.8,
        conditions: 'Elevasi <15m atau >35m, kemiringan 15-25%',
      },
      unsuitable: {
        area: 4.5,
        percentage: 4.5,
        conditions: 'Kemiringan >25%',
      },
    };
  }
}