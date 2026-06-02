import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import * as XLSX from 'xlsx';
import * as csv from 'csv-parser';
import { Readable } from 'stream';
import * as Papa from 'papaparse';

@Injectable()
export class ImportService {
  private readonly logger = new Logger(ImportService.name);

  constructor(private prisma: PrismaService) {}

  async importHarvestFromFile(
    file: Express.Multer.File,
    estateId: string,
    userId: string,
  ): Promise<ImportResult> {
    const data = await this.parseFile(file);
    const results: ImportResult = {
      total: 0,
      success: 0,
      failed: 0,
      errors: [],
      importedIds: [],
    };

    for (const row of data) {
      try {
        const validated = this.validateHarvestRow(row, estateId);
        const harvest = await this.prisma.harvest.create({
          data: {
            blockId: validated.blockId,
            tonase: validated.tonase,
            harvestDate: validated.harvestDate,
            notes: validated.notes,
            createdBy: userId,
          },
        });
        results.success++;
        results.importedIds.push(harvest.id);
      } catch (error) {
        results.failed++;
        results.errors.push({
          row: row,
          error: error.message,
        });
      }
      results.total++;
    }

    return results;
  }

  async importBlocksFromFile(
    file: Express.Multer.File,
    estateId: string,
  ): Promise<ImportResult> {
    const data = await this.parseFile(file);
    const results: ImportResult = {
      total: 0,
      success: 0,
      failed: 0,
      errors: [],
      importedIds: [],
    };

    for (const row of data) {
      try {
        const block = await this.prisma.block.create({
          data: {
            name: row['Nama Blok'] || row['name'],
            estateId: estateId,
            area: parseFloat(row['Luas'] || row['area'] || 0),
            palmCount: parseInt(row['Jumlah Pohon'] || row['palmCount'] || 0),
            geometry: row['Geometry'] ? JSON.parse(row['Geometry']) : null,
          },
        });
        results.success++;
        results.importedIds.push(block.id);
      } catch (error) {
        results.failed++;
        results.errors.push({
          row: row,
          error: error.message,
        });
      }
      results.total++;
    }

    return results;
  }

  async importTreesFromFile(
    file: Express.Multer.File,
    blockId: string,
  ): Promise<ImportResult> {
    const data = await this.parseFile(file);
    const results: ImportResult = {
      total: 0,
      success: 0,
      failed: 0,
      errors: [],
      importedIds: [],
    };

    // First, check if block exists
    const block = await this.prisma.block.findUnique({
      where: { id: blockId },
    });

    if (!block) {
      throw new BadRequestException('Block not found');
    }

    for (const row of data) {
      try {
        const tree = await this.prisma.tree.create({
          data: {
            treeCode: row['Kode Pohon'] || row['treeCode'],
            blockId: blockId,
            latitude: parseFloat(row['Latitude'] || row['lat'] || 0),
            longitude: parseFloat(row['Longitude'] || row['lng'] || 0),
            plantingDate: row['Tanggal Tanam'] ? new Date(row['Tanggal Tanam']) : null,
            variety: row['Varietas'] || row['variety'],
          },
        });
        results.success++;
        results.importedIds.push(tree.id);
      } catch (error) {
        results.failed++;
        results.errors.push({
          row: row,
          error: error.message,
        });
      }
      results.total++;
    }

    // Update block palm count
    await this.prisma.block.update({
      where: { id: blockId },
      data: { palmCount: results.success },
    });

    return results;
  }

  private async parseFile(file: Express.Multer.File): Promise<any[]> {
    const extension = file.originalname.split('.').pop().toLowerCase();
    
    if (extension === 'csv') {
      return this.parseCSV(file.buffer);
    } else if (extension === 'xlsx' || extension === 'xls') {
      return this.parseExcel(file.buffer);
    } else {
      throw new BadRequestException('Unsupported file format. Use CSV or Excel files.');
    }
  }

  private parseCSV(buffer: Buffer): Promise<any[]> {
    return new Promise((resolve, reject) => {
      const results = [];
      const stream = Readable.from(buffer.toString());
      
      stream
        .pipe(csv())
        .on('data', (data) => results.push(data))
        .on('end', () => resolve(results))
        .on('error', (error) => reject(error));
    });
  }

  private parseExcel(buffer: Buffer): any[] {
    const workbook = XLSX.read(buffer, { type: 'buffer' });
    const sheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[sheetName];
    return XLSX.utils.sheet_to_json(worksheet);
  }

  private validateHarvestRow(row: any, estateId: string): any {
    // Check required fields
    if (!row['Blok'] && !row['block']) {
      throw new Error('Block name is required');
    }
    
    if (!row['Tonase'] && !row['tonase']) {
      throw new Error('Tonase is required');
    }
    
    if (!row['Tanggal'] && !row['date']) {
      throw new Error('Date is required');
    }

    // Find block by name
    const blockName = row['Blok'] || row['block'];
    // In real implementation, you would query the database
    const blockId = 'mock-block-id';

    return {
      blockId: blockId,
      tonase: parseFloat(row['Tonase'] || row['tonase']),
      harvestDate: new Date(row['Tanggal'] || row['date']),
      notes: row['Catatan'] || row['notes'] || '',
    };
  }

  async getImportTemplate(type: string): Promise<Buffer> {
    const workbook = XLSX.utils.book_new();
    
    let headers: string[];
    let exampleData: any[];
    
    switch (type) {
      case 'harvest':
        headers = ['Blok', 'Tonase', 'Tanggal', 'Catatan'];
        exampleData = [
          ['Blok A1', 12.5, '2024-01-15', 'Panen perdana'],
          ['Blok B2', 8.3, '2024-01-15', 'Kualitas baik'],
          ['Blok C3', 15.2, '2024-01-16', 'Produksi tinggi'],
        ];
        break;
      case 'block':
        headers = ['Nama Blok', 'Luas (Ha)', 'Jumlah Pohon', 'Geometry (GeoJSON)'];
        exampleData = [
          ['Blok A1', 25.5, 1250, '{"type":"Polygon","coordinates":[...]}'],
          ['Blok B2', 18.3, 920, '{"type":"Polygon","coordinates":[...]}'],
        ];
        break;
      case 'tree':
        headers = ['Kode Pohon', 'Latitude', 'Longitude', 'Tanggal Tanam', 'Varietas'];
        exampleData = [
          ['TR-001', -6.2088, 106.8456, '2020-01-15', 'DxP'],
          ['TR-002', -6.2089, 106.8457, '2020-01-15', 'DxP'],
        ];
        break;
      default:
        throw new BadRequestException('Invalid template type');
    }
    
    const worksheet = XLSX.utils.json_to_sheet([
      Object.fromEntries(headers.map(h => [h, h])),
      ...exampleData.map(row => Object.fromEntries(headers.map((h, i) => [h, row[i]]))),
    ]);
    
    // Style the header row
    worksheet['!cols'] = headers.map(() => ({ wch: 20 }));
    
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Template');
    
    return XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' });
  }
}

interface ImportResult {
  total: number;
  success: number;
  failed: number;
  errors: Array<{ row: any; error: string }>;
  importedIds: string[];
}