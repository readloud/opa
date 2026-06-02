import {
  Controller,
  Post,
  UploadedFile,
  UseInterceptors,
  Get,
  Param,
  Body,
  UseGuards,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { MlService } from './ml.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('ml')
@UseGuards(JwtAuthGuard)
export class MlController {
  constructor(private readonly mlService: MlService) {}

  @Post('detect-pest')
  @UseInterceptors(FileInterceptor('image'))
  async detectPest(
    @UploadedFile() file: Express.Multer.File,
    @CurrentUser() user: any,
  ) {
    const result = await this.mlService.detectPest(file.buffer);
    return result;
  }

  @Post('detect-pest-from-url')
  async detectPestFromUrl(@Body('imageUrl') imageUrl: string) {
    const response = await axios.get(imageUrl, { responseType: 'arraybuffer' });
    const buffer = Buffer.from(response.data);
    return this.mlService.detectPest(buffer, imageUrl);
  }

  @Get('block/:blockId/health')
  async getBlockHealth(@Param('blockId') blockId: string) {
    return this.mlService.analyzeBlockHealth(blockId);
  }

  @Post('treatment')
  async saveTreatment(
    @Body() data: any,
    @CurrentUser() user: any,
  ) {
    return this.mlService.saveTreatment({
      ...data,
      appliedBy: user.id,
    });
  }

  @Get('block/:blockId/treatments')
  async getTreatments(@Param('blockId') blockId: string) {
    return this.mlService.getTreatmentHistory(blockId);
  }
}