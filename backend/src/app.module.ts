import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './modules/prisma/prisma.module';
import { AuthModule } from './modules/auth/auth.module';
import { UserModule } from './modules/user/user.module';
import { EstateModule } from './modules/estate/estate.module';
import { BlockModule } from './modules/block/block.module';
import { HarvestModule } from './modules/harvest/harvest.module';
import { InspectionModule } from './modules/inspection/inspection.module';
import { FertilizationModule } from './modules/fertilization/fertilization.module';
import { TaskModule } from './modules/task/task.module';
import { ReportModule } from './modules/report/report.module';
import { SyncModule } from './modules/sync/sync.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    PrismaModule,
    AuthModule,
    UserModule,
    EstateModule,
    BlockModule,
    HarvestModule,
    InspectionModule,
    FertilizationModule,
    TaskModule,
    ReportModule,
    SyncModule,
  ],
})
export class AppModule {}