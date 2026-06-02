import { Controller, Get, Query, UseGuards, Res, Req } from '@nestjs/common';
import { Response } from 'express';
import { ExportService } from './export.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';

@Controller('export')
@UseGuards(JwtAuthGuard, RolesGuard)
export class ExportController {
  constructor(private readonly exportService: ExportService) {}

  @Get('harvest')
  @Roles('ADMIN', 'SUPERVISOR')
  async exportHarvest(
    @Req() req,
    @Query('startDate') startDate: string,
    @Query('endDate') endDate: string,
    @Res({ passthrough: true }) res: Response,
  ) {
    const estateId = req.user.estateId;
    const buffer = await this.exportService.exportHarvestToExcel(
      estateId,
      new Date(startDate),
      new Date(endDate),
    );
    
    const filename = `Laporan_Panen_${startDate}_to_${endDate}.xlsx`;
    
    res.set({
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="${encodeURIComponent(filename)}"`,
      'Content-Length': buffer.length,
    });
    
    res.send(buffer);
  }

  @Get('complete')
  @Roles('ADMIN')
  async exportCompleteReport(
    @Req() req,
    @Query('startDate') startDate: string,
    @Query('endDate') endDate: string,
    @Res({ passthrough: true }) res: Response,
  ) {
    const estateId = req.user.estateId;
    const buffer = await this.exportService.exportMultiSheetReport(
      estateId,
      new Date(startDate),
      new Date(endDate),
    );
    
    const filename = `Laporan_Lengkap_${startDate}_to_${endDate}.xlsx`;
    
    res.set({
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="${encodeURIComponent(filename)}"`,
    });
    
    res.send(buffer);
  }
}