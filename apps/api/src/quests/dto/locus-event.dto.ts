import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsDateString,
  IsIn,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
  Max,
  Min,
} from 'class-validator';

export const LOCUS_EVENT_TYPES = [
  'GEOFENCE_ENTER',
  'GEOFENCE_EXIT',
  'LOCATION_UPDATE',
  'MOTION_CHANGE',
] as const;

export class LocusEventDto {
  @ApiProperty({ enum: LOCUS_EVENT_TYPES })
  @IsIn(LOCUS_EVENT_TYPES as readonly string[])
  eventType!: string;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude!: number;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude!: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  accuracy?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  altitude?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  speed?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  heading?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  activity?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  confidence?: number;

  @ApiProperty()
  @IsDateString()
  timestamp!: string;

  @ApiPropertyOptional({ description: 'Raw vendor payload' })
  @IsOptional()
  @IsObject()
  rawPayload?: Record<string, unknown>;
}
