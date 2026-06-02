import {
  Controller,
  Get,
  Post,
  Param,
  UseGuards,
  Res,
  Body,
} from '@nestjs/common';
import { Response } from 'express';
import { QrCodeService } from './qrcode.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';

@Controller('qrcode')
@UseGuards(JwtAuthGuard)
export class QrCodeController {
  constructor(private readonly qrCodeService: QrCodeService) {}

  @Get('tree/:treeId')
  async getTreeQrCode(@Param('treeId') treeId: string, @Res() res: Response) {
    const qrCode = await this.qrCodeService.generateTreeQrCode(treeId);
    res.send(`<img src="${qrCode}" alt="QR Code" />`);
  }

  @Get('batch/:blockId')
  @Roles('ADMIN', 'SUPERVISOR')
  async getBatchQrCodes(@Param('blockId') blockId: string, @Res() res: Response) {
    const pdf = await this.qrCodeService.generateBatchQrCodes(blockId);
    res.set({
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename="qr_codes_block_${blockId}.pdf"`,
    });
    res.send(pdf);
  }

  @Post('scan')
  async scanQrCode(@Body('data') qrData: string) {
    return this.qrCodeService.scanQrCode(qrData);
  }

  @Get('tree/:treeId/history')
  async getTreeHistory(@Param('treeId') treeId: string) {
    return this.qrCodeService.getTreeHistory(treeId);
  }
}