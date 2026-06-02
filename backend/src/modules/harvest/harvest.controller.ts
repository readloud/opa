import { Controller, Get, Post, Body, Param, Query, UseGuards, Req } from '@nestjs/common';
import { HarvestService } from './harvest.service';
import { CreateHarvestDto } from './dto/create-harvest.dto';
import { SyncHarvestDto } from './dto/sync-harvest.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';

@Controller('harvests')
@UseGuards(JwtAuthGuard)
export class HarvestController {
  constructor(private readonly harvestService: HarvestService) {}

  @Post()
  async create(@Req() req, @Body() createHarvestDto: CreateHarvestDto) {
    return this.harvestService.create(req.user.id, createHarvestDto);
  }

  @Get()
  async findAll(
    @Req() req,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
    @Query('blockId') blockId?: string,
  ) {
    return this.harvestService.findAll(req.user.id, req.user.role, {
      startDate,
      endDate,
      blockId,
    });
  }

  @Get('summary')
  async getSummary(
    @Req() req,
    @Query('startDate') startDate: string,
    @Query('endDate') endDate: string,
  ) {
    return this.harvestService.getSummary(
      req.user.id,
      req.user.role,
      new Date(startDate),
      new Date(endDate),
    );
  }

  @Get(':id')
  async findOne(@Req() req, @Param('id') id: string) {
    return this.harvestService.findOne(id, req.user.id, req.user.role);
  }

  @Post('sync')
  @Roles('ADMIN', 'SUPERVISOR')
  async syncFromMobile(@Body() syncData: SyncHarvestDto[]) {
    return this.harvestService.syncFromMobile(syncData);
  }
}