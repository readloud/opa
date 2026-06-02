import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ChatService {
  constructor(private prisma: PrismaService) {}

  async createDirectChat(userId1: string, userId2: string) {
    // Check if chat already exists
    const existing = await this.prisma.chat.findFirst({
      where: {
        type: 'DIRECT',
        participants: {
          every: { userId: { in: [userId1, userId2] } },
        },
      },
    });

    if (existing) return existing;

    return this.prisma.chat.create({
      data: {
        type: 'DIRECT',
        participants: {
          create: [{ userId: userId1 }, { userId: userId2 }],
        },
      },
      include: {
        participants: {
          include: { user: { select: { id: true, name: true, role: true } } },
        },
      },
    });
  }

  async createGroupChat(name: string, userIds: string[], createdBy: string) {
    return this.prisma.chat.create({
      data: {
        name,
        type: 'GROUP',
        participants: {
          create: userIds.map(userId => ({ userId })),
        },
      },
      include: {
        participants: {
          include: { user: { select: { id: true, name: true, role: true } } },
        },
      },
    });
  }

  async saveMessage(data: {
    chatId: string;
    senderId: string;
    message: string;
    type?: string;
    replyToId?: string;
    mediaUrl?: string;
  }) {
    return this.prisma.message.create({
      data: {
        chatId: data.chatId,
        senderId: data.senderId,
        content: data.message,
        type: data.type || 'text',
        replyToId: data.replyToId,
        mediaUrl: data.mediaUrl,
      },
      include: {
        sender: { select: { id: true, name: true, role: true } },
        replyTo: true,
      },
    });
  }

  async getMessages(chatId: string, limit = 50, offset = 0) {
    return this.prisma.message.findMany({
      where: { chatId },
      orderBy: { createdAt: 'desc' },
      take: limit,
      skip: offset,
      include: {
        sender: { select: { id: true, name: true, role: true } },
        replyTo: {
          include: { sender: { select: { id: true, name: true } } },
        },
        readBy: {
          include: { user: { select: { id: true, name: true } } },
        },
      },
    });
  }

  async getChats(userId: string) {
    const chats = await this.prisma.chat.findMany({
      where: {
        participants: { some: { userId } },
      },
      include: {
        participants: {
          include: { user: { select: { id: true, name: true, role: true } } },
        },
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          include: { sender: { select: { id: true, name: true } } },
        },
      },
      orderBy: { updatedAt: 'desc' },
    });

    // Add unread count
    const chatsWithUnread = await Promise.all(
      chats.map(async chat => {
        const unreadCount = await this.prisma.message.count({
          where: {
            chatId: chat.id,
            readBy: { none: { userId } },
            senderId: { not: userId },
          },
        });
        return { ...chat, unreadCount };
      }),
    );

    return chatsWithUnread;
  }

  async getChat(chatId: string) {
    const chat = await this.prisma.chat.findUnique({
      where: { id: chatId },
      include: {
        participants: {
          include: { user: { select: { id: true, name: true, role: true } } },
        },
      },
    });

    if (!chat) throw new NotFoundException('Chat not found');
    return chat;
  }

  async getUserGroups(userId: string) {
    return this.prisma.chat.findMany({
      where: {
        type: 'GROUP',
        participants: { some: { userId } },
      },
    });
  }

  async addParticipants(chatId: string, userIds: string[]) {
    return this.prisma.chat.update({
      where: { id: chatId },
      data: {
        participants: {
          create: userIds.map(userId => ({ userId })),
        },
      },
    });
  }

  async removeParticipant(chatId: string, userId: string) {
    return this.prisma.chatParticipant.delete({
      where: {
        chatId_userId: { chatId, userId },
      },
    });
  }

  async markMessageAsRead(messageId: string, userId: string) {
    return this.prisma.messageRead.create({
      data: {
        messageId,
        userId,
      },
    });
  }

  async getMessage(messageId: string) {
    return this.prisma.message.findUnique({
      where: { id: messageId },
    });
  }

  async searchMessages(chatId: string, query: string) {
    return this.prisma.message.findMany({
      where: {
        chatId,
        content: { contains: query, mode: 'insensitive' },
      },
      orderBy: { createdAt: 'desc' },
      take: 50,
      include: {
        sender: { select: { id: true, name: true } },
      },
    });
  }

  async deleteMessage(messageId: string, userId: string, isAdmin: boolean) {
    const message = await this.prisma.message.findUnique({
      where: { id: messageId },
    });

    if (!message) throw new NotFoundException('Message not found');
    if (message.senderId !== userId && !isAdmin) {
      throw new Error('Unauthorized');
    }

    return this.prisma.message.update({
      where: { id: messageId },
      data: { isDeleted: true, content: '[Pesan telah dihapus]' },
    });
  }
}