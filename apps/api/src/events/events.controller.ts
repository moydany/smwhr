import {
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { User } from '@prisma/client';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { IntentsService } from './intents.service';
import { ListEventsDto } from './dto/list-events.dto';
import { EventsService } from './events.service';

@ApiTags('events')
@ApiBearerAuth()
@Controller('events')
export class EventsController {
  constructor(
    private readonly events: EventsService,
    private readonly intents: IntentsService,
  ) {}

  @Get()
  @ApiOperation({ summary: 'List events with filters' })
  list(@Query() q: ListEventsDto) {
    return this.events.list(q);
  }

  @Get(':slug')
  @ApiOperation({ summary: 'Event detail by slug' })
  bySlug(@Param('slug') slug: string) {
    return this.events.bySlug(slug);
  }

  @Get(':id/intent')
  @ApiOperation({ summary: 'Whether the current user has an intent on this event' })
  myIntent(@CurrentUser() user: User, @Param('id') id: string) {
    return this.intents.getMine(user, id);
  }

  @Post(':id/intent')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "Set 'I'll be there'" })
  setIntent(@CurrentUser() user: User, @Param('id') id: string) {
    return this.intents.create(user, id);
  }

  @Delete(':id/intent')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Cancel intent' })
  removeIntent(@CurrentUser() user: User, @Param('id') id: string) {
    return this.intents.remove(user, id);
  }

  @Get(':id/intents')
  @ApiOperation({ summary: 'List of users with intent on this event' })
  listIntents(@Param('id') id: string) {
    return this.intents.listForEvent(id);
  }
}
