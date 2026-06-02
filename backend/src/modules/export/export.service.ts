import { Injectable, StreamableFile } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import * as ExcelJS from 'exceljs';
import * as PDFDocument from 'pdfkit';

@Injectable()
export class ExportService {
  constructor(private prisma: PrismaService) {}

  async exportHarvestToExcel(
    estateId: string,
    startDate: Date,
    endDate: Date,
  ): Promise<Buffer> {
    const harvests = await this.prisma.harvest.findMany({
      where: {
        harvestDate: { gte: startDate, lte: endDate },
        block: { estateId },
        isDeleted: false,
      },
      include: {
        block: { include: { estate: true } },
        creator: { select: { name: true } },
      },
      orderBy: { harvestDate: 'asc' },
    });

    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'OPA System';
    workbook.created = new Date();
    
    // Apply custom styles
    const headerStyle: Partial<ExcelJS.Style> = {
      font: { bold: true, color: { argb: 'FFFFFFFF' }, size: 12 },
      fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF2E7D32' } },
      alignment: { horizontal: 'center', vertical: 'middle' },
      border: {
        top: { style: 'thin' },
        left: { style: 'thin' },
        bottom: { style: 'thin' },
        right: { style: 'thin' },
      },
    };
    
    const titleStyle: Partial<ExcelJS.Style> = {
      font: { bold: true, size: 16, color: { argb: 'FF2E7D32' } },
      alignment: { horizontal: 'center' },
    };
    
    const totalStyle: Partial<ExcelJS.Style> = {
      font: { bold: true, size: 12 },
      fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE8F5E9' } },
    };

    // ========== SHEET 1: Ringkasan ==========
    const summarySheet = workbook.addWorksheet('Ringkasan', {
      properties: { tabColor: { argb: 'FF2E7D32' } },
    });
    
    // Title
    summarySheet.mergeCells('A1:D1');
    summarySheet.getCell('A1').value = 'LAPORAN PANEN OPA';
    summarySheet.getCell('A1').style = titleStyle;
    summarySheet.getRow(1).height = 30;
    
    summarySheet.mergeCells('A2:D2');
    summarySheet.getCell('A2').value = `Periode: ${startDate.toLocaleDateString('id-ID')} - ${endDate.toLocaleDateString('id-ID')}`;
    summarySheet.getCell('A2').style = { alignment: { horizontal: 'center' } };
    
    // Summary stats
    const totalTonase = harvests.reduce((sum, h) => sum + h.tonase, 0);
    const totalRecords = harvests.length;
    const averagePerDay = totalTonase / this.getDaysDifference(startDate, endDate);
    
    summarySheet.addRow([]);
    summarySheet.addRow(['STATISTIK', 'Nilai']);
    summarySheet.getRow(4).eachCell((cell) => { cell.style = headerStyle });
    
    summarySheet.addRow(['Total Tonase', `${totalTonase.toFixed(2)} ton`]);
    summarySheet.addRow(['Total Panen', `${totalRecords} kali`]);
    summarySheet.addRow(['Rata-rata per Hari', `${averagePerDay.toFixed(2)} ton`]);
    summarySheet.addRow(['Rata-rata per Panen', `${(totalTonase / totalRecords || 0).toFixed(2)} ton`]);
    
    // Apply borders
    for (let i = 5; i <= 8; i++) {
      summarySheet.getRow(i).eachCell((cell) => {
        cell.border = {
          top: { style: 'thin' },
          left: { style: 'thin' },
          bottom: { style: 'thin' },
          right: { style: 'thin' },
        };
      });
    }
    
    // Set column widths
    summarySheet.getColumn(1).width = 25;
    summarySheet.getColumn(2).width = 20;

    // ========== SHEET 2: Data Harian ==========
    const dailySheet = workbook.addWorksheet('Data Harian', {
      properties: { tabColor: { argb: 'FF2196F3' } },
    });
    
    // Group by date
    const dailyData = this.groupByDateDetailed(harvests);
    
    // Headers
    const dailyHeaders = ['Tanggal', 'Jumlah Panen', 'Total Tonase', 'Rata-rata (ton)', 'Blok Tertinggi'];
    dailySheet.addRow(dailyHeaders);
    dailySheet.getRow(1).eachCell((cell) => { cell.style = headerStyle });
    
    // Data
    for (const data of dailyData) {
      const row = dailySheet.addRow([
        data.date,
        data.count,
        data.totalTonase.toFixed(2),
        (data.totalTonase / data.count).toFixed(2),
        data.topBlock,
      ]);
      
      row.eachCell((cell) => {
        cell.border = {
          top: { style: 'thin' },
          left: { style: 'thin' },
          bottom: { style: 'thin' },
          right: { style: 'thin' },
        };
      });
    }
    
    // Totals row
    const totalRow = dailySheet.addRow([
      'TOTAL',
      dailyData.reduce((sum, d) => sum + d.count, 0),
      dailyData.reduce((sum, d) => sum + d.totalTonase, 0).toFixed(2),
      '',
      '',
    ]);
    totalRow.eachCell((cell) => { cell.style = totalStyle });
    
    dailySheet.getColumn(1).width = 15;
    dailySheet.getColumn(2).width = 15;
    dailySheet.getColumn(3).width = 15;
    dailySheet.getColumn(4).width = 15;
    dailySheet.getColumn(5).width = 20;

    // ========== SHEET 3: Per Blok ==========
    const blockSheet = workbook.addWorksheet('Per Blok', {
      properties: { tabColor: { argb: 'FFFF9800' } },
    });
    
    const blockData = this.groupByBlockDetailed(harvests);
    
    const blockHeaders = ['Blok', 'Total Panen', 'Total Tonase', 'Rata-rata (ton)', 'Persentase'];
    blockSheet.addRow(blockHeaders);
    blockSheet.getRow(1).eachCell((cell) => { cell.style = headerStyle });
    
    for (const data of blockData) {
      const percentage = (data.totalTonase / totalTonase * 100).toFixed(1);
      const row = blockSheet.addRow([
        data.blockName,
        data.count,
        data.totalTonase.toFixed(2),
        (data.totalTonase / data.count).toFixed(2),
        `${percentage}%`,
      ]);
      
      row.eachCell((cell) => {
        cell.border = {
          top: { style: 'thin' },
          left: { style: 'thin' },
          bottom: { style: 'thin' },
          right: { style: 'thin' },
        };
      });
      
      // Add progress bar using data bar (conditional formatting)
      const percentageNum = parseFloat(percentage);
      if (percentageNum > 30) {
        row.getCell(5).fill = {
          type: 'pattern',
          pattern: 'solid',
          fgColor: { argb: 'FF4CAF50' },
        };
      } else if (percentageNum > 15) {
        row.getCell(5).fill = {
          type: 'pattern',
          pattern: 'solid',
          fgColor: { argb: 'FFFFC107' },
        };
      }
    }
    
    blockSheet.getColumn(1).width = 20;
    blockSheet.getColumn(2).width = 15;
    blockSheet.getColumn(3).width = 15;
    blockSheet.getColumn(4).width = 15;
    blockSheet.getColumn(5).width = 15;

    // ========== SHEET 4: Detail Lengkap ==========
    const detailSheet = workbook.addWorksheet('Detail Lengkap', {
      properties: { tabColor: { argb: 'FF9C27B0' } },
    });
    
    const detailHeaders = [
      'No',
      'Tanggal Panen',
      'Blok',
      'Tonase (ton)',
      'Pencatat',
      'Catatan',
      'Foto URL',
    ];
    detailSheet.addRow(detailHeaders);
    detailSheet.getRow(1).eachCell((cell) => { cell.style = headerStyle });
    
    let rowNumber = 1;
    for (const harvest of harvests) {
      const row = detailSheet.addRow([
        rowNumber++,
        harvest.harvestDate.toLocaleDateString('id-ID'),
        harvest.block.name,
        harvest.tonase,
        harvest.creator.name,
        harvest.notes || '-',
        harvest.photoUrl || '-',
      ]);
      
      row.eachCell((cell) => {
        cell.border = {
          top: { style: 'thin' },
          left: { style: 'thin' },
          bottom: { style: 'thin' },
          right: { style: 'thin' },
        };
      });
      
      // Color rows based on tonase
      if (harvest.tonase > 20) {
        row.fill = {
          type: 'pattern',
          pattern: 'solid',
          fgColor: { argb: 'FFC8E6C9' },
        };
      } else if (harvest.tonase < 10) {
        row.fill = {
          type: 'pattern',
          pattern: 'solid',
          fgColor: { argb: 'FFFFCDD2' },
        };
      }
    }
    
    detailSheet.getColumn(1).width = 8;
    detailSheet.getColumn(2).width = 15;
    detailSheet.getColumn(3).width = 20;
    detailSheet.getColumn(4).width = 12;
    detailSheet.getColumn(5).width = 20;
    detailSheet.getColumn(6).width = 30;
    detailSheet.getColumn(7).width = 40;

    // ========== SHEET 5: Grafik (Embedded Chart) ==========
    const chartSheet = workbook.addWorksheet('Grafik', {
      properties: { tabColor: { argb: 'FFE91E63' } },
    });
    
    // Add chart data
    chartSheet.addRow(['Data untuk Grafik']);
    chartSheet.addRow(['Tanggal', 'Tonase']);
    
    for (const data of dailyData) {
      chartSheet.addRow([data.date, data.totalTonase]);
    }
    
    // Create bar chart
    const barChart = workbook.addChart({
      type: 'bar',
      title: 'Produksi Harian',
      width: 800,
      height: 400,
      anchor: 'A10',
    });
    
    barChart.addSeries({
      name: 'Tonase',
      labels: dailyData.map(d => d.date),
      values: dailyData.map(d => d.totalTonase),
    });
    
    chartSheet.addChart(barChart);
    
    chartSheet.getColumn(1).width = 15;
    chartSheet.getColumn(2).width = 15;

    // ========== SHEET 6: Header & Footer Info ==========
    const infoSheet = workbook.addWorksheet('Info', {
      properties: { tabColor: { argb: 'FF607D8B' } },
    });
    
    infoSheet.addRow(['Informasi Laporan']);
    infoSheet.addRow(['Dibuat oleh:', 'OPA System']);
    infoSheet.addRow(['Tanggal cetak:', new Date().toLocaleString('id-ID')]);
    infoSheet.addRow(['Periode:', `${startDate.toLocaleDateString('id-ID')} s/d ${endDate.toLocaleDateString('id-ID')}`]);
    infoSheet.addRow([]);
    infoSheet.addRow(['Keterangan:']);
    infoSheet.addRow(['1. Data diambil dari sistem OPA']);
    infoSheet.addRow(['2. Tonase dalam satuan metrik ton (1 ton = 1000 kg)']);
    infoSheet.addRow(['3. Laporan ini bersifat resmi dan dapat dipertanggungjawabkan']);
    
    infoSheet.getColumn(1).width = 20;
    infoSheet.getColumn(2).width = 40;

    // Generate buffer
    const buffer = await workbook.xlsx.writeBuffer();
    return Buffer.from(buffer);
  }

  async exportMultiSheetReport(
    estateId: string,
    startDate: Date,
    endDate: Date,
  ): Promise<Buffer> {
    const [harvests, inspections, fertilizations] = await Promise.all([
      this.prisma.harvest.findMany({
        where: {
          harvestDate: { gte: startDate, lte: endDate },
          block: { estateId },
          isDeleted: false,
        },
        include: { block: true, creator: { select: { name: true } } },
      }),
      this.prisma.inspection.findMany({
        where: {
          createdAt: { gte: startDate, lte: endDate },
          block: { estateId },
          isDeleted: false,
        },
        include: { block: true, creator: { select: { name: true } } },
      }),
      this.prisma.fertilization.findMany({
        where: {
          applicationDate: { gte: startDate, lte: endDate },
          block: { estateId },
          isDeleted: false,
        },
        include: { block: true, creator: { select: { name: true } } },
      }),
    ]);

    const workbook = new ExcelJS.Workbook();
    
    // Harvest sheet (same as above)
    await this.addHarvestSheet(workbook, harvests, startDate, endDate);
    
    // Inspection sheet
    await this.addInspectionSheet(workbook, inspections);
    
    // Fertilization sheet
    await this.addFertilizationSheet(workbook, fertilizations);
    
    // Dashboard sheet
    await this.addDashboardSheet(workbook, { harvests, inspections, fertilizations }, startDate, endDate);
    
    const buffer = await workbook.xlsx.writeBuffer();
    return Buffer.from(buffer);
  }

  private async addHarvestSheet(workbook: ExcelJS.Workbook, harvests: any[], startDate: Date, endDate: Date) {
    const sheet = workbook.addWorksheet('Panen');
    // ... (similar to exportHarvestToExcel but simplified)
  }

  private async addInspectionSheet(workbook: ExcelJS.Workbook, inspections: any[]) {
    const sheet = workbook.addWorksheet('Inspeksi');
    
    const headers = ['Tanggal', 'Blok', 'Kondisi', 'Catatan', 'Inspektur'];
    sheet.addRow(headers);
    
    for (const inspection of inspections) {
      sheet.addRow([
        inspection.createdAt.toLocaleDateString('id-ID'),
        inspection.block.name,
        inspection.condition,
        inspection.notes || '-',
        inspection.creator.name,
      ]);
    }
  }

  private async addFertilizationSheet(workbook: ExcelJS.Workbook, fertilizations: any[]) {
    const sheet = workbook.addWorksheet('Pemupukan');
    
    const headers = ['Tanggal', 'Blok', 'Jenis Pupuk', 'Kuantitas (kg)', 'Catatan'];
    sheet.addRow(headers);
    
    for (const fert of fertilizations) {
      sheet.addRow([
        fert.applicationDate.toLocaleDateString('id-ID'),
        fert.block.name,
        fert.fertilizerType,
        fert.quantity,
        fert.notes || '-',
      ]);
    }
  }

  private async addDashboardSheet(workbook: ExcelJS.Workbook, data: any, startDate: Date, endDate: Date) {
    const sheet = workbook.addWorksheet('Dashboard');
    
    // Summary cards
    sheet.mergeCells('A1:D2');
    sheet.getCell('A1').value = 'DASHBOARD OPA';
    sheet.getCell('A1').style = { font: { bold: true, size: 18 } };
    
    // KPI Cards
    const totalTonase = data.harvests.reduce((s, h) => s + h.tonase, 0);
    const healthyCount = data.inspections.filter(i => i.condition === 'HEALTHY').length;
    
    sheet.addRow([]);
    sheet.addRow(['KPI', 'Nilai', 'Target', 'Status']);
    
    sheet.addRow(['Total Produksi', `${totalTonase.toFixed(2)} ton`, '100 ton', totalTonase >= 100 ? '✓' : '⚠']);
    sheet.addRow(['Inspeksi Sehat', `${((healthyCount / data.inspections.length) * 100).toFixed(1)}%`, '80%', healthyCount / data.inspections.length >= 0.8 ? '✓' : '⚠']);
  }

  private groupByDateDetailed(harvests: any[]): any[] {
    const groups: Record<string, any> = {};
    
    for (const h of harvests) {
      const date = h.harvestDate.toISOString().split('T')[0];
      if (!groups[date]) {
        groups[date] = { date, count: 0, totalTonase: 0, blocks: {} };
      }
      groups[date].count++;
      groups[date].totalTonase += h.tonase;
      groups[date].blocks[h.block.name] = (groups[date].blocks[h.block.name] || 0) + h.tonase;
    }
    
    return Object.values(groups).map(g => ({
      ...g,
      topBlock: Object.entries(g.blocks).sort((a, b) => b[1] - a[1])[0]?.[0] || '-',
    }));
  }

  private groupByBlockDetailed(harvests: any[]): any[] {
    const groups: Record<string, any> = {};
    
    for (const h of harvests) {
      if (!groups[h.block.name]) {
        groups[h.block.name] = { blockName: h.block.name, count: 0, totalTonase: 0 };
      }
      groups[h.block.name].count++;
      groups[h.block.name].totalTonase += h.tonase;
    }
    
    return Object.values(groups).sort((a, b) => b.totalTonase - a.totalTonase);
  }

  private getDaysDifference(startDate: Date, endDate: Date): number {
    const diff = endDate.getTime() - startDate.getTime();
    return Math.max(1, Math.ceil(diff / (1000 * 3600 * 24)));
  }
}