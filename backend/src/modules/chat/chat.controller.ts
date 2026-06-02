import {
  Controller,
  Post,
  Get,
  Body,
  Param,
  Query,
  UseGuards,
  Delete,
} from '@nestjs/common';
import { ChatService } from './chat.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('chat')
@UseGuards(JwtAuthGuard)
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Post('direct')
  async createDirectChat(@CurrentUser() user: any, @Body('userId') otherUserId: string) {
    return this.chatService.createDirectChat(user.id, otherUserId);
  }

  @Post('group')
  async createGroupChat(
    @CurrentUser() user: any,
    @Body('name') name: string,
    @Body('userIds') userIds: string[],
  ) {
    return this.chatService.createGroupChat(name, [user.id, ...userIds], user.id);
  }

  @Get('my-chats')
  async getMyChats(@CurrentUser() user: any) {
    return this.chatService.getChats(user.id);
  }

  @Get(':chatId/messages')
  async getMessages(
    @Param('chatId') chatId: string,
    @Query('limit') limit: string,
    @Query('offset') offset: string,
  ) {
    return this.chatService.getMessages(
      chatId,
      limit ? parseInt(limit) : 50,
      offset ? parseInt(offset) : 0,
    );
  }

  @Post(':chatId/messages/search')
  async searchMessages(
    @Param('chatId') chatId: string,
    @Body('query') query: string,
  ) {
    return this.chatService.searchMessages(chatId, query);
  }

  @Post(':chatId/participants')
  async addParticipants(
    @Param('chatId') chatId: string,
    @Body('userIds') userIds: string[],
  ) {
    return this.chatService.addParticipants(chatId, userIds);
  }

  @Delete(':chatId/participants/:userId')
  async removeParticipant(@Param('chatId') chatId: string, @Param('userId') userId: string) {
    return this.chatService.removeParticipant(chatId, userId);
  }

  @Delete('messages/:messageId')
  async deleteMessage(
    @Param('messageId') messageId: string,
    @CurrentUser() user: any,
  ) {
    return this.chatService.deleteMessage(messageId, user.id, user.role === 'ADMIN');
  }
}