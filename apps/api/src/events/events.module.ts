import { Module } from '@nestjs/common';
import { EventsController } from './events.controller';
import { EventsService } from './events.service';
import { IntentsService } from './intents.service';

@Module({
  controllers: [EventsController],
  providers: [EventsService, IntentsService],
  exports: [EventsService, IntentsService],
})
export class EventsModule {}
