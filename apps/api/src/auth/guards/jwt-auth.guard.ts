import {
  CanActivate,
  ExecutionContext,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { PrismaService } from '../../prisma/prisma.service';
import { SupabaseService } from '../supabase.service';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';

@Injectable()
export class JwtAuthGuard implements CanActivate {
  private readonly logger = new Logger(JwtAuthGuard.name);

  constructor(
    private readonly reflector: Reflector,
    private readonly supabase: SupabaseService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      ctx.getHandler(),
      ctx.getClass(),
    ]);
    if (isPublic) return true;

    const req = ctx.switchToHttp().getRequest<Request>();
    const auth = req.headers['authorization'];
    if (!auth || typeof auth !== 'string' || !auth.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing bearer token');
    }
    const token = auth.slice('Bearer '.length).trim();
    if (!token) throw new UnauthorizedException('Empty bearer token');

    const { data, error } = await this.supabase.admin.auth.getUser(token);
    if (error || !data.user) {
      this.logger.debug(`token rejected: ${error?.message ?? 'no user'}`);
      throw new UnauthorizedException('Invalid or expired token');
    }
    const sb = data.user;

    let user = await this.prisma.user.findUnique({ where: { supabaseUserId: sb.id } });
    if (!user) {
      const placeholderHandle = `pending_${sb.id.slice(0, 8)}`;
      user = await this.prisma.user.create({
        data: {
          supabaseUserId: sb.id,
          email: sb.email ?? `${sb.id}@noemail.smwhr`,
          handle: placeholderHandle,
          displayName: '',
          authProvider: sb.app_metadata?.provider ?? 'email',
          authProviderId: sb.user_metadata?.provider_id ?? null,
        },
      });
    }

    (req as Request & { user: typeof user; supabaseUserId: string }).user = user;
    (req as Request & { user: typeof user; supabaseUserId: string }).supabaseUserId = sb.id;
    return true;
  }
}
