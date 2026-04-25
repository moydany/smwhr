import { Module } from '@nestjs/common';
import { EventsModule } from '../events/events.module';
import { QuestsController } from './quests.controller';
import { QuestsService } from './quests.service';
import { StorageService } from './storage.service';

@Module({
  imports: [EventsModule],
  controllers: [QuestsController],
  providers: [QuestsService, StorageService],
  exports: [QuestsService, StorageService],
})
export class QuestsModule {}
