export interface AppEnv {
  nodeEnv: string;
  isProd: boolean;
  port: number;
  corsOrigins: string[] | '*';
  databaseUrl: string;
  redisUrl: string;
  jwtAccessSecret: string;
  jwtRefreshSecret: string;
  jwtAccessTtl: number;
  jwtRefreshTtlDays: number;
  codeHmacSecret: string;
  smtp: { host?: string; port: number; secure: boolean; user?: string; pass?: string; from: string };
  devExposeCodes: boolean;
  soulMatchSeconds: number;
  voiceMatchSeconds: number;
  livekit: { url?: string; apiKey?: string; apiSecret?: string };
}

const num = (v: string | undefined, d: number) => (v && !Number.isNaN(Number(v)) ? Number(v) : d);
const bool = (v: string | undefined) => v === 'true' || v === '1';

export function loadEnv(src: NodeJS.ProcessEnv = process.env): AppEnv {
  const nodeEnv = src.NODE_ENV ?? 'development';
  const isProd = nodeEnv === 'production';
  const required = ['DATABASE_URL', 'REDIS_URL', 'JWT_ACCESS_SECRET', 'JWT_REFRESH_SECRET'];
  const missing = required.filter((k) => !src[k]);
  if (missing.length) throw new Error(`Missing env: ${missing.join(', ')}`);
  if (isProd && (src.JWT_ACCESS_SECRET!.length < 32 || src.JWT_ACCESS_SECRET!.startsWith('change-me'))) {
    throw new Error('JWT_ACCESS_SECRET must be a strong secret in production');
  }
  const cors = src.CORS_ORIGINS ?? '*';
  return {
    nodeEnv,
    isProd,
    port: num(src.PORT, 3000),
    corsOrigins: cors === '*' ? '*' : cors.split(',').map((s) => s.trim()),
    databaseUrl: src.DATABASE_URL!,
    redisUrl: src.REDIS_URL!,
    jwtAccessSecret: src.JWT_ACCESS_SECRET!,
    jwtRefreshSecret: src.JWT_REFRESH_SECRET!,
    jwtAccessTtl: num(src.JWT_ACCESS_TTL_SECONDS, 900),
    jwtRefreshTtlDays: num(src.JWT_REFRESH_TTL_DAYS, 30),
    codeHmacSecret: src.CODE_HMAC_SECRET ?? src.JWT_ACCESS_SECRET!,
    smtp: {
      host: src.SMTP_HOST || undefined,
      port: num(src.SMTP_PORT, 587),
      secure: bool(src.SMTP_SECURE),
      user: src.SMTP_USER || undefined,
      pass: src.SMTP_PASS || undefined,
      from: src.MAIL_FROM ?? 'Lumi <no-reply@lumi.local>',
    },
    // Never expose codes in production, whatever the flag says.
    devExposeCodes: !isProd && bool(src.DEV_EXPOSE_CODES),
    soulMatchSeconds: num(src.SOUL_MATCH_SECONDS, 180),
    voiceMatchSeconds: num(src.VOICE_MATCH_SECONDS, 420),
    livekit: {
      url: src.LIVEKIT_URL || undefined,
      apiKey: src.LIVEKIT_API_KEY || undefined,
      apiSecret: src.LIVEKIT_API_SECRET || undefined,
    },
  };
}

export const APP_ENV = Symbol('APP_ENV');
