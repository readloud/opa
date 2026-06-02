import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  ConnectedSocket,
  MessageBody,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { UseGuards } from '@nestjs/common';
import { WsJwtGuard } from '../../common/guards/ws-jwt.guard';
import { PrismaService } from '../prisma/prisma.service';

@WebSocketGateway({
  cors: {
    origin: '*',
    credentials: true,
  },
  namespace: '/sync',
})
export class SyncGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private userSockets: Map<string, string[]> = new Map(); // userId -> socketIds[]
  private taskSubscriptions: Map<string, Set<string>> = new Map(); // taskId -> userIds

  constructor(private prisma: PrismaService) {}

  async handleConnection(client: Socket) {
    const token = client.handshake.auth.token;
    if (!token) {
      client.disconnect();
      return;
    }

    try {
      // Verify JWT token
      const userId = this.verifyToken(token);
      client.data.userId = userId;
      
      // Store socket
      if (!this.userSockets.has(userId)) {
        this.userSockets.set(userId, []);
      }
      this.userSockets.get(userId)!.push(client.id);
      
      console.log(`User ${userId} connected with socket ${client.id}`);
      
      // Join user's room
      client.join(`user:${userId}`);
      
      // Send pending notifications
      await this.sendPendingNotifications(userId, client.id);
    } catch (error) {
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    const userId = client.data.userId;
    if (userId && this.userSockets.has(userId)) {
      const sockets = this.userSockets.get(userId)!;
      const index = sockets.indexOf(client.id);
      if (index > -1) sockets.splice(index, 1);
      if (sockets.length === 0) {
        this.userSockets.delete(userId);
      }
    }
    console.log(`Socket ${client.id} disconnected`);
  }

  @SubscribeMessage('subscribe:tasks')
  handleSubscribeTasks(@ConnectedSocket() client: Socket, @MessageBody() data: any) {
    const userId = client.data.userId;
    client.join(`tasks:${userId}`);
    return { event: 'subscribed', data: { tasks: true } };
  }

  @SubscribeMessage('sync:harvest')
  async handleSyncHarvest(@ConnectedSocket() client: Socket, @MessageBody() data: any) {
    const userId = client.data.userId;
    
    // Broadcast to admin/supervisor
    const admins = await this.getAdminUsers();
    for (const adminId of admins) {
      this.server.to(`user:${adminId}`).emit('sync:new-data', {
        type: 'harvest',
        userId: userId,
        data: data,
        timestamp: new Date(),
      });
    }
    
    return { event: 'sync:ack', data: { status: 'received' } };
  }

  @SubscribeMessage('task:update')
  async handleTaskUpdate(@ConnectedSocket() client: Socket, @MessageBody() data: any) {
    const { taskId, status, completedBy } = data;
    
    // Update task in database
    await this.prisma.task.update({
      where: { id: taskId },
      data: {
        status,
        completedAt: status === 'COMPLETED' ? new Date() : null,
      },
    });
    
    // Notify assigned user
    const task = await this.prisma.task.findUnique({
      where: { id: taskId },
      select: { assignedTo: true, assignedBy: true },
    });
    
    if (task) {
      this.server.to(`user:${task.assignedTo}`).emit('task:updated', {
        taskId,
        status,
        updatedBy: completedBy,
        timestamp: new Date(),
      });
      
      if (task.assignedBy) {
        this.server.to(`user:${task.assignedBy}`).emit('task:updated', {
          taskId,
          status,
          updatedBy: completedBy,
          timestamp: new Date(),
        });
      }
    }
    
    return { event: 'task:updated', data: { taskId, status } };
  }

  @SubscribeMessage('block:select')
  async handleBlockSelect(@ConnectedSocket() client: Socket, @MessageBody() data: any) {
    const { blockId } = data;
    const userId = client.data.userId;
    
    // Store user's current block
    await this.prisma.user.update({
      where: { id: userId },
      data: { currentBlockId: blockId },
    });
    
    // Notify supervisor about user location
    const supervisors = await this.getSupervisors(userId);
    for (const supId of supervisors) {
      this.server.to(`user:${supId}`).emit('user:location-update', {
        userId,
        blockId,
        timestamp: new Date(),
      });
    }
    
    return { event: 'block:selected', data: { blockId } };
  }

  @SubscribeMessage('sync:request')
  async handleSyncRequest(@ConnectedSocket() client: Socket, @MessageBody() data: any) {
    const userId = client.data.userId;
    const { lastSyncTime, entityType } = data;
    
    // Get changes since last sync
    const changes = await this.getChangesSince(userId, lastSyncTime, entityType);
    
    client.emit('sync:response', {
      changes,
      timestamp: new Date(),
    });
    
    return { event: 'sync:requested' };
  }

  async notifyNewTask(task: any) {
    // Send to assigned user
    this.server.to(`user:${task.assignedTo}`).emit('task:new', {
      task,
      timestamp: new Date(),
    });
    
    // Also send notification via FCM if user is offline
    await this.sendPushNotification(task.assignedTo, {
      title: 'Tugas Baru',
      body: task.title,
      data: { taskId: task.id, type: 'task' },
    });
  }

  async notifyDataSync(userId: string, syncResult: any) {
    this.server.to(`user:${userId}`).emit('sync:completed', {
      result: syncResult,
      timestamp: new Date(),
    });
  }

  private async sendPendingNotifications(userId: string, socketId: string) {
    const notifications = await this.prisma.notification.findMany({
      where: {
        userId,
        isRead: false,
        deliveredAt: null,
      },
      orderBy: { createdAt: 'asc' },
      take: 50,
    });
    
    for (const notif of notifications) {
      this.server.to(socketId).emit('notification', notif);
      await this.prisma.notification.update({
        where: { id: notif.id },
        data: { deliveredAt: new Date() },
      });
    }
  }

  private async getChangesSince(userId: string, lastSyncTime: string, entityType?: string) {
    const lastSync = new Date(lastSyncTime);
    const changes: any = { harvests: [], inspections: [], tasks: [] };
    
    if (!entityType || entityType === 'harvest') {
      changes.harvests = await this.prisma.harvest.findMany({
        where: {
          OR: [
            { createdAt: { gt: lastSync } },
            { updatedAt: { gt: lastSync } },
          ],
          createdBy: { not: userId },
        },
        include: { block: true },
      });
    }
    
    if (!entityType || entityType === 'inspection') {
      changes.inspections = await this.prisma.inspection.findMany({
        where: {
          OR: [
            { createdAt: { gt: lastSync } },
            { updatedAt: { gt: lastSync } },
          ],
          createdBy: { not: userId },
        },
        include: { block: true },
      });
    }
    
    if (!entityType || entityType === 'task') {
      changes.tasks = await this.prisma.task.findMany({
        where: {
          OR: [
            { assignedTo: userId },
            { assignedBy: userId },
          ],
          updatedAt: { gt: lastSync },
        },
      });
    }
    
    return changes;
  }

  private async getAdminUsers(): Promise<string[]> {
    const admins = await this.prisma.user.findMany({
      where: { role: 'ADMIN' },
      select: { id: true },
    });
    return admins.map(a => a.id);
  }

  private async getSupervisors(userId: string): Promise<string[]> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { estateId: true },
    });
    
    if (!user?.estateId) return [];
    
    const supervisors = await this.prisma.user.findMany({
      where: {
        estateId: user.estateId,
        role: { in: ['ADMIN', 'SUPERVISOR'] },
      },
      select: { id: true },
    });
    
    return supervisors.map(s => s.id).filter(id => id !== userId);
  }

  private async sendPushNotification(userId: string, payload: any) {
    // Implement FCM or other push notification
    console.log(`Sending push to ${userId}:`, payload);
  }

  private verifyToken(token: string): string {
    // Implement JWT verification
    // Return userId
    return 'user-id-placeholder';
  }
}