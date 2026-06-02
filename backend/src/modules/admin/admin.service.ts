import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.module';

@Injectable()
export class AdminService {
  private readonly logger = new Logger(AdminService.name);

  constructor(private prisma: PrismaService) {}

  async getMultiEstateDashboard() {
    const [
      estates,
      totalHarvests,
      totalMissions,
      totalWorkOrders,
      pestSummary,
      productionTrend,
    ] = await Promise.all([
      this.getEstatesSummary(),
      this.getTotalHarvests(),
      this.getTotalDroneMissions(),
      this.getWorkOrdersSummary(),
      this.getPestSummaryByEstate(),
      this.getProductionTrendAllEstates(),
    ]);
    
    return {
      summary: {
        totalEstates: estates.length,
        totalArea: estates.reduce((sum, e) => sum + (e.totalArea || 0), 0),
        totalHarvests: totalHarvests,
        totalDroneMissions: totalMissions,
        activeWorkOrders: totalWorkOrders.active,
        completedWorkOrders: totalWorkOrders.completed,
      },
      estates,
      pestSummary,
      productionTrend,
      alerts: await this.getGlobalAlerts(),
      topPerformers: await this.getTopPerformingEstates(),
    };
  }

  private async getEstatesSummary() {
    const estates = await this.prisma.estate.findMany({
      include: {
        blocks: true,
        users: {
          select: { id: true, name: true, role: true },
        },
        droneMissions: {
          orderBy: { flightDate: 'desc' },
          take: 1,
        },
      },
    });
    
    return estates.map(estate => ({
      id: estate.id,
      name: estate.name,
      location: estate.location,
      totalArea: estate.totalArea,
      totalBlocks: estate.blocks.length,
      totalWorkers: estate.users.length,
      lastDroneMission: estate.droneMissions[0]?.flightDate,
      healthScore: this.calculateEstateHealthScore(estate),
    }));
  }

  private calculateEstateHealthScore(estate: any): number {
    // Simplified health score calculation
    let score = 75; // base score
    
    // Adjust based on recent drone missions
    if (estate.droneMissions.length > 0) {
      const lastMission = estate.droneMissions[0];
      if (lastMission.pestSeverityScore) {
        score -= lastMission.pestSeverityScore / 2;
      }
    }
    
    return Math.max(0, Math.min(100, score));
  }

  private async getTotalHarvests(): Promise<number> {
    const result = await this.prisma.harvest.aggregate({
      _count: { id: true },
    });
    return result._count.id;
  }

  private async getTotalDroneMissions(): Promise<number> {
    return this.prisma.droneMission.count();
  }

  private async getWorkOrdersSummary() {
    const [active, completed] = await Promise.all([
      this.prisma.workOrder.count({
        where: { status: { in: ['PENDING', 'APPROVED', 'IN_PROGRESS'] } },
      }),
      this.prisma.workOrder.count({
        where: { status: 'COMPLETED' },
      }),
    ]);
    
    return { active, completed };
  }

  private async getPestSummaryByEstate() {
    const detections = await this.prisma.pestDetection.findMany({
      include: {
        droneMission: {
          include: { estate: true },
        },
      },
      where: {
        createdAt: { gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) },
      },
    });
    
    const byEstate: Record<string, any> = {};
    
    for (const det of detections) {
      const estateName = det.droneMission.estate.name;
      if (!byEstate[estateName]) {
        byEstate[estateName] = {
          estateName,
          pests: {},
          totalDetections: 0,
        };
      }
      
      if (!byEstate[estateName].pests[det.detectedPest]) {
        byEstate[estateName].pests[det.detectedPest] = 0;
      }
      
      byEstate[estateName].pests[det.detectedPest] += det.count;
      byEstate[estateName].totalDetections += det.count;
    }
    
    return Object.values(byEstate);
  }

  private async getProductionTrendAllEstates() {
    const harvests = await this.prisma.harvest.findMany({
      where: {
        harvestDate: { gte: new Date(Date.now() - 90 * 24 * 60 * 60 * 1000) },
      },
      include: {
        block: { include: { estate: true } },
      },
    });
    
    const trends: Record<string, any> = {};
    
    for (const harvest of harvests) {
      const estateName = harvest.block.estate.name;
      const month = harvest.harvestDate.toISOString().slice(0, 7);
      
      if (!trends[estateName]) {
        trends[estateName] = {};
      }
      if (!trends[estateName][month]) {
        trends[estateName][month] = 0;
      }
      
      trends[estateName][month] += harvest.tonase;
    }
    
    return trends;
  }

  private async getGlobalAlerts() {
    const alerts = [];
    
    // Check for estates with low health score
    const estates = await this.getEstatesSummary();
    for (const estate of estates) {
      if (estate.healthScore < 50) {
        alerts.push({
          type: 'LOW_HEALTH_SCORE',
          severity: 'HIGH',
          estateName: estate.name,
          message: `Health score below 50% (${estate.healthScore}%)`,
        });
      }
    }
    
    // Check for pending urgent work orders
    const urgentOrders = await this.prisma.workOrder.count({
      where: {
        priority: 'URGENT',
        status: { not: 'COMPLETED' },
        dueDate: { lt: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000) },
      },
    });
    
    if (urgentOrders > 0) {
      alerts.push({
        type: 'URGENT_WORK_ORDERS',
        severity: 'HIGH',
        message: `${urgentOrders} urgent work orders need attention`,
      });
    }
    
    return alerts;
  }

  private async getTopPerformingEstates() {
    const estates = await this.getEstatesSummary();
    
    return estates
      .sort((a, b) => b.healthScore - a.healthScore)
      .slice(0, 5)
      .map((e, index) => ({
        rank: index + 1,
        name: e.name,
        healthScore: e.healthScore,
        totalProduction: e.totalArea * 20, // estimated
      }));
  }

  async getEstateDetail(estateId: string) {
    const estate = await this.prisma.estate.findUnique({
      where: { id: estateId },
      include: {
        blocks: true,
        users: true,
        droneMissions: {
          orderBy: { flightDate: 'desc' },
          take: 5,
        },
        workOrders: {
          orderBy: { createdAt: 'desc' },
          take: 10,
        },
      },
    });
    
    return estate;
  }
}