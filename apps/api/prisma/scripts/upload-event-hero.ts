/**
 * Operational one-off: upload a local image as an event's hero artwork.
 *
 * Usage:
 *   pnpm --filter api db:upload-hero <slug> <localPath>
 *
 * Behavior:
 *   1. Ensures the `events` bucket exists in Supabase Storage. Public
 *      so the mobile / landing can `<img src>` it without signing on
 *      every read.
 *   2. Uploads `<localPath>` to `events/<slug>/hero.<ext>` (upserting
 *      so re-running with a new file replaces in place).
 *   3. Updates `event.heroImageUrl` to the bucket's public URL.
 *
 * Idempotent — re-runnable safely.
 */
import { createClient } from '@supabase/supabase-js';
import { PrismaClient } from '@prisma/client';
import { existsSync, readFileSync, statSync } from 'node:fs';
import { extname, resolve } from 'node:path';

// Standalone scripts don't go through @nestjs/config so we load
// `apps/api/.env` ourselves. Prisma's own engine already picks up
// DATABASE_URL via its bundled loader; we only need the Supabase keys
// here. Walk up at most three levels to tolerate `pnpm` invocations
// from a different cwd.
loadDotenv();

const prisma = new PrismaClient();

function loadDotenv() {
  for (const candidate of ['.env', '../.env', '../../.env']) {
    const p = resolve(process.cwd(), candidate);
    if (!existsSync(p)) continue;
    for (const raw of readFileSync(p, 'utf8').split('\n')) {
      const line = raw.trim();
      if (!line || line.startsWith('#')) continue;
      const eq = line.indexOf('=');
      if (eq < 0) continue;
      const key = line.slice(0, eq).trim();
      let value = line.slice(eq + 1).trim();
      if (
        (value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))
      ) {
        value = value.slice(1, -1);
      }
      if (process.env[key] === undefined) process.env[key] = value;
    }
    return;
  }
}

const BUCKET = 'events';

async function main() {
  const [, , slug, localPath] = process.argv;
  if (!slug || !localPath) {
    console.error('Usage: ts-node upload-event-hero.ts <slug> <localPath>');
    process.exit(2);
  }

  const url = process.env.SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceKey) {
    console.error('SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing — load apps/api/.env first');
    process.exit(1);
  }

  const event = await prisma.event.findUnique({ where: { slug } });
  if (!event) {
    console.error(`event not found: slug=${slug}`);
    process.exit(1);
  }

  const fileBuffer = readFileSync(localPath);
  const fileSize = statSync(localPath).size;
  const ext = extname(localPath).toLowerCase() || '.png';
  const mime = mimeFor(ext);
  const path = `${slug}/hero${ext}`;

  console.log(`📦 ${localPath} → ${BUCKET}/${path}  (${fileSize} bytes, ${mime})`);

  const supabase = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Ensure bucket exists (public). createBucket fails with a clear
  // error if it already exists; we treat that as success.
  const created = await supabase.storage.createBucket(BUCKET, { public: true });
  if (created.error) {
    const msg = created.error.message.toLowerCase();
    if (!msg.includes('already exists') && !msg.includes('duplicate')) {
      throw created.error;
    }
    console.log(`  bucket "${BUCKET}" already exists ✓`);
  } else {
    console.log(`  bucket "${BUCKET}" created (public) ✓`);
  }

  const upload = await supabase.storage
    .from(BUCKET)
    .upload(path, fileBuffer, { contentType: mime, upsert: true });
  if (upload.error) throw upload.error;
  console.log(`  uploaded ✓`);

  const { data } = supabase.storage.from(BUCKET).getPublicUrl(path);
  const publicUrl = data.publicUrl;
  console.log(`  public URL: ${publicUrl}`);

  await prisma.event.update({
    where: { id: event.id },
    data: { heroImageUrl: publicUrl },
  });
  console.log(`✓ event.heroImageUrl updated for ${slug}`);
}

function mimeFor(ext: string): string {
  switch (ext) {
    case '.png':
      return 'image/png';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.webp':
      return 'image/webp';
    case '.heic':
    case '.heif':
      return 'image/heic';
    default:
      return 'application/octet-stream';
  }
}

main()
  .catch((e) => {
    console.error('upload-event-hero failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
