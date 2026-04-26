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

    return { bucket, path, publicUrl: null };
  }

  async signedPhotoUrl(path: string, expiresInSec = 3600): Promise<string> {
    const { data, error } = await this.supabase.admin.storage
      .from('photos')
      .createSignedUrl(path, expiresInSec);
    if (error || !data?.signedUrl) {
      throw new ApiException(
        HttpStatus.BAD_GATEWAY,
        'STORAGE_SIGN_FAILED',
        error?.message ?? 'Could not sign URL',
      );
    }
    return data.signedUrl;
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
