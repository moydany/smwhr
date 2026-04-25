import { ApiProperty } from '@nestjs/swagger';
import { IsDateString, IsIn, IsString } from 'class-validator';

export class IntegrityDto {
  @ApiProperty({ enum: ['ios', 'android'] })
  @IsIn(['ios', 'android'])
  platform!: 'ios' | 'android';

  @ApiProperty({ description: 'App Attest / Play Integrity attestation token' })
  @IsString()
  token!: string;

  @ApiProperty()
  @IsDateString()
  verifiedAt!: string;
}
