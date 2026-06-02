import { IsString, IsNotEmpty, IsNumber, IsOptional, IsBoolean } from 'class-validator';

export class SyncHarvestDto {
  @IsString()
  @IsNotEmpty()
  id: string;

  @IsString()
  @IsNotEmpty()
  blockId: string;

  @IsNumber()
  tonase: number;

  @IsString()
  harvestDate: string;

  @IsString()
  @IsOptional()
  photoUrl?: string;

  @IsBoolean()
  isDeleted?: boolean;
}