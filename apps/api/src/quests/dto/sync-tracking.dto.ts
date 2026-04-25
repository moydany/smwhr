import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsDateString,
  IsObject,
  IsOptional,
  ValidateNested,
} from 'class-validator';
import { GeolocatorPingDto } from './geolocator-ping.dto';
import { LocusEventDto } from './locus-event.dto';

export class SyncTrackingDto {
  @ApiPropertyOptional({ type: [LocusEventDto] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(5000)
  @ValidateNested({ each: true })
  @Type(() => LocusEventDto)
  locusEvents?: LocusEventDto[];

  @ApiPropertyOptional({ type: [GeolocatorPingDto] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(5000)
  @ValidateNested({ each: true })
  @Type(() => GeolocatorPingDto)
  geolocatorPings?: GeolocatorPingDto[];

  @ApiProperty()
  @IsDateString()
  clientTimestamp!: string;

  @ApiPropertyOptional({ description: 'Device id, model, os, app version' })
  @IsOptional()
  @IsObject()
  deviceInfo?: Record<string, unknown>;
}
