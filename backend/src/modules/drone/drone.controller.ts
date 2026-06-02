import {
  Controller,
  Post,
  Get,
  Param,
  Query,
  UseInterceptors,
  UploadedFiles,
  Body,
  UseGuards,
  StreamableFile,
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { DroneService } from './drone.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('drone')
@UseGuards(JwtAuthGuard, RolesGuard)
export class DroneController {
  constructor(private readonly droneService: DroneService) {}

  @Post('upload')
  @Roles('ADMIN', 'SUPERVISOR')
  @UseInterceptors(FilesInterceptor('images', 100))
  async uploadDroneImagery(
    @UploadedFiles() files: Express.Multer.File[],
    @Body() flightData: any,
    @CurrentUser() user: any,
  ) {
    return this.droneService.uploadDroneImagery(files, user.estateId, flightData);
  }

  @Post('thermal')
  @Roles('ADMIN', 'SUPERVISOR')
  @UseInterceptors(FilesInterceptor('thermal', 100))
  async uploadThermalImagery(
    @UploadedFiles() files: Express.Multer.File[],
    @Body('missionId') missionId: string,
  ) {
    return this.droneService.processThermalImagery(files, missionId);
  }

  @Get('missions')
  async getMissions(
    @CurrentUser() user: any,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.droneService.getEstateMissions(
      user.estateId,
      limit ? parseInt(limit) : 10,
      offset ? parseInt(offset) : 0,
    );
  }

  @Get('missions/:id')
  async getMission(@Param('id') id: string) {
    return this.droneService.getMissionResults(id);
  }

  @Get('missions/:id/report')
  async getMissionReport(@Param('id') id: string) {
    return this.droneService.generateReport(id);
  }

  @Get('compare/:id1/:id2')
  async compareMissions(
    @Param('id1') id1: string,
    @Param('id2') id2: string,
  ) {
    return this.droneService.compareMissions(id1, id2);
  }

  @Post('auto-schedule')
  @Roles('ADMIN')
  async autoScheduleMission(@CurrentUser() user: any) {
    return this.droneService.autoScheduleMission(user.estateId);
  }

  @Get('missions/:id/orthomosaic')
  async getOrthomosaic(@Param('id') id: string) {
    const mission = await this.droneService.getMissionResults(id);
    // Stream the orthomosaic file
    return { url: mission.orthomosaicUrl };
  }

  @Get('missions/:id/ndvi')
  async getNDVIMap(@Param('id') id: string) {
    const mission = await this.droneService.getMissionResults(id);
    return { url: mission.ndviUrl };
  }
}