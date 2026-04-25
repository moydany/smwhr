import { HttpStatus, Injectable, Logger } from '@nestjs/common';
import { ApiException } from '../common/exceptions/api.exception';
import { SupabaseService } from './supabase.service';

export interface AuthSession {
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
  supabaseUserId: string;
  email: string | null;
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(private readonly supabase: SupabaseService) {}

  async requestEmailMagicLink(email: string): Promise<{ sent: true }> {
    const { error } = await this.supabase.admin.auth.signInWithOtp({
      email,
      options: { shouldCreateUser: true },
    });
    if (error) {
      this.logger.warn(`signInWithOtp failed: ${error.message}`);
      throw new ApiException(HttpStatus.BAD_REQUEST, 'AUTH_OTP_FAILED', error.message);
    }
    return { sent: true };
  }

  async verifyEmailMagicLink(email: string, token: string): Promise<AuthSession> {
    const { data, error } = await this.supabase.admin.auth.verifyOtp({
      email,
      token,
      type: 'email',
    });
    if (error || !data.session || !data.user) {
      throw new ApiException(
        HttpStatus.UNAUTHORIZED,
        'AUTH_INVALID_OTP',
        error?.message ?? 'Invalid OTP',
      );
    }
    return this.toSession(data.session, data.user);
  }

  async refreshSession(refreshToken: string): Promise<AuthSession> {
    const { data, error } = await this.supabase.admin.auth.refreshSession({
      refresh_token: refreshToken,
    });
    if (error || !data.session || !data.user) {
      throw new ApiException(
        HttpStatus.UNAUTHORIZED,
        'AUTH_INVALID_REFRESH',
        error?.message ?? 'Invalid refresh token',
      );
    }
    return this.toSession(data.session, data.user);
  }

  notImplemented(provider: 'apple' | 'google'): never {
    throw new ApiException(
      HttpStatus.NOT_IMPLEMENTED,
      'AUTH_PROVIDER_NOT_CONFIGURED',
      `${provider} sign-in not configured yet — add provider credentials in Supabase dashboard`,
    );
  }

  private toSession(
    session: { access_token: string; refresh_token: string; expires_at?: number },
    user: { id: string; email?: string | null },
  ): AuthSession {
    return {
      accessToken: session.access_token,
      refreshToken: session.refresh_token,
      expiresAt: session.expires_at ?? 0,
      supabaseUserId: user.id,
      email: user.email ?? null,
    };
  }
}
