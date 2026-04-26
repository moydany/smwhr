import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SupabaseClient, createClient } from '@supabase/supabase-js';

@Injectable()
export class SupabaseService implements OnModuleInit {
  private readonly logger = new Logger(SupabaseService.name);
  private _admin!: SupabaseClient;
  private _anon!: SupabaseClient;

  constructor(private readonly config: ConfigService) {}

  onModuleInit() {
    const url = this.config.getOrThrow<string>('supabase.url');
    const serviceKey = this.config.getOrThrow<string>('supabase.serviceRoleKey');
    const anonKey = this.config.getOrThrow<string>('supabase.anonKey');

    this._admin = createClient(url, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    this._anon = createClient(url, anonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    // Diagnostic: log the role claim of each loaded JWT and the last
    // 8 chars of the key so we can confirm the running process picked
    // up the right env at boot. If this prints `role=anon` for the
    // admin client, RLS will reject every storage write — the .env
    // wiring is wrong even though the file looks correct.
    this.logger.log(
      `Supabase ready url=${url} ` +
        `admin=${this._roleClaim(serviceKey)}/${serviceKey.slice(-8)} ` +
        `anon=${this._roleClaim(anonKey)}/${anonKey.slice(-8)}`,
    );
  }

  private _roleClaim(jwt: string): string {
    try {
      const payload = jwt.split('.')[1];
      if (!payload) return 'unparseable';
      const decoded = JSON.parse(
        Buffer.from(payload, 'base64').toString('utf8'),
      );
      return String(decoded?.role ?? 'no-role');
    } catch {
      return 'unparseable';
    }
  }

  get admin(): SupabaseClient {
    return this._admin;
  }

  get anon(): SupabaseClient {
    return this._anon;
  }
}
