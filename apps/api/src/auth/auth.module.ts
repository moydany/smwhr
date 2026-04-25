import { Global, Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { SupabaseService } from './supabase.service';

@Global()
@Module({
  controllers: [AuthController],
  providers: [
    AuthService,
    SupabaseService,
    JwtAuthGuard,
    { provide: APP_GUARD, useClass: JwtAuthGuard },
  ],
  exports: [SupabaseService, AuthService],
})
export class AuthModule {}
