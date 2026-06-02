import { Controller, Get, Query, UseGuards, Res, StreamableFile } from '@nestjs/common';
import { Response } from 'express';
import { ReportService } from './report.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';

@Controller('reports')
@UseGuards(JwtAuthGuard, RolesGuard)
export class ReportController {
  constructor(private readonly reportService: ReportService) {}

  @Get('harvest')
  @Roles('ADMIN', 'SUPERVISOR')
  async exportHarvestReport(
    @Query('estateId') estateId: string,
    @Query('startDate') startDate: string,
    @Query('endDate') endDate: string,
    @Query('format') format: 'pdf' | 'csv' | 'excel',
    @Res({ passthrough: true }) res: Response,
  ) {
    const report = await this.reportService.generateHarvestReport(
      estateId,
      new Date(startDate),
      new Date(endDate),
      format,
    );

    let filename = `laporan_panen_${startDate}_to_${endDate}`;
    let contentType = '';

    switch (format) {
      case 'pdf':
        filename += '.pdf';
        contentType = 'application/pdf';
        break;
      case 'csv':
        filename += '.csv';
        contentType = 'text/csv';
        break;
      case 'excel':
        filename += '.xlsx';
        contentType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        break;
    }

    res.set({
      'Content-Type': contentType,
      'Content-Disposition': `attachment; filename="${filename}"`,
    });

    if (typeof report === 'string') {
      return new StreamableFile(Buffer.from(report));
    }
    return new StreamableFile(report);
  }

  @Get('inspection')
  @Roles('ADMIN', 'SUPERVISOR')
  async getInspectionReport(
    @Query('estateId') estateId: string,
    @Query('startDate') startDate: string,
    @Query('endDate') endDate: string,
  ) {
    return this.reportService.generateInspectionReport(
      estateId,
      new Date(startDate),
      new Date(endDate),
    );
  }
}