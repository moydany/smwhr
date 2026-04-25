import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class AppleAuthDto {
  @ApiProperty()
  @IsString()
  identityToken!: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  authorizationCode?: string;
}
