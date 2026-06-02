import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.module';
import { NotificationService } from '../notification/notification.service';

@Injectable()
export class WorkOrderService {
  private readonly logger = new Logger(WorkOrderService.name);

  constructor(
    private prisma: PrismaService,
    private notificationService: NotificationService,
  ) {}

  async generateWorkOrdersFromDroneMission(missionId: string) {
    const mission = await this.prisma.droneMission.findUnique({
      where: { id: missionId },
      include: { estate: true },
    });
    
    if (!mission) {
      throw new Error('Mission not found');
    }
    
    const workOrders = [];
    
    // Generate from pest detections
    if (mission.pestDetections) {
      const pestOrders = await this.createPestControlOrders(mission);
      workOrders.push(...pestOrders);
    }
    
    // Generate from health statistics
    if (mission.statistics) {
      const healthOrders = await this.createHealthBasedOrders(mission);
      workOrders.push(...healthOrders);
    }
    
    // Generate from thermal/water stress
    if (mission.waterStressZones) {
      const waterOrders = await this.createWaterStressOrders(mission);
      workOrders.push(...waterOrders);
    }
    
    return workOrders;
  }

  private async createPestControlOrders(mission: any): Promise<any[]> {
    const orders = [];
    const pests = mission.pestDetections;
    
    for (const [pestType, data] of Object.entries(pests)) {
      if (data.count > 3 || data.severity === 'HIGH' || data.severity === 'CRITICAL') {
        const workOrder = await this.prisma.workOrder.create({
          data: {
            estateId: mission.estateId,
            droneMissionId: mission.id,
            type: 'PEST_CONTROL',
            title: `Pengendalian Hama ${data.pestName || pestType}`,
            description: `Deteksi ${data.count} titik serangan ${pestType} dengan confidence ${(data.avgConfidence * 100).toFixed(1)}%`,
            priority: this.getPriorityFromSeverity(data.severity),
            estimatedDuration: data.count * 2, // hours
            estimatedCost: this.calculateCost(pestType, data.count),
            assignedTo: mission.estate.supervisorId,
            status: 'PENDING',
            dueDate: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000),
            metadata: {
              pestType,
              affectedCount: data.count,
              locations: data.locations || [],
            },
          },
        });
        
        orders.push(workOrder);
        
        // Send notification
        await this.notificationService.sendNotification(
          mission.estate.supervisorId,
          'Work Order Generated',
          `Work order for ${pestType} control has been created`,
          { type: 'work_order', workOrderId: workOrder.id },
        );
      }
    }
    
    return orders;
  }

  private async createHealthBasedOrders(mission: any): Promise<any[]> {
    const orders = [];
    const stats = mission.statistics;
    
    if (stats.percentages?.unhealthy > 15) {
      const workOrder = await this.prisma.workOrder.create({
        data: {
          estateId: mission.estateId,
          droneMissionId: mission.id,
          type: 'FERTILIZATION',
          title: 'Fertilisasi Area Tidak Sehat',
          description: `${stats.percentages.unhealthy}% area menunjukkan kesehatan rendah. Diperlukan fertilisasi tambahan.`,
          priority: 'HIGH',
          estimatedDuration: 48,
          estimatedCost: 5000000,
          assignedTo: mission.estate.supervisorId,
          status: 'PENDING',
          dueDate: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000),
          metadata: {
            unhealthyArea: stats.percentages.unhealthy,
            stressedArea: stats.percentages.stressed,
          },
        },
      });
      
      orders.push(workOrder);
    }
    
    if (stats.percentages?.dead > 5) {
      const workOrder = await this.prisma.workOrder.create({
        data: {
          estateId: mission.estateId,
          droneMissionId: mission.id,
          type: 'REPLANTING',
          title: 'Penanaman Ulang Area Mati',
          description: `${stats.percentages.dead}% area teridentifikasi mati. Perlu penanaman ulang.`,
          priority: 'HIGH',
          estimatedDuration: 120,
          estimatedCost: 15000000,
          assignedTo: mission.estate.supervisorId,
          status: 'PENDING',
          dueDate: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000),
          metadata: {
            deadArea: stats.percentages.dead,
            recommendedVariety: 'DxP Yangambi',
          },
        },
      });
      
      orders.push(workOrder);
    }
    
    return orders;
  }

  private async createWaterStressOrders(mission: any): Promise<any[]> {
    const orders = [];
    const stressZones = mission.waterStressZones;
    
    if (stressZones && stressZones.length > 0) {
      const workOrder = await this.prisma.workOrder.create({
        data: {
          estateId: mission.estateId,
          droneMissionId: mission.id,
          type: 'IRRIGATION',
          title: 'Irigasi Area Water Stress',
          description: `${stressZones.length} area terdeteksi mengalami water stress. Perlu irigasi tambahan.`,
          priority: 'URGENT',
          estimatedDuration: 24,
          estimatedCost: 3000000,
          assignedTo: mission.estate.supervisorId,
          status: 'PENDING',
          dueDate: new Date(Date.now() + 1 * 24 * 60 * 60 * 1000),
          metadata: {
            stressZones: stressZones.map(z => ({ location: z.location, severity: z.severity })),
          },
        },
      });
      
      orders.push(workOrder);
    }
    
    return orders;
  }

  async getWorkOrders(estateId: string, status?: string, limit = 50, offset = 0) {
    const where: any = { estateId };
    if (status) where.status = status;
    
    return this.prisma.workOrder.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: limit,
      skip: offset,
      include: {
        assignedToUser: { select: { id: true, name: true } },
        droneMission: true,
        tasks: true,
      },
    });
  }

  async updateWorkOrderStatus(orderId: string, status: string, userId: string) {
    const workOrder = await this.prisma.workOrder.update({
      where: { id: orderId },
      data: {
        status,
        completedAt: status === 'COMPLETED' ? new Date() : undefined,
      },
    });
    
    // Create task for field workers
    if (status === 'APPROVED') {
      await this.createTasksFromWorkOrder(workOrder);
    }
    
    return workOrder;
  }

  private async createTasksFromWorkOrder(workOrder: any) {
    const tasks = [];
    
    // Create sub-tasks based on work order type
    if (workOrder.type === 'PEST_CONTROL') {
      const task1 = await this.prisma.task.create({
        data: {
          workOrderId: workOrder.id,
          title: `Spraying - ${workOrder.title}`,
          description: workOrder.description,
          type: 'PEST_CONTROL',
          blockId: workOrder.metadata?.blockId,
          assignedTo: workOrder.assignedTo,
          assignedBy: 'system',
          dueDate: workOrder.dueDate,
        },
      });
      tasks.push(task1);
    }
    
    return tasks;
  }

  private getPriorityFromSeverity(severity: string): string {
    switch (severity) {
      case 'CRITICAL': return 'URGENT';
      case 'HIGH': return 'HIGH';
      case 'MEDIUM': return 'MEDIUM';
      default: return 'LOW';
    }
  }

  private calculateCost(pestType: string, count: number): number {
    const baseCosts: Record<string, number> = {
      'RUSA': 500000,
      'KUMBANG_TANDUK': 300000,
      'ULAT_API': 200000,
      'KUTU_PUTIH': 150000,
      'TIKUS': 250000,
      'GANODERMA': 2000000,
      'BUSUK_PANGKAL': 1000000,
      'NEMATODA': 400000,
    };
    
    return (baseCosts[pestType] || 200000) * Math.ceil(count / 10);
  }
}