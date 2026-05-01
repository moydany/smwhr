import { HttpStatus, Injectable, Logger } from '@nestjs/common';
import { ApiException } from '../common/exceptions/api.exception';
import { SupabaseService } from '../auth/supabase.service';

export interface UploadResult {
  bucket: string;
  path: string;
  publicUrl: string | null;
}

@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);

  constructor(private readonly supabase: SupabaseService) {}

  async uploadPhoto(
    userId: string,
    eventId: string,
    photoId: string,
    file: { buffer: Buffer; mimetype: string; originalname?: string },
  ): Promise<UploadResult> {
    const ext = this.extFor(file.mimetype);
    const path = `${userId}/${eventId}/${photoId}${ext}`;
    const bucket = 'photos';

    this.logger.log(
      `upload diag bucket=${bucket} path=${path} mime=${file.mimetype} size=${file.buffer.length}B`,
    );

    const { error } = await this.supabase.admin.storage
      .from(bucket)
      .upload(path, file.buffer, {
        contentType: file.mimetype,
        upsert: false,
      });
    if (error) {
      this.logger.error(`storage upload failed: ${error.message}`);
      throw new ApiException(HttpStatus.BAD_GATEWAY, 'STORAGE_UPLOAD_FAILED', error.message);
    }

    const signedUrl = await this.signedPhotoUrl(path, 10 * 365 * 24 * 3600); // 10 years
    return { bucket, path, publicUrl: signedUrl };
  }

  /// Stores the user's avatar under the same `photos` bucket so we don't
  /// have to provision a second bucket for R0.1. Path is namespaced to
  /// avoid colliding with quest photos. Each call uses a fresh timestamp,
  /// which guarantees a unique path and lets the client cache-bust just
  /// by reading the new signed URL.
  async uploadAvatar(
    userId: string,
    file: { buffer: Buffer; mimetype: string; originalname?: string },
  ): Promise<UploadResult> {
    const ext = this.extFor(file.mimetype);
    const path = `${userId}/avatar/${Date.now()}${ext}`;
    const bucket = 'photos';

    this.logger.log(
      `avatar upload diag bucket=${bucket} path=${path} mime=${file.mimetype} size=${file.buffer.length}B`,
    );

    const { error } = await this.supabase.admin.storage
      .from(bucket)
      .upload(path, file.buffer, {
        contentType: file.mimetype,
        upsert: false,
      });
    if (error) {
      this.logger.error(`avatar upload failed: ${error.message}`);
      throw new ApiException(HttpStatus.BAD_GATEWAY, 'STORAGE_UPLOAD_FAILED', error.message);
    }

    const signedUrl = await this.signedPhotoUrl(path, 10 * 365 * 24 * 3600);
    return { bucket, path, publicUrl: signedUrl };
  }

  /// Best-effort delete. Logs but does not throw on miss — the user's
  /// `avatarUrl` clears regardless so a stale storage object is the worst
  /// case (and gets reaped by Supabase's lifecycle rules eventually).
  async removeObject(path: string): Promise<void> {
    if (!path) return;
    const { error } = await this.supabase.admin.storage
      .from('photos')
      .remove([path]);
    if (error) {
      this.logger.warn(`storage delete missed path=${path}: ${error.message}`);
    }
  }

  async signedPhotoUrl(path: string, expiresInSec = 3600): Promise<string> {
    const url = `${this.supabase.storageUrl}/object/sign/photos/${path}`;
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.supabase.serviceRoleKey}`,
        apikey: this.supabase.serviceRoleKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ expiresIn: expiresInSec }),
    });
    if (!res.ok) {
      const text = await res.text();
      this.logger.error(`sign URL failed ${res.status}: ${text}`);
      throw new ApiException(HttpStatus.BAD_GATEWAY, 'STORAGE_SIGN_FAILED', text);
    }
    const json = (await res.json()) as { signedURL?: string };
    if (!json.signedURL) {
      throw new ApiException(HttpStatus.BAD_GATEWAY, 'STORAGE_SIGN_FAILED', 'No signedURL in response');
    }
    return `${this.supabase.storageUrl}${json.signedURL}`;
  }

  private extFor(mimetype: string): string {
    switch (mimetype) {
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/heic':
      case 'image/heif':
        return '.heic';
      case 'image/webp':
        return '.webp';
      default:
        return '';
    }
  }
}
