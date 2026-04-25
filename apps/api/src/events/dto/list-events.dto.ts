import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Length,
  Max,
  Min,
} from 'class-validator';
import { VALID_INTERESTS } from '../../users/dto/onboarding.dto';

export class ListEventsDto {
  @ApiPropertyOptional({ enum: VALID_INTERESTS })
  @IsOptional()
  @IsIn(VALID_INTERESTS as readonly string[])
  category?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Length(1, 80)
  city?: string;

  @ApiPropertyOptional({ description: 'Filter to featured events' })
  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  @IsBoolean()
  featured?: boolean;

  @ApiPropertyOptional({ default: 50 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  offset?: number;

  @ApiPropertyOptional({ description: 'ISO timestamp; only events starting at or after this time' })
  @IsOptional()
  @IsString()
  from?: string;

  @ApiPropertyOptional({ description: 'ISO timestamp; only events ending before this time' })
  @IsOptional()
  @IsString()
  to?: string;
}
