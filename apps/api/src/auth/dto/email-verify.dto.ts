import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsString, Length } from 'class-validator';

export class EmailVerifyDto {
  @ApiProperty({ example: 'moi@orbit-m.dev' })
  @IsEmail()
  email!: string;

  @ApiProperty({ example: '123456', description: '6-digit OTP from email' })
  @IsString()
  @Length(6, 12)
  token!: string;
}
