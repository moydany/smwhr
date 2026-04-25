import { HttpStatus, Injectable } from '@nestjs/common';
import type { User } from '@prisma/client';
import { Prisma } from '@prisma/client';
import { AuditService } from '../audit/audit.service';
import { ApiException } from '../common/exceptions/api.exception';
import { PrismaService } from '../prisma/prisma.service';
import { EventsService } from './events.service';

@Injectable()
export class IntentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly events: EventsService,
    private readonly audit: AuditService,
  ) {}

  async getMine(user: User, eventId: string) {
    const intent = await this.prisma.intent.findUnique({
      where: { userId_eventId: { userId: user.id, eventId } },
    });
    return { has: Boolean(intent), intent };
  }

  async listForEvent(eventId: string) {
    await this.events.byId(eventId);
    return this.prisma.intent.findMany({
      where: { eventId },
      include: { user: { select: { handle: true, displayName: true, avatarUrl: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  async create(user: User, eventId: string) {
    const event = await this.events.byId(eventId);
    try {
      const intent = await this.prisma.$transaction(async (tx) => {
        const created = await tx.intent.create({
          data: { userId: user.id, eventId: event.id },
        });
        await tx.event.update({
          where: { id: event.id },
          data: { intentCount: { increment: 1 } },
        });
        return created;
      });
      await this.audit.record({ type: 'INTENT_SET', userId: user.id, eventId: event.id });
      return { intent, eventId: event.id };
    } catch (err) {
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        throw new ApiException(HttpStatus.CONFLICT, 'INTENT_EXISTS', 'Intent already set');
      }
      throw err;
    }
  }

  async remove(user: User, eventId: string) {
    const event = await this.events.byId(eventId);
    try {
      await this.prisma.$transaction(async (tx) => {
        await tx.intent.delete({
          where: { userId_eventId: { userId: user.id, eventId: event.id } },
        });
        await tx.event.update({
          where: { id: event.id },
          data: { intentCount: { decrement: 1 } },
        });
      });
      await this.audit.record({ type: 'INTENT_CLEARED', userId: user.id, eventId: event.id });
    } catch (err) {
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2025') {
        return;
      }
      throw err;
    }
  }
}
