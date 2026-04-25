import { ApiProperty } from '@nestjs/swagger';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  Length,
  Matches,
} from 'class-validator';

export const VALID_INTERESTS = ['music', 'sports', 'festivals', 'outdoor', 'culture'] as const;
export type Interest = (typeof VALID_INTERESTS)[number];

export class OnboardingDto {
  @ApiProperty({ minLength: 3, maxLength: 20 })
  @IsString()
  @Length(3, 20)
  handle!: string;

  @ApiProperty({ minLength: 1, maxLength: 40 })
  @IsString()
  @Length(1, 40)
  displayName!: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @Length(0, 80)
  city?: string;

  @ApiProperty({ required: false, default: 'MX', minLength: 2, maxLength: 2 })
  @IsOptional()
  @IsString()
  @Matches(/^[A-Z]{2}$/)
  countryCode?: string;

  @ApiProperty({ enum: VALID_INTERESTS, isArray: true, required: false })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(VALID_INTERESTS.length)
  @IsIn(VALID_INTERESTS as readonly string[], { each: true })
  interests?: Interest[];

  @ApiProperty({ required: false, default: false })
  @IsOptional()
  @IsBoolean()
  notificationsEnabled?: boolean;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  pushToken?: string;

  @ApiProperty({ required: false, enum: ['ios', 'android'] })
  @IsOptional()
  @IsIn(['ios', 'android'])
  pushPlatform?: 'ios' | 'android';
}
