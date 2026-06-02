import {
  Controller,
  Post,
  UploadedFile,
  UploadedFiles,
  UseInterceptors,
  UseGuards,
  Query,
  Get,
  Delete,
  Param,
} from '@nestjs/common';
import { FileInterceptor, FilesInterceptor } from '@nestjs/platform-express';
import { StorageService } from './storage.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('storage')
@UseGuards(JwtAuthGuard)
export class StorageController {
  constructor(private readonly storageService: StorageService) {}

  @Post('upload')
  @UseInterceptors(FileInterceptor('file'))
  async uploadImage(
    @UploadedFile() file: Express.Multer.File,
    @CurrentUser() user: any,
    @Query('folder') folder?: string,
  ) {
    const url = await this.storageService.uploadImage(
      file,
      folder || 'general',
      user.id,
    );
    return { url, originalName: file.originalname, size: file.size };
  }

  @Post('upload-multiple')
  @UseInterceptors(FilesInterceptor('files', 10))
  async uploadMultipleImages(
    @UploadedFiles() files: Express.Multer.File[],
    @CurrentUser() user: any,
    @Query('folder') folder?: string,
  ) {
    const urls = await this.storageService.uploadMultipleImages(
      files,
      folder || 'general',
      user.id,
    );
    return { urls, count: urls.length };
  }

  @Get('signed-url')
  async getSignedUrl(@Query('key') key: string) {
    const url = await this.storageService.getSignedUrl(key);
    return { url };
  }

  @Delete(':url')
  async deleteImage(@Param('url') url: string) {
    await this.storageService.deleteImage(decodeURIComponent(url));
    return { message: 'Image deleted successfully' };
  }
}