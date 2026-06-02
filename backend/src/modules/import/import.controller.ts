import {
  Controller,
  Post,
  UploadedFile,
  UseInterceptors,
  UseGuards,
  Get,
  Query,
  Body,
  Param,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ImportService } from './import.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('import')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN', 'SUPERVISOR')
export class ImportController {
  constructor(private readonly importService: ImportService) {}

  @Post('harvest')
  @UseInterceptors(FileInterceptor('file'))
  async importHarvest(
    @UploadedFile() file: Express.Multer.File,
    @CurrentUser() user: any,
    @Body('estateId') estateId: string,
  ) {
    return this.importService.importHarvestFromFile(file, estateId, user.id);
  }

  @Post('blocks')
  @UseInterceptors(FileInterceptor('file'))
  async importBlocks(
    @UploadedFile() file: Express.Multer.File,
    @Body('estateId') estateId: string,
  ) {
    return this.importService.importBlocksFromFile(file, estateId);
  }

  @Post('trees/:blockId')
  @UseInterceptors(FileInterceptor('file'))
  async importTrees(
    @UploadedFile() file: Express.Multer.File,
    @Param('blockId') blockId: string,
  ) {
    return this.importService.importTreesFromFile(file, blockId);
  }

  @Get('template')
  async getTemplate(@Query('type') type: string) {
    const buffer = await this.importService.getImportTemplate(type);
    return {
      buffer: buffer.toString('base64'),
      filename: `template_import_${type}.xlsx`,
    };
  }
}