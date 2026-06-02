import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import * as QRCode from 'qrcode';
import * as bwipjs from 'bwip-js';

@Injectable()
export class QrCodeService {
  constructor(private prisma: PrismaService) {}

  async generateTreeQrCode(treeId: string): Promise<string> {
    const tree = await this.prisma.tree.findUnique({
      where: { id: treeId },
      include: { block: true },
    });

    if (!tree) {
      throw new NotFoundException('Tree not found');
    }

    const qrData = JSON.stringify({
      type: 'tree',
      id: tree.id,
      code: tree.treeCode,
      blockId: tree.blockId,
      blockName: tree.block.name,
      url: `https://opa-app.com/tree/${tree.id}`,
    });

    // Generate QR code as data URL
    const qrCode = await QRCode.toDataURL(qrData, {
      errorCorrectionLevel: 'H',
      margin: 2,
      width: 300,
      color: {
        dark: '#2E7D32',
        light: '#FFFFFF',
      },
    });

    return qrCode;
  }

  async generateBatchQrCodes(blockId: string): Promise<Buffer> {
    const trees = await this.prisma.tree.findMany({
      where: { blockId },
      include: { block: true },
    });

    if (trees.length === 0) {
      throw new NotFoundException('No trees found in this block');
    }

    // Generate QR codes in a grid layout using bwip-js or similar
    const qrCodes = await Promise.all(
      trees.map(async (tree) => {
        const qrData = JSON.stringify({
          type: 'tree',
          id: tree.id,
          code: tree.treeCode,
        });
        return await QRCode.toBuffer(qrData, {
          width: 200,
          margin: 1,
        });
      }),
    );

    // Combine QR codes into a single PDF for printing
    const PDFDocument = require('pdfkit');
    const doc = new PDFDocument({ autoFirstPage: false });
    
    doc.addPage({ size: 'A4', layout: 'landscape' });
    
    let x = 20;
    let y = 20;
    const cols = 4;
    const spacing = 20;
    const qrSize = 180;
    
    for (let i = 0; i < qrCodes.length; i++) {
      doc.image(qrCodes[i], x, y, { width: qrSize });
      doc.fontSize(10).text(trees[i].treeCode, x + qrSize / 2 - 20, y + qrSize + 5);
      
      x += qrSize + spacing;
      if ((i + 1) % cols === 0) {
        x = 20;
        y += qrSize + 50;
      }
      
      if (y > 500) {
        doc.addPage({ size: 'A4', layout: 'landscape' });
        x = 20;
        y = 20;
      }
    }
    
    doc.end();
    return new Promise((resolve) => {
      const chunks: Buffer[] = [];
      doc.on('data', (chunk) => chunks.push(chunk));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
    });
  }

  async scanQrCode(qrData: string): Promise<any> {
    try {
      const data = JSON.parse(qrData);
      
      if (data.type === 'tree') {
        const tree = await this.prisma.tree.findUnique({
          where: { id: data.id },
          include: {
            block: true,
            inspections: {
              orderBy: { createdAt: 'desc' },
              take: 10,
            },
            harvests: {
              orderBy: { harvestDate: 'desc' },
              take: 5,
            },
          },
        });
        
        if (!tree) {
          throw new NotFoundException('Tree not found');
        }
        
        return {
          type: 'tree',
          data: tree,
        };
      }
      
      return { type: 'unknown', data };
    } catch (e) {
      return { type: 'invalid', data: qrData };
    }
  }

  async getTreeHistory(treeId: string) {
    const [inspections, harvests] = await Promise.all([
      this.prisma.inspection.findMany({
        where: { treeId },
        orderBy: { createdAt: 'desc' },
        include: { creator: { select: { name: true } } },
      }),
      this.prisma.harvest.findMany({
        where: { treeId },
        orderBy: { harvestDate: 'desc' },
        include: { creator: { select: { name: true } } },
      }),
    ]);

    return {
      treeId,
      inspections,
      harvests,
      totalInspections: inspections.length,
      totalHarvests: harvests.length,
      totalProduction: harvests.reduce((sum, h) => sum + h.tonase, 0),
      lastInspection: inspections.first,
      lastHarvest: harvests.first,
    };
  }
}