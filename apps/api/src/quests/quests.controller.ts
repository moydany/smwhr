import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  ApiBearerAuth,
  ApiBody,
  ApiConsumes,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import type { User } from '@prisma/client';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { IntegrityDto } from './dto/integrity.dto';
import { SyncTrackingDto } from './dto/sync-tracking.dto';
import { UploadPhotoMetadataDto } from './dto/upload-photo.dto';
import { QuestsService } from './quests.service';
import { CheckinFinalizerService } from './services/checkin-finalizer.service';

@ApiTags('quests')
@ApiBearerAuth()
@Controller('quests')
export class QuestsController {
  constructor(
    private readonly quests: QuestsService,
    private readonly finalizer: CheckinFinalizerService,
  ) {}

  @Get(':eventId/status')
  @ApiOperation({ summary: 'Active quest state for the current user + event' })
  status(@CurrentUser() user: User, @Param('eventId') eventId: string) {
    return this.quests.getStatus(user, eventId);
  }

  @Post(':eventId/sync')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Batch ingest of locus events + geolocator pings' })
  sync(
    @CurrentUser() user: User,
    @Param('eventId') eventId: string,
    @Body() dto: SyncTrackingDto,
  ) {
    return this.quests.sync(user, eventId, dto);
  }

  @Post(':eventId/integrity')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Submit App Attest / Play Integrity token' })
  integrity(
    @CurrentUser() user: User,
    @Param('eventId') eventId: string,
    @Body() dto: IntegrityDto,
  ) {
    return this.quests.attestIntegrity(user, eventId, dto);
  }

  @Post(':eventId/photo')
  @HttpCode(HttpStatus.OK)
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: { type: 'string', format: 'binary' },
        exifTimestamp: { type: 'string', format: 'date-time' },
        exifLatitude: { type: 'number' },
        exifLongitude: { type: 'number' },
        exifRaw: { type: 'string', description: 'JSON string of raw EXIF map' },
      },
      required: ['file'],
    },
  })
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 12 * 1024 * 1024 } }))
  @ApiOperation({ summary: 'Upload event photo (multipart) + EXIF metadata' })
  photo(
    @CurrentUser() user: User,
    @Param('eventId') eventId: string,
    @UploadedFile() file: Express.Multer.File,
    @Body() metadata: UploadPhotoMetadataDto,
  ) {
    return this.quests.uploadPhoto(user, eventId, file, metadata);
  }

  @Post(':eventId/finalize')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Force reconciliation for current user (dev/admin)' })
  finalize(@CurrentUser() user: User, @Param('eventId') eventId: string) {
    return this.finalizer.finalize(user.id, eventId);
  }
}
