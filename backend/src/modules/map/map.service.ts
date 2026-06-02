import { Injectable, StreamableFile } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';

@Injectable()
export class MapService {
  private tileCacheDir = './tile-cache';

  constructor(private prisma: PrismaService) {
    if (!fs.existsSync(this.tileCacheDir)) {
      fs.mkdirSync(this.tileCacheDir, { recursive: true });
    }
  }

  async getGeojsonData(estateId: string): Promise<any> {
    const blocks = await this.prisma.block.findMany({
      where: { estateId },
      select: {
        id: true,
        name: true,
        area: true,
        geometry: true,
        palmCount: true,
      },
    });

    const features = blocks
      .filter(block => block.geometry)
      .map(block => ({
        type: 'Feature',
        geometry: block.geometry,
        properties: {
          id: block.id,
          name: block.name,
          area: block.area,
          palmCount: block.palmCount,
        },
      }));

    return {
      type: 'FeatureCollection',
      features,
    };
  }

  async getOfflinePackage(estateId: string, bounds: any) {
    const geojson = await this.getGeojsonData(estateId);
    const boundsStr = `${bounds.minLng},${bounds.minLat},${bounds.maxLng},${bounds.maxLat}`;
    const hash = crypto.createHash('md5').update(`${estateId}-${boundsStr}`).digest('hex');
    const packagePath = path.join(this.tileCacheDir, `${hash}.json`);
    
    // Check if package already exists
    if (fs.existsSync(packagePath)) {
      const data = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
      return data;
    }
    
    // Generate offline package
    const offlinePackage = {
      version: '1.0',
      generatedAt: new Date().toISOString(),
      estateId,
      bounds,
      geojson,
      tiles: [], // Would fetch actual tiles from tile server
    };
    
    fs.writeFileSync(packagePath, JSON.stringify(offlinePackage));
    return offlinePackage;
  }

  async saveOfflineMapData(estateId: string, data: any) {
    const filePath = path.join(this.tileCacheDir, `${estateId}_offline.json`);
    fs.writeFileSync(filePath, JSON.stringify(data));
    return { success: true, path: filePath };
  }
}