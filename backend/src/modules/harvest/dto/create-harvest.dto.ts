import { IsString, IsNotEmpty, IsNumber, IsOptional, IsDateString, Min } from 'class-validator';

export class CreateHarvestDto {
  @IsString()
  @IsNotEmpty()
  blockId: string;

  @IsNumber()
  @IsNotEmpty()
  @Min(0)
  tonase: number;

  @IsDateString()
  @IsNotEmpty()
  harvestDate: string;

  @IsString()
  @IsOptional()
  photoUrl?: string;
}