import { AttachmentKind } from '@prisma/client';
import { createHmac, timingSafeEqual } from 'crypto';
import { extname } from 'path';

export const MAX_VOICE_MS = 5 * 60 * 1000;
export const MAX_CAPTION = 500;

/** MIME allowlist per kind. Images are additionally verified by magic bytes. */
export const ALLOWED: Record<AttachmentKind, Record<string, string[]>> = {
  IMAGE: {
    'image/jpeg': ['.jpg', '.jpeg'],
    'image/png': ['.png'],
    'image/webp': ['.webp'],
    'image/gif': ['.gif'],
    'image/heic': ['.heic'],
  },
  VOICE: {
    'audio/mp4': ['.m4a', '.mp4', '.aac'],
    'audio/m4a': ['.m4a'],
    'audio/x-m4a': ['.m4a'],
    'audio/aac': ['.aac', '.m4a'],
    'audio/mpeg': ['.mp3'],
    'audio/ogg': ['.ogg', '.oga', '.opus'],
    'audio/opus': ['.opus'],
    'audio/webm': ['.webm', '.weba'],
    'audio/wav': ['.wav'],
    'audio/x-wav': ['.wav'],
  },
  FILE: {
    'application/pdf': ['.pdf'],
    'text/plain': ['.txt', '.md', '.csv', '.log'],
    'text/csv': ['.csv'],
    'application/zip': ['.zip'],
    'application/x-zip-compressed': ['.zip'],
    'application/msword': ['.doc'],
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': ['.docx'],
    'application/vnd.ms-excel': ['.xls'],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': ['.xlsx'],
    'application/vnd.ms-powerpoint': ['.ppt'],
    'application/vnd.openxmlformats-officedocument.presentationml.presentation': ['.pptx'],
    'image/jpeg': ['.jpg', '.jpeg'],
    'image/png': ['.png'],
    'audio/mpeg': ['.mp3'],
    'video/mp4': ['.mp4'],
  },
};

/** Clients often send octet-stream: infer from extension within the kind's allowlist. */
export function resolveMime(kind: AttachmentKind, declared: string | undefined, fileName: string): string | null {
  const ext = extname(fileName).toLowerCase();
  const table = ALLOWED[kind];
  const d = (declared ?? '').split(';')[0].trim().toLowerCase();
  if (d && table[d] && (!ext || table[d].includes(ext))) return d;
  if (!ext) return null;
  const hit = Object.entries(table).find(([, exts]) => exts.includes(ext));
  return hit ? hit[0] : null;
}

export function sniffImage(buf: Buffer): string | null {
  if (buf.length < 12) return null;
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'image/jpeg';
  if (buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'image/png';
  if (buf.subarray(0, 4).toString('ascii') === 'RIFF' && buf.subarray(8, 12).toString('ascii') === 'WEBP') return 'image/webp';
  if (buf.subarray(0, 3).toString('ascii') === 'GIF') return 'image/gif';
  if (buf.subarray(4, 8).toString('ascii') === 'ftyp') return 'image/heic';
  return null;
}

/** Strip paths / control chars; keep a readable name for display + Content-Disposition. */
export function safeFileName(name: string | undefined, fallback: string): string {
  const base = (name ?? '').split(/[\\/]/).pop() ?? '';
  // eslint-disable-next-line no-control-regex
  const clean = base.replace(/[\u0000-\u001f\u007f"]/g, '').trim().slice(0, 120);
  return clean || fallback;
}

export function extFor(mime: string, kind: AttachmentKind): string {
  return ALLOWED[kind][mime]?.[0] ?? '';
}

// ---- signed download URLs (for <img>/audio players that cannot send headers) ----

export function signAttachment(secret: string, id: string, exp: number): string {
  return createHmac('sha256', secret).update(`att:${id}:${exp}`).digest('base64url');
}

export function verifyAttachmentSig(secret: string, id: string, exp: number, sig: string, now = Date.now()): boolean {
  if (!Number.isFinite(exp) || exp * 1000 < now || !sig) return false;
  const want = Buffer.from(signAttachment(secret, id, exp));
  const got = Buffer.from(sig);
  return want.length === got.length && timingSafeEqual(want, got);
}
