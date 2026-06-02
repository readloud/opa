import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AnalyticsService {
  constructor(private prisma: PrismaService) {}

  async getDashboardStats(
    estateId: string,
    startDate: Date,
    endDate: Date,
  ) {
    // Parallel queries for better performance
    const [
      productionStats,
      inspectionStats,
      fertilizationStats,
      taskStats,
      topBlocks,
      monthlyTrend,
    ] = await Promise.all([
      this.getProductionStats(estateId, startDate, endDate),
      this.getInspectionStats(estateId, startDate, endDate),
      this.getFertilizationStats(estateId, startDate, endDate),
      this.getTaskStats(estateId),
      this.getTopBlocks(estateId, startDate, endDate),
      this.getMonthlyTrend(estateId, startDate, endDate),
    ]);

    return {
      period: {
        startDate,
        endDate,
      },
      summary: {
        totalProduction: productionStats.total,
        averageProductionPerDay: productionStats.averagePerDay,
        totalInspections: inspectionStats.total,
        healthyPercentage: inspectionStats.healthyPercentage,
        totalFertilizations: fertilizationStats.total,
        totalFertilizerKg: fertilizationStats.totalKg,
        completedTasks: taskStats.completed,
        pendingTasks: taskStats.pending,
      },
      productionStats,
      inspectionStats,
      fertilizationStats,
      taskStats,
      topBlocks,
      monthlyTrend,
    };
  }

  private async getProductionStats(estateId: string, startDate: Date, endDate: Date) {
    const harvests = await this.prisma.harvest.findMany({
      where: {
        harvestDate: { gte: startDate, lte: endDate },
        block: { estateId },
        isDeleted: false,
      },
      select: {
        tonase: true,
        harvestDate: true,
        block: { select: { name: true } },
      },
      orderBy: { harvestDate: 'asc' },
    });

    const total = harvests.reduce((sum, h) => sum + h.tonase, 0);
    const averagePerDay = total / this.getDaysDifference(startDate, endDate);
    
    // Daily breakdown for chart
    const dailyData = this.groupByDate(harvests, 'harvestDate');
    
    // Weekly breakdown
    const weeklyData = this.groupByWeek(harvests);
    
    // By block
    const byBlock = this.groupByBlock(harvests, 'tonase');

    return {
      total,
      averagePerDay,
      totalRecords: harvests.length,
      dailyData,
      weeklyData,
      byBlock,
    };
  }

  private async getInspectionStats(estateId: string, startDate: Date, endDate: Date) {
    const inspections = await this.prisma.inspection.findMany({
      where: {
        createdAt: { gte: startDate, lte: endDate },
        block: { estateId },
        isDeleted: false,
      },
      select: {
        condition: true,
        createdAt: true,
        block: { select: { name: true } },
      },
    });

    const total = inspections.length;
    const conditionCount = {
      HEALTHY: inspections.filter(i => i.condition === 'HEALTHY').length,
      MILD_DAMAGE: inspections.filter(i => i.condition === 'MILD_DAMAGE').length,
      SEVERE_DAMAGE: inspections.filter(i => i.condition === 'SEVERE_DAMAGE').length,
      DEAD: inspections.filter(i => i.condition === 'DEAD').length,
    };

    const healthyPercentage = total > 0 ? (conditionCount.HEALTHY / total) * 100 : 0;
    
    // Daily trend
    const dailyTrend = this.groupByDate(inspections, 'createdAt');
    
    // By block
    const byBlock = this.groupByBlock(inspections, 'condition');

    return {
      total,
      healthyPercentage,
      conditionCount,
      dailyTrend,
      byBlock,
    };
  }

  private async getFertilizationStats(estateId: string, startDate: Date, endDate: Date) {
    const fertilizations = await this.prisma.fertilization.findMany({
      where: {
        applicationDate: { gte: startDate, lte: endDate },
        block: { estateId },
        isDeleted: false,
      },
      select: {
        fertilizerType: true,
        quantity: true,
        applicationDate: true,
        block: { select: { name: true } },
      },
    });

    const totalKg = fertilizations.reduce((sum, f) => sum + f.quantity, 0);
    
    // By fertilizer type
    const byType = fertilizations.reduce((acc, f) => {
      acc[f.fertilizerType] = (acc[f.fertilizerType] || 0) + f.quantity;
      return acc;
    }, {} as Record<string, number>);
    
    // Monthly usage
    const monthlyUsage = this.groupByMonth(fertilizations, 'quantity');
    
    // By block
    const byBlock = this.groupByBlock(fertilizations, 'quantity');

    return {
      totalKg,
      totalRecords: fertilizations.length,
      byType,
      monthlyUsage,
      byBlock,
    };
  }

  private async getTaskStats(estateId: string) {
    const tasks = await this.prisma.task.findMany({
      where: {
        block: { estateId },
      },
      select: {
        status: true,
        type: true,
      },
    });

    const completed = tasks.filter(t => t.status === 'COMPLETED').length;
    const pending = tasks.filter(t => t.status === 'PENDING').length;
    const inProgress = tasks.filter(t => t.status === 'IN_PROGRESS').length;
    const cancelled = tasks.filter(t => t.status === 'CANCELLED').length;
    
    // By type
    const byType = tasks.reduce((acc, t) => {
      acc[t.type] = (acc[t.type] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);

    return {
      completed,
      pending,
      inProgress,
      cancelled,
      total: tasks.length,
      completionRate: tasks.length > 0 ? (completed / tasks.length) * 100 : 0,
      byType,
    };
  }

  private async getTopBlocks(estateId: string, startDate: Date, endDate: Date) {
    const harvests = await this.prisma.harvest.findMany({
      where: {
        harvestDate: { gte: startDate, lte: endDate },
        block: { estateId },
        isDeleted: false,
      },
      include: {
        block: true,
      },
    });

    const blockStats = harvests.reduce((acc, h) => {
      if (!acc[h.block.name]) {
        acc[h.block.name] = { tonase: 0, count: 0 };
      }
      acc[h.block.name].tonase += h.tonase;
      acc[h.block.name].count++;
      return acc;
    }, {} as Record<string, { tonase: number; count: number }>);

    return Object.entries(blockStats)
      .map(([name, stats]) => ({
        blockName: name,
        totalTonase: stats.tonase,
        averagePerHarvest: stats.tonase / stats.count,
        harvestCount: stats.count,
      }))
      .sort((a, b) => b.totalTonase - a.totalTonase)
      .slice(0, 5);
  }

  private async getMonthlyTrend(estateId: string, startDate: Date, endDate: Date) {
    const harvests = await this.prisma.harvest.findMany({
      where: {
        harvestDate: { gte: startDate, lte: endDate },
        block: { estateId },
        isDeleted: false,
      },
      select: {
        tonase: true,
        harvestDate: true,
      },
    });

    const monthlyData = this.groupByMonth(harvests, 'tonase');
    
    // Convert to array format for chart
    return Object.entries(monthlyData).map(([month, tonase]) => ({
      month,
      tonase,
    }));
  }

  private groupByDate(data: any[], dateField: string): any[] {
    const groups: Record<string, number> = {};
    for (const item of data) {
      const date = item[dateField].toISOString().split('T')[0];
      const value = item.tonase !== undefined ? item.tonase : 1;
      groups[date] = (groups[date] || 0) + value;
    }
    
    return Object.entries(groups).map(([date, value]) => ({
      date,
      value,
    }));
  }

  private groupByWeek(data: any[]): any[] {
    const groups: Record<string, number> = {};
    for (const item of data) {
      const week = this.getWeekNumber(item.harvestDate || item.createdAt);
      groups[week] = (groups[week] || 0) + (item.tonase || 1);
    }
    
    return Object.entries(groups).map(([week, value]) => ({
      week,
      value,
    }));
  }

  private groupByMonth(data: any[], valueField: string): Record<string, number> {
    const groups: Record<string, number> = {};
    for (const item of data) {
      const date = item.harvestDate || item.applicationDate || item.createdAt;
      const month = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
      const value = item[valueField] !== undefined ? item[valueField] : 1;
      groups[month] = (groups[month] || 0) + value;
    }
    return groups;
  }

  private groupByBlock(data: any[], valueField: string): any[] {
    const groups: Record<string, number> = {};
    for (const item of data) {
      const blockName = item.block?.name || 'Unknown';
      const value = item[valueField] !== undefined ? item[valueField] : 1;
      groups[blockName] = (groups[blockName] || 0) + value;
    }
    
    return Object.entries(groups).map(([block, value]) => ({
      block,
      value,
    }));
  }

  private getDaysDifference(startDate: Date, endDate: Date): number {
    const diff = endDate.getTime() - startDate.getTime();
    return Math.max(1, Math.ceil(diff / (1000 * 3600 * 24)));
  }

  private getWeekNumber(date: Date): string {
    const firstDayOfYear = new Date(date.getFullYear(), 0, 1);
    const pastDaysOfYear = (date.getTime() - firstDayOfYear.getTime()) / 86400000;
    const week = Math.ceil((pastDaysOfYear + firstDayOfYear.getDay() + 1) / 7);
    return `${date.getFullYear()}-W${week}`;
  }

  async getRealtimeStats(estateId: string) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const [todayHarvest, todayTasks, pendingTasks] = await Promise.all([
      this.prisma.harvest.aggregate({
        where: {
          harvestDate: { gte: today, lt: tomorrow },
          block: { estateId },
          isDeleted: false,
        },
        _sum: { tonase: true },
      }),
      this.prisma.task.count({
        where: {
          dueDate: { gte: today, lt: tomorrow },
          block: { estateId },
          status: { not: 'COMPLETED' },
        },
      }),
      this.prisma.task.count({
        where: {
          dueDate: { lt: today },
          status: 'PENDING',
          block: { estateId },
        },
      }),
    ]);

    return {
      todayProduction: todayHarvest._sum.tonase || 0,
      todayTasks,
      pendingTasks,
      lastUpdated: new Date(),
    };
  }
}