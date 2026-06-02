import { IsString, IsNotEmpty, Matches } from 'class-validator';

export class RequestOtpDto {
  @IsString()
  @IsNotEmpty()
  @Matches(/^(\+?62|0)[0-9]{9,13}$|^[^\s@]+@[^\s@]+\.[^\s@]+$/, {
    message: 'Must be valid phone number (Indonesian) or email',
  })
  identifier: string;
}