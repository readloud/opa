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
import { ChatService } from './chat.service';
import { WsJwtGuard } from '../../common/guards/ws-jwt.guard';

@WebSocketGateway({
  cors: { origin: '*' },
  namespace: '/chat',
})
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private userSockets: Map<string, string[]> = new Map();
  private typingUsers: Map<string, Map<string, Timer>> = new Map();

  constructor(private chatService: ChatService) {}

  async handleConnection(client: Socket) {
    const userId = client.data.userId;
    if (!userId) {
      client.disconnect();
      return;
    }

    if (!this.userSockets.has(userId)) {
      this.userSockets.set(userId, []);
    }
    this.userSockets.get(userId)!.push(client.id);

    // Join user's personal room
    client.join(`user:${userId}`);
    
    // Join all group rooms user is member of
    const groups = await this.chatService.getUserGroups(userId);
    for (const group of groups) {
      client.join(`group:${group.id}`);
    }

    // Notify others that user is online
    client.broadcast.emit('user:online', { userId, online: true });
  }

  handleDisconnect(client: Socket) {
    const userId = client.data.userId;
    if (userId && this.userSockets.has(userId)) {
      const sockets = this.userSockets.get(userId)!;
      const index = sockets.indexOf(client.id);
      if (index > -1) sockets.splice(index, 1);
      if (sockets.length === 0) {
        this.userSockets.delete(userId);
        client.broadcast.emit('user:online', { userId, online: false });
      }
    }
  }

  @SubscribeMessage('message:send')
  async handleSendMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: any,
  ) {
    const senderId = client.data.userId;
    const { chatId, message, type = 'text', replyToId } = data;

    const savedMessage = await this.chatService.saveMessage({
      chatId,
      senderId,
      message,
      type,
      replyToId,
    });

    // Get chat info
    const chat = await this.chatService.getChat(chatId);
    
    // Send to all participants
    for (const participant of chat.participants) {
      this.server.to(`user:${participant.userId}`).emit('message:new', {
        ...savedMessage,
        sender: { id: senderId, name: client.data.userName },
      });
    }

    return { success: true };
  }

  @SubscribeMessage('message:read')
  async handleMarkAsRead(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: any,
  ) {
    const userId = client.data.userId;
    const { chatId, messageId } = data;

    await this.chatService.markMessageAsRead(messageId, userId);
    
    // Notify sender
    const message = await this.chatService.getMessage(messageId);
    if (message) {
      this.server.to(`user:${message.senderId}`).emit('message:read', {
        messageId,
        chatId,
        readBy: userId,
        readAt: new Date(),
      });
    }
  }

  @SubscribeMessage('typing:start')
  handleTypingStart(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: any,
  ) {
    const userId = client.data.userId;
    const { chatId } = data;

    if (!this.typingUsers.has(chatId)) {
      this.typingUsers.set(chatId, new Map());
    }
    
    const typingMap = this.typingUsers.get(chatId)!;
    if (!typingMap.has(userId)) {
      typingMap.set(userId, null);
      
      // Broadcast to other participants
      client.to(`chat:${chatId}`).emit('typing:start', {
        userId,
        chatId,
      });
    }
  }

  @SubscribeMessage('typing:stop')
  handleTypingStop(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: any,
  ) {
    const userId = client.data.userId;
    const { chatId } = data;

    const typingMap = this.typingUsers.get(chatId);
    if (typingMap && typingMap.has(userId)) {
      typingMap.delete(userId);
      client.to(`chat:${chatId}`).emit('typing:stop', { userId, chatId });
    }
  }

  @SubscribeMessage('location:share')
  async handleShareLocation(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: any,
  ) {
    const senderId = client.data.userId;
    const { chatId, latitude, longitude, address } = data;

    const message = await this.chatService.saveMessage({
      chatId,
      senderId,
      message: JSON.stringify({ latitude, longitude, address }),
      type: 'location',
    });

    const chat = await this.chatService.getChat(chatId);
    
    for (const participant of chat.participants) {
      this.server.to(`user:${participant.userId}`).emit('message:new', {
        ...message,
        location: { latitude, longitude, address },
      });
    }
  }

  @SubscribeMessage('image:send')
  async handleSendImage(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: any,
  ) {
    const senderId = client.data.userId;
    const { chatId, imageUrl, caption } = data;

    const message = await this.chatService.saveMessage({
      chatId,
      senderId,
      message: caption || '',
      type: 'image',
      mediaUrl: imageUrl,
    });

    const chat = await this.chatService.getChat(chatId);
    
    for (const participant of chat.participants) {
      this.server.to(`user:${participant.userId}`).emit('message:new', {
        ...message,
        imageUrl,
      });
    }
  }
}