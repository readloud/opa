import { Controller, Get, Query, UseGuards, Post, Body } from '@nestjs/common';
import { MapService } from './map.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@Controller('map')
@UseGuards(JwtAuthGuard)
export class MapController {
  constructor(private readonly mapService: MapService) {}

  @Get('geojson')
  async getGeojson(@Query('estateId') estateId: string) {
    return this.mapService.getGeojsonData(estateId);
  }

  @Get('offline-package')
  async getOfflinePackage(
    @Query('estateId') estateId: string,
    @Query('minLat') minLat: string,
    @Query('minLng') minLng: string,
    @Query('maxLat') maxLat: string,
    @Query('maxLng') maxLng: string,
  ) {
    const bounds = {
      minLat: parseFloat(minLat),
      minLng: parseFloat(minLng),
      maxLat: parseFloat(maxLat),
      maxLng: parseFloat(maxLng),
    };
    return this.mapService.getOfflinePackage(estateId, bounds);
  }

  @Post('save-offline')
  async saveOfflineMapData(
    @Body('estateId') estateId: string,
    @Body('data') data: any,
  ) {
    return this.mapService.saveOfflineMapData(estateId, data);
  }
}