import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateHarvestDto } from './dto/create-harvest.dto';
import { SyncHarvestDto } from './dto/sync-harvest.dto';

@Injectable()
export class HarvestService {
  constructor(private prisma: PrismaService) {}

  async create(userId: string, createHarvestDto: CreateHarvestDto) {
    const { blockId, tonase, harvestDate, photoUrl } = createHarvestDto;

    // Verify block exists
    const block = await this.prisma.block.findUnique({
      where: { id: blockId },
    });

    if (!block) {
      throw new NotFoundException('Block not found');
    }

    return this.prisma.harvest.create({
      data: {
        blockId,
        tonase,
        harvestDate: new Date(harvestDate),
        photoUrl,
        createdBy: userId,
      },
      include: {
        block: {
          include: {
            estate: true,
          },
        },
        creator: {
          select: {
            id: true,
            name: true,
          },
        },
      },
    });
  }

  async findAll(userId: string, role: string, filters?: any) {
    const where: any = { isDeleted: false };

    // Non-admin can only see their estate/blocks
    if (role !== 'ADMIN') {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { estateId: true, blockId: true, role: true },
      });

      if (user.role === 'FIELD_WORKER' && user.blockId) {
        where.blockId = user.blockId;
      } else if (user.estateId) {
        where.block = { estateId: user.estateId };
      }
    }

    // Date filters
    if (filters?.startDate) {
      where.harvestDate = { gte: new Date(filters.startDate) };
    }
    if (filters?.endDate) {
      where.harvestDate = { ...where.harvestDate, lte: new Date(filters.endDate) };
    }
    if (filters?.blockId) {
      where.blockId = filters.blockId;
    }

    return this.prisma.harvest.findMany({
      where,
      include: {
        block: {
          include: {
            estate: true,
          },
        },
        creator: {
          select: {
            id: true,
            name: true,
          },
        },
      },
      orderBy: { harvestDate: 'desc' },
    });
  }

  async findOne(id: string, userId: string, role: string) {
    const harvest = await this.prisma.harvest.findUnique({
      where: { id, isDeleted: false },
      include: {
        block: true,
        creator: true,
      },
    });

    if (!harvest) {
      throw new NotFoundException('Harvest not found');
    }

    // Check access
    if (role !== 'ADMIN') {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { estateId: true, blockId: true },
      });

      const block = await this.prisma.block.findUnique({
        where: { id: harvest.blockId },
      });

      if (user.blockId !== harvest.blockId && user.estateId !== block.estateId) {
        throw new ForbiddenException('Access denied');
      }
    }

    return harvest;
  }

  async syncFromMobile(syncData: SyncHarvestDto[]) {
    const results = [];
    
    for (const item of syncData) {
      try {
        const existing = await this.prisma.harvest.findUnique({
          where: { id: item.id },
        });

        if (existing) {
          if (item.isDeleted) {
            await this.prisma.harvest.update({
              where: { id: item.id },
              data: { isDeleted: true, syncedAt: new Date() },
            });
          } else {
            // Last-write-wins: compare timestamps
            if (new Date(item.harvestDate) > existing.harvestDate) {
              await this.prisma.harvest.update({
                where: { id: item.id },
                data: {
                  tonase: item.tonase,
                  harvestDate: new Date(item.harvestDate),
                  photoUrl: item.photoUrl,
                  syncedAt: new Date(),
                },
              });
            }
          }
          results.push({ id: item.id, status: 'updated' });
        } else {
          await this.prisma.harvest.create({
            data: {
              id: item.id,
              blockId: item.blockId,
              tonase: item.tonase,
              harvestDate: new Date(item.harvestDate),
              photoUrl: item.photoUrl,
              createdBy: 'system_sync',
              syncedAt: new Date(),
            },
          });
          results.push({ id: item.id, status: 'created' });
        }
      } catch (error) {
        results.push({ id: item.id, status: 'failed', error: error.message });
      }
    }

    return results;
  }

  async getSummary(userId: string, role: string, startDate: Date, endDate: Date) {
    const harvests = await this.findAll(userId, role, { startDate, endDate });
    
    const totalTonase = harvests.reduce((sum, h) => sum + h.tonase, 0);
    const dailyData = this.groupByDate(harvests);
    const weeklyData = this.groupByWeek(harvests);
    const monthlyData = this.groupByMonth(harvests);

    return {
      totalTonase,
      averagePerDay: harvests.length > 0 ? totalTonase / harvests.length : 0,
      dailyData,
      weeklyData,
      monthlyData,
      totalRecords: harvests.length,
    };
  }

  private groupByDate(harvests: any[]) {
    const groups: Record<string, number> = {};
    for (const h of harvests) {
      const date = h.harvestDate.toISOString().split('T')[0];
      groups[date] = (groups[date] || 0) + h.tonase;
    }
    return Object.entries(groups).map(([date, tonase]) => ({ date, tonase }));
  }

  private groupByWeek(harvests: any[]) {
    const groups: Record<string, number> = {};
    for (const h of harvests) {
      const week = this.getWeekNumber(h.harvestDate);
      groups[week] = (groups[week] || 0) + h.tonase;
    }
    return groups;
  }

  private groupByMonth(harvests: any[]) {
    const groups: Record<string, number> = {};
    for (const h of harvests) {
      const month = `${h.harvestDate.getFullYear()}-${h.harvestDate.getMonth() + 1}`;
      groups[month] = (groups[month] || 0) + h.tonase;
    }
    return groups;
  }

  private getWeekNumber(date: Date): string {
    const firstDayOfYear = new Date(date.getFullYear(), 0, 1);
    const pastDaysOfYear = (date.getTime() - firstDayOfYear.getTime()) / 86400000;
    const week = Math.ceil((pastDaysOfYear + firstDayOfYear.getDay() + 1) / 7);
    return `${date.getFullYear()}-W${week}`;
  }
}