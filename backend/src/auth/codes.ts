import { createHmac, randomInt, timingSafeEqual } from 'crypto';

export const CODE_TTL_MS = 10 * 60 * 1000;
export const CODE_COOLDOWN_MS = 60 * 1000;
export const CODE_MAX_ATTEMPTS = 5;

export function generateCode(): string {
  return randomInt(0, 1_000_000).toString().padStart(6, '0');
}

export function hashCode(secret: string, email: string, purpose: string, code: string): string {
  return createHmac('sha256', secret).update(`${purpose}:${email}:${code}`).digest('hex');
}

export function safeEqualHex(a: string, b: string): boolean {
  const ba = Buffer.from(a, 'hex');
  const bb = Buffer.from(b, 'hex');
  return ba.length === bb.length && timingSafeEqual(ba, bb);
}
