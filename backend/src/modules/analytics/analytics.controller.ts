import { Controller, Get, Query, UseGuards, Req } from '@nestjs/common';
import { AnalyticsService } from './analytics.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@Controller('analytics')
@UseGuards(JwtAuthGuard)
export class AnalyticsController {
  constructor(private readonly analyticsService: AnalyticsService) {}

  @Get('dashboard')
  async getDashboardStats(
    @Req() req,
    @Query('estateId') estateId: string,
    @Query('startDate') startDate: string,
    @Query('endDate') endDate: string,
  ) {
    // If no estateId, get user's estate
    if (!estateId && req.user.estateId) {
      estateId = req.user.estateId;
    }
    
    return this.analyticsService.getDashboardStats(
      estateId,
      new Date(startDate),
      new Date(endDate),
    );
  }

  @Get('realtime')
  async getRealtimeStats(@Req() req, @Query('estateId') estateId: string) {
    if (!estateId && req.user.estateId) {
      estateId = req.user.estateId;
    }
    return this.analyticsService.getRealtimeStats(estateId);
  }
}