import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsDateString, IsNumber, IsObject, IsOptional, Max, Min } from 'class-validator';

export class UploadPhotoMetadataDto {
  @ApiPropertyOptional({ description: 'EXIF DateTimeOriginal' })
  @IsOptional()
  @IsDateString()
  exifTimestamp?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  exifLatitude?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  exifLongitude?: number;

  @ApiPropertyOptional({ description: 'Raw EXIF JSON from client' })
  @IsOptional()
  @IsObject()
  exifRaw?: Record<string, unknown>;
}
