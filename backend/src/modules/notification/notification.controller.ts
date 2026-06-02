import {
  Controller,
  Post,
  Get,
  Body,
  Param,
  UseGuards,
  Query,
  Patch,
} from '@nestjs/common';
import { NotificationService } from './notification.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationController {
  constructor(private readonly notificationService: NotificationService) {}

  @Post('register-token')
  async registerToken(
    @CurrentUser() user: any,
    @Body('token') token: string,
    @Body('deviceType') deviceType: string,
  ) {
    await this.notificationService.registerDeviceToken(user.id, token, deviceType);
    return { success: true };
  }

  @Post('unregister-token')
  async unregisterToken(
    @CurrentUser() user: any,
    @Body('token') token: string,
  ) {
    await this.notificationService.unregisterDeviceToken(user.id, token);
    return { success: true };
  }

  @Get()
  async getNotifications(
    @CurrentUser() user: any,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.notificationService.getUserNotifications(
      user.id,
      limit ? parseInt(limit) : 50,
      offset ? parseInt(offset) : 0,
    );
  }

  @Get('unread-count')
  async getUnreadCount(@CurrentUser() user: any) {
    const count = await this.notificationService.getUnreadCount(user.id);
    return { count };
  }

  @Patch(':id/read')
  async markAsRead(@CurrentUser() user: any, @Param('id') id: string) {
    await this.notificationService.markAsRead(id, user.id);
    return { success: true };
  }

  @Post('broadcast')
  @Roles('ADMIN')
  async broadcast(@Body() body: any) {
    await this.notificationService.sendBroadcast(
      body.title,
      body.body,
      body.role,
      body.data,
    );
    return { success: true };
  }
}