import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
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
import { OnboardingDto } from './dto/onboarding.dto';
import { UpdateMeDto } from './dto/update-me.dto';
import { UsersService } from './users.service';

@ApiTags('users')
@ApiBearerAuth()
@Controller()
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Authenticated user profile' })
  me(@CurrentUser() user: User) {
    return this.users.getMe(user);
  }

  @Patch('me')
  @ApiOperation({ summary: 'Patch own profile' })
  updateMe(@CurrentUser() user: User, @Body() dto: UpdateMeDto) {
    return this.users.updateMe(user, dto);
  }

  @Post('me/avatar')
  @HttpCode(HttpStatus.OK)
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: { file: { type: 'string', format: 'binary' } },
      required: ['file'],
    },
  })
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }))
  @ApiOperation({ summary: 'Upload own avatar (multipart) and return updated profile' })
  uploadAvatar(@CurrentUser() user: User, @UploadedFile() file: Express.Multer.File) {
    return this.users.uploadAvatar(user, file);
  }

  @Delete('me/avatar')
  @ApiOperation({ summary: 'Clear own avatar' })
  removeAvatar(@CurrentUser() user: User) {
    return this.users.removeAvatar(user);
  }

  @Post('me/onboarding')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Set handle, displayName, interests, etc. on first run' })
  onboarding(@CurrentUser() user: User, @Body() dto: OnboardingDto) {
    return this.users.completeOnboarding(user, dto);
  }

  @Get('users/check-handle/:handle')
  @ApiOperation({ summary: 'Check if a handle is available' })
  checkHandle(@Param('handle') handle: string) {
    return this.users.checkHandleAvailable(handle);
  }

  @Get('users/:handle')
  @ApiOperation({ summary: 'Public profile by handle' })
  byHandle(@Param('handle') handle: string) {
    return this.users.getByHandle(handle);
  }

  @Get('users/:handle/badges')
  @ApiOperation({ summary: 'Public badge collection by handle' })
  badgesByHandle(@Param('handle') handle: string) {
    return this.users.getBadgesByHandle(handle);
  }
}
