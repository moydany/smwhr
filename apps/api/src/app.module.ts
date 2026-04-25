import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import configuration from './config/configuration';
import { validationSchema } from './config/validation.schema';
import { AuthModule } from './auth/auth.module';
import { BadgesModule } from './badges/badges.module';
import { EventsModule } from './events/events.module';
import { HealthModule } from './health/health.module';
import { PrismaModule } from './prisma/prisma.module';
import { QuestsModule } from './quests/quests.module';
import { UsersModule } from './users/users.module';
import { WaitlistModule } from './waitlist/waitlist.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
      validationSchema,
      validationOptions: { abortEarly: false },
    }),
    ScheduleModule.forRoot(),
    PrismaModule,
    AuthModule,
    UsersModule,
    EventsModule,
    QuestsModule,
    BadgesModule,
    WaitlistModule,
    HealthModule,
  ],
})
export class AppModule {}
