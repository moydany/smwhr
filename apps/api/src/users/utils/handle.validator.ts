export const HANDLE_MIN_LENGTH = 3;
export const HANDLE_MAX_LENGTH = 20;

const ALLOWED = /^[a-z0-9_]+$/;
const STARTS_WITH_ALNUM = /^[a-z0-9]/;

export const RESERVED_HANDLES = new Set([
  'admin', 'smwhr', 'support', 'help', 'official', 'staff', 'team',
  'api', 'root', 'test', 'demo', 'example', 'user', 'me',
]);

export function normalizeHandle(raw: string): string {
  let v = raw.trim().toLowerCase();
  if (v.startsWith('@')) v = v.slice(1);
  return v.replace(/\s/g, '');
}

export function validateHandle(raw: string): { ok: true } | { ok: false; reason: string } {
  const h = normalizeHandle(raw);
  if (h.length === 0) return { ok: false, reason: 'Handle is required' };
  if (h.length < HANDLE_MIN_LENGTH) {
    return { ok: false, reason: `Handle must be at least ${HANDLE_MIN_LENGTH} characters` };
  }
  if (h.length > HANDLE_MAX_LENGTH) {
    return { ok: false, reason: `Handle must be at most ${HANDLE_MAX_LENGTH} characters` };
  }
  if (!STARTS_WITH_ALNUM.test(h)) {
    return { ok: false, reason: 'Handle must start with a letter or digit' };
  }
  if (!ALLOWED.test(h)) {
    return { ok: false, reason: 'Handle may only contain a-z, 0-9 and underscore' };
  }
  if (RESERVED_HANDLES.has(h)) {
    return { ok: false, reason: 'Handle is reserved' };
  }
  return { ok: true };
}
