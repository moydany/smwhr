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

export const VALID_LANGUAGES = ['es', 'en'] as const;
export type Language = (typeof VALID_LANGUAGES)[number];

export class UpdateMeDto {
  @ApiProperty({ required: false, minLength: 3, maxLength: 20 })
  @IsOptional()
  @IsString()
  @Length(3, 20)
  handle?: string;

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

  @ApiProperty({ required: false, enum: VALID_LANGUAGES })
  @IsOptional()
  @IsIn(VALID_LANGUAGES as readonly string[])
  language?: Language;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  pushToken?: string;

  @ApiProperty({ required: false, enum: ['ios', 'android'] })
  @IsOptional()
  @IsIn(['ios', 'android'])
  pushPlatform?: 'ios' | 'android';
}
