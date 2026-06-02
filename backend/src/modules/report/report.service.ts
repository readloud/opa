import { Injectable, StreamableFile } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import * as PDFDocument from 'pdfkit';
import * as ExcelJS from 'exceljs';
import { Response } from 'express';

@Injectable()
export class ReportService {
  constructor(private prisma: PrismaService) {}

  async generateHarvestReport(
    estateId: string,
    startDate: Date,
    endDate: Date,
    format: 'pdf' | 'csv' | 'excel',
  ) {
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

    const summary = {
      totalTonase: harvests.reduce((sum, h) => sum + h.tonase, 0),
      totalRecords: harvests.length,
      averagePerDay: harvests.length > 0 
        ? harvests.reduce((sum, h) => sum + h.tonase, 0) / harvests.length 
        : 0,
      byBlock: this.groupByBlock(harvests),
      byDate: this.groupByDate(harvests),
    };

    switch (format) {
      case 'pdf':
        return this.generatePDF(harvests, summary, startDate, endDate);
      case 'csv':
        return this.generateCSV(harvests);
      case 'excel':
        return this.generateExcel(harvests, summary);
      default:
        return this.generatePDF(harvests, summary, startDate, endDate);
    }
  }

  private groupByBlock(harvests: any[]) {
    const groups: Record<string, { tonase: number; count: number }> = {};
    for (const h of harvests) {
      if (!groups[h.block.name]) {
        groups[h.block.name] = { tonase: 0, count: 0 };
      }
      groups[h.block.name].tonase += h.tonase;
      groups[h.block.name].count++;
    }
    return groups;
  }

  private groupByDate(harvests: any[]) {
    const groups: Record<string, number> = {};
    for (const h of harvests) {
      const date = h.harvestDate.toISOString().split('T')[0];
      groups[date] = (groups[date] || 0) + h.tonase;
    }
    return groups;
  }

  private async generatePDF(harvests: any[], summary: any, startDate: Date, endDate: Date): Promise<Buffer> {
    return new Promise((resolve) => {
      const doc = new PDFDocument({ margin: 50, size: 'A4' });
      const buffers: Uint8Array[] = [];
      
      doc.on('data', buffers.push.bind(buffers));
      doc.on('end', () => {
        const pdfData = Buffer.concat(buffers);
        resolve(pdfData);
      });

      // Header
      doc.fontSize(20)
        .font('Helvetica-Bold')
        .text('Laporan Panen OPA', { align: 'center' });
      
      doc.moveDown();
      doc.fontSize(12)
        .font('Helvetica')
        .text(`Periode: ${startDate.toLocaleDateString('id-ID')} - ${endDate.toLocaleDateString('id-ID')}`, { align: 'center' });
      
      doc.moveDown(2);

      // Summary section
      doc.fontSize(14)
        .font('Helvetica-Bold')
        .text('Ringkasan', { underline: true });
      
      doc.moveDown(0.5);
      doc.fontSize(12)
        .font('Helvetica')
        .text(`Total Tonase: ${summary.totalTonase.toFixed(2)} ton`)
        .text(`Total Panen: ${summary.totalRecords} kali`)
        .text(`Rata-rata per Panen: ${summary.averagePerDay.toFixed(2)} ton`);
      
      doc.moveDown();

      // Per block section
      doc.fontSize(14)
        .font('Helvetica-Bold')
        .text('Per Blok', { underline: true });
      
      doc.moveDown(0.5);
      
      const blockTableTop = doc.y;
      doc.fontSize(10)
        .font('Helvetica-Bold')
        .text('Blok', 50, blockTableTop)
        .text('Total Tonase', 200, blockTableTop)
        .text('Frekuensi', 350, blockTableTop);
      
      let y = blockTableTop + 20;
      for (const [blockName, data] of Object.entries(summary.byBlock)) {
        doc.font('Helvetica')
          .text(blockName, 50, y)
          .text((data as any).tonase.toFixed(2), 200, y)
          .text((data as any).count.toString(), 350, y);
        y += 20;
        
        if (y > 700) {
          doc.addPage();
          y = 50;
        }
      }
      
      doc.moveDown(2);

      // Daily breakdown
      doc.fontSize(14)
        .font('Helvetica-Bold')
        .text('Detail Harian', { underline: true });
      
      doc.moveDown(0.5);
      
      const dailyTableTop = doc.y;
      doc.fontSize(10)
        .font('Helvetica-Bold')
        .text('Tanggal', 50, dailyTableTop)
        .text('Tonase', 200, dailyTableTop);
      
      let dailyY = dailyTableTop + 20;
      for (const [date, tonase] of Object.entries(summary.byDate)) {
        doc.font('Helvetica')
          .text(date, 50, dailyY)
          .text((tonase as number).toFixed(2), 200, dailyY);
        dailyY += 20;
        
        if (dailyY > 700) {
          doc.addPage();
          dailyY = 50;
        }
      }

      // Footer
      const pageCount = doc.bufferedPageRange();
      for (let i = 0; i < pageCount; i++) {
        doc.switchToPage(i);
        doc.fontSize(8)
          .text(
            `Dicetak pada: ${new Date().toLocaleString('id-ID')} | Halaman ${i + 1} dari ${pageCount}`,
            50,
            doc.page.height - 50,
            { align: 'center' },
          );
      }

      doc.end();
    });
  }

  private async generateCSV(harvests: any[]): Promise<string> {
    const headers = ['Tanggal', 'Blok', 'Tonase', 'Pencatat', 'Catatan'];
    const rows = harvests.map(h => [
      h.harvestDate.toISOString().split('T')[0],
      h.block.name,
      h.tonase.toString(),
      h.creator.name,
      h.notes || '',
    ]);
    
    const csvContent = [headers, ...rows]
      .map(row => row.map(cell => `"${cell}"`).join(','))
      .join('\n');
    
    return csvContent;
  }

  private async generateExcel(harvests: any[], summary: any): Promise<Buffer> {
    const workbook = new ExcelJS.Workbook();
    
    // Summary sheet
    const summarySheet = workbook.addWorksheet('Ringkasan');
    summarySheet.addRow(['Laporan Panen OPA']);
    summarySheet.addRow([`Periode: ${new Date().toLocaleDateString()}`]);
    summarySheet.addRow([]);
    summarySheet.addRow(['Total Tonase', summary.totalTonase]);
    summarySheet.addRow(['Total Panen', summary.totalRecords]);
    summarySheet.addRow(['Rata-rata per Panen', summary.averagePerDay]);
    
    // Per block sheet
    const blockSheet = workbook.addWorksheet('Per Blok');
    blockSheet.addRow(['Blok', 'Total Tonase', 'Frekuensi']);
    for (const [blockName, data] of Object.entries(summary.byBlock)) {
      blockSheet.addRow([blockName, (data as any).tonase, (data as any).count]);
    }
    
    // Detail sheet
    const detailSheet = workbook.addWorksheet('Detail');
    detailSheet.addRow(['Tanggal', 'Blok', 'Tonase', 'Pencatat', 'Catatan']);
    for (const h of harvests) {
      detailSheet.addRow([
        h.harvestDate,
        h.block.name,
        h.tonase,
        h.creator.name,
        h.notes || '',
      ]);
    }
    
    const buffer = await workbook.xlsx.writeBuffer();
    return Buffer.from(buffer);
  }

  async generateInspectionReport(estateId: string, startDate: Date, endDate: Date) {
    const inspections = await this.prisma.inspection.findMany({
      where: {
        createdAt: { gte: startDate, lte: endDate },
        block: { estateId },
        isDeleted: false,
      },
      include: {
        block: true,
        creator: true,
      },
    });

    const conditionStats = {
      HEALTHY: inspections.filter(i => i.condition === 'HEALTHY').length,
      MILD_DAMAGE: inspections.filter(i => i.condition === 'MILD_DAMAGE').length,
      SEVERE_DAMAGE: inspections.filter(i => i.condition === 'SEVERE_DAMAGE').length,
      DEAD: inspections.filter(i => i.condition === 'DEAD').length,
    };

    return {
      totalInspections: inspections.length,
      conditionStats,
      inspections: inspections.map(i => ({
        date: i.createdAt,
        block: i.block.name,
        condition: i.condition,
        notes: i.notes,
        inspector: i.creator.name,
      })),
    };
  }
}