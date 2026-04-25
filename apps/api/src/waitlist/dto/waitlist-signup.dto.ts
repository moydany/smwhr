import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  ArrayMaxSize,
  IsArray,
  IsEmail,
  IsIn,
  IsOptional,
  IsString,
  Length,
} from 'class-validator';
import { VALID_INTERESTS } from '../../users/dto/onboarding.dto';

export class WaitlistSignupDto {
  @ApiProperty()
  @IsEmail()
  email!: string;

  @ApiPropertyOptional({ default: 'landing' })
  @IsOptional()
  @IsString()
  @Length(1, 40)
  source?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Length(0, 200)
  referrer?: string;

  @ApiPropertyOptional({ enum: VALID_INTERESTS, isArray: true })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(VALID_INTERESTS.length)
  @IsIn(VALID_INTERESTS as readonly string[], { each: true })
  interests?: string[];
}
