import { Module } from '@nestjs/common';
import { DroneService } from './drone.service';
import { DroneController } from './drone.controller';
import { DroneGateway } from './drone.gateway';
import { PrismaModule } from '../prisma/prisma.module';
import { StorageModule } from '../storage/storage.module';
import { S3Module } from '../s3/s3.module';

@Module({
  imports: [PrismaModule, StorageModule, S3Module],
  controllers: [DroneController],
  providers: [DroneService, DroneGateway],
  exports: [DroneService],
})
export class DroneModule {}