import { Controller, Get, Param } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { User } from '@prisma/client';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { BadgesService } from './badges.service';

@ApiTags('badges')
@ApiBearerAuth()
@Controller()
export class BadgesController {
  constructor(private readonly badges: BadgesService) {}

  @Get('me/badges')
  @ApiOperation({ summary: 'Authenticated user collection' })
  mine(@CurrentUser() user: User) {
    return this.badges.listMine(user);
  }

  @Get('badges/:id')
  @ApiOperation({ summary: 'Badge detail' })
  byId(@Param('id') id: string) {
    return this.badges.byId(id);
  }

  @Get('badges/:id/share')
  @ApiOperation({ summary: 'Share payload for IG / generic' })
  share(@Param('id') id: string) {
    return this.badges.share(id);
  }
}
