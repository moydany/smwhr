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
    this.logger.log('Supabase admin + anon clients ready');
  }

  get admin(): SupabaseClient {
    return this._admin;
  }

  get anon(): SupabaseClient {
    return this._anon;
  }
}
