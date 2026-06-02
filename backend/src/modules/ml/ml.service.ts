import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.module';
import * as tf from '@tensorflow/tfjs-node';
import * as sharp from 'sharp';
import axios from 'axios';

@Injectable()
export class MlService {
  private readonly logger = new Logger(MlService.name);
  private model: tf.GraphModel | null = null;
  private pestLabels = [
    'Rusa', 'Kumbang Tanduk', 'Ulat Api', 'Kutu Putih', 'Tikus',
    'Healthy - No Pest', 'Ganoderma', 'Busuk Pangkal Batang',
  ];

  constructor(private prisma: PrismaService) {
    this.loadModel();
  }

  private async loadModel() {
    try {
      // Load pre-trained model from storage
      // In production, you would host the model on S3 or local
      const modelPath = process.env.MODEL_PATH || './models/pest-detection/model.json';
      this.model = await tf.loadGraphModel(`file://${modelPath}`);
      this.logger.log('ML Model loaded successfully');
    } catch (error) {
      this.logger.error('Failed to load ML model', error);
      // Fallback: use mock predictions
    }
  }

  async detectPest(imageBuffer: Buffer, imageUrl?: string): Promise<PestDetectionResult> {
    try {
      // Preprocess image
      const processedImage = await this.preprocessImage(imageBuffer);
      
      // Run inference
      let predictions;
      if (this.model) {
        const tensor = tf.tensor(processedImage);
        const output = this.model.predict(tensor) as tf.Tensor;
        predictions = await output.data();
        tensor.dispose();
        output.dispose();
      } else {
        // Mock predictions for testing
        predictions = this.generateMockPredictions();
      }
      
      // Parse results
      const results = this.parsePredictions(predictions);
      
      // Save detection record
      const detection = await this.saveDetection(results, imageUrl);
      
      return {
        id: detection.id,
        detections: results,
        recommendation: this.generateRecommendation(results),
        confidence: results[0].confidence,
        imageUrl,
        createdAt: new Date(),
      };
    } catch (error) {
      this.logger.error('Pest detection failed', error);
      throw new Error(`Pest detection failed: ${error.message}`);
    }
  }

  private async preprocessImage(buffer: Buffer): Promise<tf.Tensor3D> {
    // Resize image to model input size (e.g., 224x224)
    const resized = await sharp(buffer)
      .resize(224, 224)
      .toBuffer();
    
    // Convert to tensor and normalize
    const tensor = tf.node.decodeImage(resized, 3);
    const normalized = tensor.div(255.0);
    
    return normalized as tf.Tensor3D;
  }

  private parsePredictions(predictions: Float32Array): PestDetection[] {
    const results: PestDetection[] = [];
    
    for (let i = 0; i < predictions.length; i++) {
      results.push({
        pestName: this.pestLabels[i],
        confidence: predictions[i],
        severity: this.getSeverity(predictions[i], i),
      });
    }
    
    return results.sort((a, b) => b.confidence - a.confidence);
  }

  private getSeverity(confidence: number, pestIndex: number): 'LOW' | 'MEDIUM' | 'HIGH' {
    // Healthy (index 5) shouldn't have severity
    if (pestIndex === 5) return 'LOW';
    
    if (confidence > 0.7) return 'HIGH';
    if (confidence > 0.4) return 'MEDIUM';
    return 'LOW';
  }

  private generateRecommendation(detections: PestDetection[]): Recommendation {
    const topPest = detections[0];
    
    const recommendations: Record<string, { action: string; pesticide: string; note: string }> = {
      'Rusa': {
        action: 'Pasang pagar elektrik atau pagar kawat di sekeliling kebun',
        pesticide: 'Tidak diperlukan pestisida, gunakan pengusir fisik',
        note: 'Rusa aktif di malam hari. Tambahkan lampu sensor gerak',
      },
      'Kumbang Tanduk': {
        action: 'Semprot dengan insektisida berbahan aktif Sipermetrin',
        pesticide: 'Sipermetrin 200 EC (2 ml/L air)',
        note: 'Aplikasi pada sore hari, ulangi setiap 2 minggu',
      },
      'Ulat Api': {
        action: 'Semprot dengan Bacillus thuringiensis atau insektisida sistemik',
        pesticide: 'Bacillus thuringiensis (1 g/L) atau Klorantraniliprol',
        note: 'Lakukan pemangkasan pelepah terserang',
      },
      'Kutu Putih': {
        action: 'Aplikasi insektisida sistemik dan semprot minyak nabati',
        pesticide: 'Imidakloprid 70 WG (0.5 g/L)',
        note: 'Perkuat dengan predator alami seperti kumbang koksi',
      },
      'Tikus': {
        action: 'Pasang perangkap tikus dan rodentisida',
        pesticide: 'Racun tikus berbahan aktif Brodifakum',
        note: 'Pasang perangkap di jalur tikus aktif',
      },
      'Ganoderma': {
        action: 'Eradikasi pohon terinfeksi, aplikasi fungisida sistemik',
        pesticide: 'Heksakonazol atau Tridemorf',
        note: 'Buat parit isolasi untuk mencegah penyebaran',
      },
    };
    
    const rec = recommendations[topPest.pestName] || {
      action: 'Lakukan inspeksi lebih lanjut',
      pesticide: 'Konsultasikan dengan ahli',
      note: 'Dokumentasikan kondisi pohon secara berkala',
    };
    
    return {
      pestName: topPest.pestName,
      confidence: topPest.confidence,
      action: rec.action,
      pesticide: rec.pesticide,
      note: rec.note,
      severity: topPest.severity,
    };
  }

  private generateMockPredictions(): Float32Array {
    // Mock prediction for testing
    const mock = new Float32Array(8);
    for (let i = 0; i < 8; i++) {
      mock[i] = Math.random() * 0.5;
    }
    // Make healthy more likely
    mock[5] = 0.6;
    return mock;
  }

  private async saveDetection(results: PestDetection[], imageUrl?: string) {
    return this.prisma.pestDetection.create({
      data: {
        imageUrl: imageUrl || '',
        detectedPest: results[0].pestName,
        confidence: results[0].confidence,
        severity: results[0].severity,
        fullResults: JSON.stringify(results),
        recommendation: JSON.stringify(this.generateRecommendation(results)),
      },
    });
  }

  async analyzeBlockHealth(blockId: string) {
    const inspections = await this.prisma.inspection.findMany({
      where: {
        blockId,
        createdAt: { gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) },
      },
      orderBy: { createdAt: 'desc' },
    });
    
    const pestDetections = await this.prisma.pestDetection.findMany({
      where: {
        inspection: { blockId },
        createdAt: { gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) },
      },
    });
    
    const pestFrequency = pestDetections.reduce((acc, d) => {
      acc[d.detectedPest] = (acc[d.detectedPest] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);
    
    const healthScore = this.calculateHealthScore(inspections, pestDetections);
    
    return {
      blockId,
      healthScore,
      pestFrequency,
      totalInspections: inspections.length,
      pestDetections: pestDetections.length,
      recommendation: this.getBlockRecommendation(healthScore),
      timestamp: new Date(),
    };
  }

  private calculateHealthScore(inspections: any[], pestDetections: any[]): number {
    let score = 100;
    
    // Deduct for poor conditions
    for (const inspection of inspections) {
      if (inspection.condition === 'SEVERE_DAMAGE') score -= 10;
      else if (inspection.condition === 'MILD_DAMAGE') score -= 5;
      else if (inspection.condition === 'DEAD') score -= 15;
    }
    
    // Deduct for pest detections
    for (const detection of pestDetections) {
      if (detection.severity === 'HIGH') score -= 15;
      else if (detection.severity === 'MEDIUM') score -= 8;
      else score -= 3;
    }
    
    return Math.max(0, Math.min(100, score));
  }

  private getBlockRecommendation(score: number): string {
    if (score >= 80) {
      return 'Blok dalam kondisi sehat. Lanjutkan monitoring rutin.';
    } else if (score >= 60) {
      return 'Perlu perhatian. Lakukan inspeksi lebih detail dan pengendalian hama terarah.';
    } else if (score >= 40) {
      return 'Kondisi mengkhawatirkan. Segera lakukan tindakan pengendalian dan konsultasi dengan ahli.';
    } else {
      return 'KRITIS! Segera koordinasi dengan tim manajemen untuk tindakan darurat.';
    }
  }

  async getTreatmentHistory(blockId: string) {
    return this.prisma.pestTreatment.findMany({
      where: { blockId },
      orderBy: { appliedAt: 'desc' },
      include: { appliedBy: { select: { name: true } } },
    });
  }

  async saveTreatment(data: {
    blockId: string;
    pestName: string;
    treatmentType: string;
    pesticideUsed: string;
    dosage: string;
    areaTreated: number;
    notes: string;
    appliedBy: string;
  }) {
    return this.prisma.pestTreatment.create({
      data: {
        ...data,
        appliedAt: new Date(),
      },
    });
  }
}

interface PestDetection {
  pestName: string;
  confidence: number;
  severity: 'LOW' | 'MEDIUM' | 'HIGH';
}

interface Recommendation {
  pestName: string;
  confidence: number;
  action: string;
  pesticide: string;
  note: string;
  severity: string;
}

interface PestDetectionResult {
  id: string;
  detections: PestDetection[];
  recommendation: Recommendation;
  confidence: number;
  imageUrl?: string;
  createdAt: Date;
}