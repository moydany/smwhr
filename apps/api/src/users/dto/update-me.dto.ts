import { ApiProperty } from '@nestjs/swagger';
import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsOptional,
  IsString,
  Length,
} from 'class-validator';
import { VALID_INTERESTS, type Interest } from './onboarding.dto';

export class UpdateMeDto {
  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @Length(1, 40)
  displayName?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @Length(0, 140)
  bio?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @Length(0, 80)
  city?: string;

  @ApiProperty({ required: false, enum: VALID_INTERESTS, isArray: true })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(VALID_INTERESTS.length)
  @IsIn(VALID_INTERESTS as readonly string[], { each: true })
  interests?: Interest[];

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  pushToken?: string;

  @ApiProperty({ required: false, enum: ['ios', 'android'] })
  @IsOptional()
  @IsIn(['ios', 'android'])
  pushPlatform?: 'ios' | 'android';
}
