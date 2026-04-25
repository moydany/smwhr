import { Module } from '@nestjs/common';
import { EventsModule } from '../events/events.module';
import { CloseEndedEventsCron } from './cron/close-ended-events.cron';
import { QuestsController } from './quests.controller';
import { QuestsService } from './quests.service';
import { CheckinFinalizerService } from './services/checkin-finalizer.service';
import { GeoService } from './services/geo.service';
import { ReconciliationService } from './services/reconciliation.service';
import { VerificationService } from './services/verification.service';
import { StorageService } from './storage.service';

@Module({
  imports: [EventsModule],
  controllers: [QuestsController],
  providers: [
    QuestsService,
    StorageService,
    GeoService,
    ReconciliationService,
    VerificationService,
    CheckinFinalizerService,
    CloseEndedEventsCron,
  ],
  exports: [QuestsService, StorageService, GeoService, CheckinFinalizerService],
})
export class QuestsModule {}
