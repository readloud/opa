import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import * as admin from 'firebase-admin';

@Injectable()
export class NotificationService {
  private readonly logger = new Logger(NotificationService.name);
  private fcmApp: admin.app.App;

  constructor(
    private configService: ConfigService,
    private prisma: PrismaService,
  ) {
    this.initializeFirebase();
  }

  private initializeFirebase() {
    const serviceAccount = {
      projectId: this.configService.get('FCM_PROJECT_ID'),
      privateKey: this.configService.get('FCM_PRIVATE_KEY')?.replace(/\\n/g, '\n'),
      clientEmail: this.configService.get('FCM_CLIENT_EMAIL'),
    };

    this.fcmApp = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }

  async registerDeviceToken(userId: string, token: string, deviceType: string) {
    await this.prisma.deviceToken.upsert({
      where: {
        userId_token: {
          userId,
          token,
        },
      },
      update: {
        deviceType,
        lastUsedAt: new Date(),
        isActive: true,
      },
      create: {
        userId,
        token,
        deviceType,
        lastUsedAt: new Date(),
        isActive: true,
      },
    });
  }

  async unregisterDeviceToken(userId: string, token: string) {
    await this.prisma.deviceToken.update({
      where: {
        userId_token: {
          userId,
          token,
        },
      },
      data: {
        isActive: false,
      },
    });
  }

  async sendNotification(
    userId: string,
    title: string,
    body: string,
    data?: Record<string, any>,
    saveToDatabase: boolean = true,
  ): Promise<void> {
    // Get user's device tokens
    const tokens = await this.prisma.deviceToken.findMany({
      where: {
        userId,
        isActive: true,
      },
    });

    if (tokens.length === 0) {
      this.logger.warn(`No active tokens for user ${userId}`);
      return;
    }

    // Save notification to database
    let notificationId: string | undefined;
    if (saveToDatabase) {
      const saved = await this.prisma.notification.create({
        data: {
          userId,
          title,
          body,
          data: data || {},
          type: data?.type || 'general',
        },
      });
      notificationId = saved.id;
    }

    // Send to FCM
    const message: admin.messaging.MulticastMessage = {
      tokens: tokens.map(t => t.token),
      notification: {
        title,
        body,
      },
      data: {
        ...(data?.reduce((acc, val, key) => ({ ...acc, [key]: String(val) }), {}) || {}),
        notificationId: notificationId || '',
        timestamp: new Date().toISOString(),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'opa_tasks',
          sound: 'default',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    try {
      const response = await admin.messaging().sendEachForMulticast(message);
      
      // Handle failed tokens
      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            this.logger.error(`Failed to send to token ${tokens[idx].token}: ${resp.error}`);
            if (resp.error?.code === 'messaging/registration-token-not-registered') {
              // Delete invalid token
              this.prisma.deviceToken.update({
                where: { userId_token: { userId, token: tokens[idx].token } },
                data: { isActive: false },
              });
            }
          }
        });
      }
      
      this.logger.log(`Sent notification to ${response.successCount}/${tokens.length} devices`);
    } catch (error) {
      this.logger.error('Failed to send FCM notification', error);
    }
  }

  async sendTaskNotification(task: any, assignedTo: string) {
    await this.sendNotification(
      assignedTo,
      'Tugas Baru',
      task.title,
      {
        type: 'task',
        taskId: task.id,
        dueDate: task.dueDate.toISOString(),
      },
      true,
    );
  }

  async sendSyncCompleteNotification(userId: string, syncResult: any) {
    await this.sendNotification(
      userId,
      'Sinkronisasi Selesai',
      `${syncResult.syncedCount} data berhasil disinkronkan`,
      {
        type: 'sync',
        syncedCount: syncResult.syncedCount,
      },
      false,
    );
  }

  async sendReminderNotification(taskId: string, userId: string, hoursBefore: number) {
    const task = await this.prisma.task.findUnique({
      where: { id: taskId },
    });
    
    if (task && task.status === 'PENDING') {
      await this.sendNotification(
        userId,
        'Pengingat Tugas',
        `Tugas "${task.title}" akan jatuh tempo dalam ${hoursBefore} jam`,
        {
          type: 'reminder',
          taskId: task.id,
        },
        true,
      );
    }
  }

  async sendBroadcast(
    title: string,
    body: string,
    role?: string,
    data?: Record<string, any>,
  ) {
    const where: any = { isActive: true };
    if (role) {
      where.user = { role };
    }
    
    const tokens = await this.prisma.deviceToken.findMany({
      where,
      include: { user: true },
    });
    
    // Group by user to avoid duplicate notifications
    const uniqueTokens = [...new Map(tokens.map(t => [t.userId, t])).values()];
    
    for (const token of uniqueTokens) {
      await this.sendNotification(token.userId, title, body, data, true);
    }
  }

  async markAsRead(notificationId: string, userId: string) {
    await this.prisma.notification.update({
      where: { id: notificationId, userId },
      data: { isRead: true, readAt: new Date() },
    });
  }

  async getUserNotifications(userId: string, limit: number = 50, offset: number = 0) {
    return this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: limit,
      skip: offset,
    });
  }

  async getUnreadCount(userId: string): Promise<number> {
    return this.prisma.notification.count({
      where: { userId, isRead: false },
    });
  }
}