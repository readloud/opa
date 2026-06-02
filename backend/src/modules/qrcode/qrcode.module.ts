import { Module } from '@nestjs/common';
import { QrCodeService } from './qrcode.service';
import { QrCodeController } from './qrcode.controller';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [QrCodeController],
  providers: [QrCodeService],
  exports: [QrCodeService],
})
export class QrCodeModule {}