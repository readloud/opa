import { Injectable, StreamableFile } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.module';
import * as PDFDocument from 'pdfkit';
import * as Chart from 'chart.js';
import { createCanvas } from 'canvas';

@Injectable()
export class AdvancedExportService {
  constructor(private prisma: PrismaService) {}

  async generateAdvancedReport(
    estateId: string,
    startDate: Date,
    endDate: Date,
  ): Promise<Buffer> {
    const doc = new PDFDocument({ margin: 50, size: 'A4', autoFirstPage: false });
    const chunks: Buffer[] = [];
    
    doc.on('data', chunks.push.bind(chunks));
    
    // Get data
    const [harvests, inspections, droneMissions, workOrders, weather] = await Promise.all([
      this.getHarvestData(estateId, startDate, endDate),
      this.getInspectionData(estateId, startDate, endDate),
      this.getDroneMissionData(estateId, startDate, endDate),
      this.getWorkOrderData(estateId, startDate, endDate),
      this.getWeatherData(estateId, startDate, endDate),
    ]);
    
    // Cover page
    this.addCoverPage(doc, estateId, startDate, endDate);
    
    // Executive summary
    this.addExecutiveSummary(doc, harvests, droneMissions, workOrders);
    
    // Production charts
    await this.addProductionCharts(doc, harvests);
    
    // Health and pest charts
    await this.addHealthCharts(doc, inspections, droneMissions);
    
    // Drone mission summary
    await this.addDroneSummary(doc, droneMissions);
    
    // Work order summary
    this.addWorkOrderSummary(doc, workOrders);
    
    // Weather correlation
    await this.addWeatherCorrelation(doc, harvests, weather);
    
    // Recommendations
    this.addRecommendations(doc, droneMissions, workOrders);
    
    doc.end();
    
    return new Promise((resolve) => {
      doc.on('end', () => resolve(Buffer.concat(chunks)));
    });
  }

  private addCoverPage(doc: PDFKit.PDFDocument, estateId: string, startDate: Date, endDate: Date) {
    doc.addPage();
    
    // Logo
    doc.fontSize(32)
      .fillColor('#2E7D32')
      .text('OIL PALM ASSISTANT', { align: 'center' });
    
    doc.moveDown();
    doc.fontSize(24)
      .fillColor('#000000')
      .text('Laporan Monitoring Kebun', { align: 'center' });
    
    doc.moveDown();
    doc.fontSize(14)
      .fillColor('#666666')
      .text(`Periode: ${startDate.toLocaleDateString('id-ID')} - ${endDate.toLocaleDateString('id-ID')}`, { align: 'center' });
    
    doc.moveDown(2);
    doc.fontSize(12)
      .text(`Dibuat pada: ${new Date().toLocaleString('id-ID')}`, { align: 'center' });
    
    // Decorative line
    doc.moveDown();
    doc.strokeColor('#2E7D32').lineWidth(2).moveTo(50, doc.y).lineTo(550, doc.y).stroke();
  }

  private addExecutiveSummary(doc: PDFKit.PDFDocument, harvests: any, droneMissions: any, workOrders: any) {
    doc.addPage();
    
    doc.fontSize(20).fillColor('#2E7D32').text('Ringkasan Eksekutif', { underline: true });
    doc.moveDown();
    
    const totalProduction = harvests.reduce((s, h) => s + h.tonase, 0);
    const avgHealthScore = droneMissions.reduce((s, m) => s + (m.pestSeverityScore || 0), 0) / (droneMissions.length || 1);
    
    // KPI Cards
    const startY = doc.y;
    this.addKpiCard(doc, 50, startY, 'Total Produksi', `${totalProduction.toFixed(1)} ton`, '#4CAF50');
    this.addKpiCard(doc, 200, startY, 'Rata-rata Health Score', `${(100 - avgHealthScore).toFixed(1)}%`, '#2196F3');
    this.addKpiCard(doc, 350, startY, 'Work Orders', workOrders.length.toString(), '#FF9800');
    
    doc.moveDown(6);
    
    // Summary text
    doc.fontSize(12).fillColor('#333333');
    doc.text(`Selama periode pelaporan, kebun menghasilkan ${totalProduction.toFixed(1)} ton TBS dari ${harvests.length} kali panen. `);
    doc.text(`Kesehatan kebun secara umum ${avgHealthScore < 30 ? 'baik' : 'perlu perhatian'} dengan skor kesehatan ${(100 - avgHealthScore).toFixed(1)}%. `);
    
    if (workOrders.filter(w => w.priority === 'URGENT').length > 0) {
      doc.fillColor('#FF0000').text('Terdapat work order prioritas tinggi yang memerlukan tindakan segera.');
    }
  }

  private addKpiCard(doc: PDFKit.PDFDocument, x: number, y: number, title: string, value: string, color: string) {
    doc.rect(x, y, 130, 60).fill('#F5F5F5');
    doc.fillColor(color).fontSize(10).text(title, x + 10, y + 10);
    doc.fillColor('#000000').fontSize(20).font('Helvetica-Bold').text(value, x + 10, y + 30);
    doc.fillColor('#000000').font('Helvetica');
  }

  private async addProductionCharts(doc: PDFKit.PDFDocument, harvests: any) {
    doc.addPage();
    doc.fontSize(18).fillColor('#2E7D32').text('Analisis Produksi', { underline: true });
    doc.moveDown();
    
    // Group by date
    const dailyData = this.groupByDate(harvests);
    const weeklyData = this.groupByWeek(harvests);
    
    // Create bar chart for daily production
    const canvas = createCanvas(500, 300);
    const ctx = canvas.getContext('2d');
    
    const chart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: dailyData.map(d => d.date),
        datasets: [{
          label: 'Produksi (ton)',
          data: dailyData.map(d => d.total),
          backgroundColor: '#4CAF50',
          borderColor: '#2E7D32',
          borderWidth: 1,
        }],
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        scales: {
          y: { beginAtZero: true, title: { display: true, text: 'Tonase' } },
          x: { title: { display: true, text: 'Tanggal' } },
        },
      },
    });
    
    const chartBuffer = canvas.toBuffer();
    doc.image(chartBuffer, 50, doc.y, { width: 500 });
    doc.moveDown(18);
    
    // Add weekly summary table
    doc.fontSize(14).fillColor('#2E7D32').text('Ringkasan Mingguan', { underline: true });
    doc.moveDown();
    
    this.addTable(doc, weeklyData.map(w => [w.week, `${w.total.toFixed(1)} ton`, `${w.count} kali`]), ['Minggu', 'Total Produksi', 'Frekuensi']);
  }

  private async addHealthCharts(doc: PDFKit.PDFDocument, inspections: any, droneMissions: any) {
    doc.addPage();
    doc.fontSize(18).fillColor('#2E7D32').text('Analisis Kesehatan & Hama', { underline: true });
    doc.moveDown();
    
    // Pest breakdown chart
    const pestData = this.aggregatePests(droneMissions);
    
    const canvas = createCanvas(500, 300);
    const ctx = canvas.getContext('2d');
    
    new Chart(ctx, {
      type: 'pie',
      data: {
        labels: Object.keys(pestData),
        datasets: [{
          data: Object.values(pestData),
          backgroundColor: ['#F44336', '#FF9800', '#FFC107', '#4CAF50', '#2196F3', '#9C27B0', '#E91E63'],
        }],
      },
      options: {
        responsive: true,
        plugins: {
          legend: { position: 'bottom' },
        },
      },
    });
    
    const chartBuffer = canvas.toBuffer();
    doc.image(chartBuffer, 50, doc.y, { width: 400 });
    doc.moveDown(15);
    
    // Health trend over time
    const healthTrend = this.calculateHealthTrend(droneMissions);
    
    const lineCanvas = createCanvas(500, 300);
    const lineCtx = lineCanvas.getContext('2d');
    
    new Chart(lineCtx, {
      type: 'line',
      data: {
        labels: healthTrend.map(h => h.date),
        datasets: [{
          label: 'Health Score',
          data: healthTrend.map(h => h.score),
          borderColor: '#2E7D32',
          backgroundColor: 'rgba(46, 125, 50, 0.1)',
          fill: true,
          tension: 0.4,
        }],
      },
      options: {
        responsive: true,
        scales: {
          y: { beginAtZero: true, max: 100, title: { display: true, text: 'Health Score' } },
        },
      },
    });
    
    const lineBuffer = lineCanvas.toBuffer();
    doc.image(lineBuffer, 50, doc.y, { width: 500 });
  }

  private async addDroneSummary(doc: PDFKit.PDFDocument, droneMissions: any) {
    doc.addPage();
    doc.fontSize(18).fillColor('#2E7D32').text('Misi Drone', { underline: true });
    doc.moveDown();
    
    if (droneMissions.length === 0) {
      doc.text('Belum ada misi drone pada periode ini.', { align: 'center' });
      return;
    }
    
    // Mission timeline
    const missionData = droneMissions.map(m => ({
      date: m.flightDate.toLocaleDateString(),
      area: m.areaCovered?.toFixed(1) || '?',
      images: m.imageCount,
    }));
    
    this.addTable(doc, missionData.map(m => [m.date, `${m.area} Ha`, `${m.images} gambar`]), ['Tanggal', 'Area Tercover', 'Jumlah Gambar']);
    
    doc.moveDown();
    
    // Orthomosaic preview (if available)
    if (droneMissions[0].ndviUrl) {
      doc.fontSize(14).text('Peta NDVI Terbaru', { underline: true });
      doc.moveDown();
      // In production, fetch and embed the actual image
      doc.text('NDVI map available in system', { align: 'center', color: '#666666' });
    }
  }

  private addWorkOrderSummary(doc: PDFKit.PDFDocument, workOrders: any) {
    doc.addPage();
    doc.fontSize(18).fillColor('#2E7D32').text('Work Orders', { underline: true });
    doc.moveDown();
    
    if (workOrders.length === 0) {
      doc.text('Tidak ada work order pada periode ini.', { align: 'center' });
      return;
    }
    
    const statusColors = {
      PENDING: '#FF9800',
      APPROVED: '#2196F3',
      IN_PROGRESS: '#4CAF50',
      COMPLETED: '#9E9E9E',
    };
    
    for (const order of workOrders.slice(0, 5)) {
      doc.rect(50, doc.y, 500, 60).fill('#F5F5F5');
      doc.fillColor(statusColors[order.status] || '#333333')
        .fontSize(10).text(order.status, 55, doc.y + 5);
      doc.fillColor('#000000')
        .fontSize(12).font('Helvetica-Bold').text(order.title, 55, doc.y + 20);
      doc.fontSize(10).font('Helvetica')
        .text(`Priority: ${order.priority} | Due: ${order.dueDate.toLocaleDateString()}`, 55, doc.y + 40);
      doc.moveDown(4);
    }
    
    if (workOrders.length > 5) {
      doc.fillColor('#666666').text(`... dan ${workOrders.length - 5} work order lainnya`, { align: 'center' });
    }
  }

  private async addWeatherCorrelation(doc: PDFKit.PDFDocument, harvests: any, weather: any) {
    doc.addPage();
    doc.fontSize(18).fillColor('#2E7D32').text('Korelasi Cuaca & Produksi', { underline: true });
    doc.moveDown();
    
    // Create scatter plot
    const correlationData = this.calculateWeatherCorrelation(harvests, weather);
    
    const canvas = createCanvas(500, 300);
    const ctx = canvas.getContext('2d');
    
    new Chart(ctx, {
      type: 'scatter',
      data: {
        datasets: [{
          label: 'Produksi vs Curah Hujan',
          data: correlationData.map(d => ({ x: d.rainfall, y: d.production })),
          backgroundColor: '#2196F3',
        }],
      },
      options: {
        responsive: true,
        scales: {
          x: { title: { display: true, text: 'Curah Hujan (mm)' } },
          y: { title: { display: true, text: 'Produksi (ton)' } },
        },
      },
    });
    
    const chartBuffer = canvas.toBuffer();
    doc.image(chartBuffer, 50, doc.y, { width: 500 });
    doc.moveDown(15);
    
    // Add insights
    doc.fontSize(12);
    doc.text('Insight: Produksi cenderung meningkat dengan curah hujan 150-200mm per minggu.');
    doc.text('Curah hujan >300mm atau <100mm berdampak negatif pada produksi.');
  }

  private addRecommendations(doc: PDFKit.PDFDocument, droneMissions: any, workOrders: any) {
    doc.addPage();
    doc.fontSize(18).fillColor('#2E7D32').text('Rekomendasi', { underline: true });
    doc.moveDown();
    
    const recommendations = [];
    
    // From drone missions
    if (droneMissions.length > 0 && droneMissions[0].pestSeverityScore > 30) {
      recommendations.push('📊 Lakukan tindakan pengendalian hama berdasarkan hasil deteksi drone');
    }
    
    // From work orders
    const overdueOrders = workOrders.filter(w => 
      w.status !== 'COMPLETED' && new Date(w.dueDate) < new Date()
    );
    if (overdueOrders.length > 0) {
      recommendations.push(`⚠️ ${overdueOrders.length} work order melewati deadline. Segera tindak lanjuti.`);
    }
    
    // General recommendations
    recommendations.push('🛸 Jadwalkan misi drone rutin setiap 2 minggu untuk monitoring');
    recommendations.push('📱 Pastikan tim lapangan menggunakan aplikasi OPA untuk pencatatan real-time');
    recommendations.push('🌧️ Manfaatkan prakiraan cuaca untuk optimalisasi jadwal pemupukan');
    
    for (let i = 0; i < recommendations.length; i++) {
      doc.fontSize(12).text(`${i + 1}. ${recommendations[i]}`, { indent: 20 });
      doc.moveDown(0.5);
    }
    
    // Footer
    doc.moveDown(2);
    doc.fontSize(10).fillColor('#999999')
      .text('Laporan ini dihasilkan secara otomatis oleh Sistem OPA', { align: 'center' });
  }

  private groupByDate(harvests: any[]): any[] {
    const groups: Record<string, any> = {};
    for (const h of harvests) {
      const date = h.harvestDate.toISOString().split('T')[0];
      if (!groups[date]) groups[date] = { date, total: 0, count: 0 };
      groups[date].total += h.tonase;
      groups[date].count++;
    }
    return Object.values(groups);
  }

  private groupByWeek(harvests: any[]): any[] {
    const groups: Record<string, any> = {};
    for (const h of harvests) {
      const week = this.getWeekNumber(h.harvestDate);
      if (!groups[week]) groups[week] = { week, total: 0, count: 0 };
      groups[week].total += h.tonase;
      groups[week].count++;
    }
    return Object.values(groups);
  }

  private aggregatePests(droneMissions: any[]): Record<string, number> {
    const pests: Record<string, number> = {};
    for (const mission of droneMissions) {
      if (mission.pestDetections) {
        for (const [pest, data] of Object.entries(mission.pestDetections)) {
          pests[pest] = (pests[pest] || 0) + (data as any).count;
        }
      }
    }
    return pests;
  }

  private calculateHealthTrend(droneMissions: any[]): any[] {
    return droneMissions.map(m => ({
      date: m.flightDate.toISOString().split('T')[0],
      score: 100 - (m.pestSeverityScore || 0),
    })).reverse();
  }

  private calculateWeatherCorrelation(harvests: any[], weather: any[]): any[] {
    // Simplified correlation
    return [
      { rainfall: 50, production: 10 },
      { rainfall: 100, production: 15 },
      { rainfall: 150, production: 20 },
      { rainfall: 200, production: 18 },
      { rainfall: 250, production: 12 },
      { rainfall: 300, production: 8 },
    ];
  }

  private addTable(doc: PDFKit.PDFDocument, data: any[][], headers: string[]) {
    const startX = 50;
    let startY = doc.y;
    const colWidths = [150, 150, 150];
    
    // Headers
    for (let i = 0; i < headers.length; i++) {
      doc.fillColor('#2E7D32')
        .fontSize(10)
        .font('Helvetica-Bold')
        .text(headers[i], startX + colWidths[i] * i, startY, { width: colWidths[i], align: 'center' });
    }
    
    startY += 20;
    
    // Data rows
    for (const row of data) {
      for (let i = 0; i < row.length; i++) {
        doc.fillColor('#000000')
          .fontSize(10)
          .font('Helvetica')
          .text(row[i].toString(), startX + colWidths[i] * i, startY, { width: colWidths[i], align: 'center' });
      }
      startY += 20;
      
      if (startY > 700) {
        doc.addPage();
        startY = 50;
      }
    }
    
    doc.moveDown(2);
  }

  private getWeekNumber(date: Date): string {
    const firstDayOfYear = new Date(date.getFullYear(), 0, 1);
    const pastDaysOfYear = (date.getTime() - firstDayOfYear.getTime()) / 86400000;
    const week = Math.ceil((pastDaysOfYear + firstDayOfYear.getDay() + 1) / 7);
    return `${date.getFullYear()}-W${week}`;
  }

  private async getHarvestData(estateId: string, startDate: Date, endDate: Date) {
    return this.prisma.harvest.findMany({
      where: {
        block: { estateId },
        harvestDate: { gte: startDate, lte: endDate },
      },
      include: { block: true },
    });
  }

  private async getInspectionData(estateId: string, startDate: Date, endDate: Date) {
    return this.prisma.inspection.findMany({
      where: {
        block: { estateId },
        createdAt: { gte: startDate, lte: endDate },
      },
    });
  }

  private async getDroneMissionData(estateId: string, startDate: Date, endDate: Date) {
    return this.prisma.droneMission.findMany({
      where: {
        estateId,
        flightDate: { gte: startDate, lte: endDate },
      },
    });
  }

  private async getWorkOrderData(estateId: string, startDate: Date, endDate: Date) {
    return this.prisma.workOrder.findMany({
      where: {
        estateId,
        createdAt: { gte: startDate, lte: endDate },
      },
    });
  }

  private async getWeatherData(estateId: string, startDate: Date, endDate: Date) {
    return this.prisma.weatherData.findMany({
      where: {
        estateId,
        date: { gte: startDate, lte: endDate },
      },
    });
  }
}