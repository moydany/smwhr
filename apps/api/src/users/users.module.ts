import { Module } from '@nestjs/common';
import { QuestsModule } from '../quests/quests.module';
import { StorageService } from '../quests/storage.service';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

@Module({
  imports: [QuestsModule],
  controllers: [UsersController],
  providers: [UsersService, StorageService],
  exports: [UsersService],
})
export class UsersModule {}
