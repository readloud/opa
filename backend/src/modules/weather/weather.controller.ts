import { Controller, Get, Query, UseGuards, Param } from '@nestjs/common';
import { WeatherService } from './weather.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('weather')
@UseGuards(JwtAuthGuard)
export class WeatherController {
  constructor(private readonly weatherService: WeatherService) {}

  @Get('current')
  async getCurrentWeather(
    @Query('lat') lat: string,
    @Query('lon') lon: string,
  ) {
    return this.weatherService.getCurrentWeather(parseFloat(lat), parseFloat(lon));
  }

  @Get('forecast')
  async getForecast(
    @Query('lat') lat: string,
    @Query('lon') lon: string,
    @Query('days') days: string,
  ) {
    return this.weatherService.getForecast(
      parseFloat(lat),
      parseFloat(lon),
      days ? parseInt(days) : 7,
    );
  }

  @Get('predict-yield')
  async predictHarvestYield(
    @CurrentUser() user: any,
    @Query('estateId') estateId: string,
    @Query('blockId') blockId?: string,
  ) {
    return this.weatherService.predictHarvestYield(
      estateId || user.estateId,
      blockId,
    );
  }

  @Get('alerts')
  async getWeatherAlerts(@CurrentUser() user: any) {
    return this.weatherService.getWeatherAlert(user.estateId);
  }

  @Post('sync/:estateId')
  async syncWeatherData(
    @Param('estateId') estateId: string,
    @Query('lat') lat: string,
    @Query('lon') lon: string,
  ) {
    return this.weatherService.saveWeatherData(estateId, parseFloat(lat), parseFloat(lon));
  }
}