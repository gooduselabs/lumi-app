// Test defaults: a dedicated database + redis db, fast sessions, codes exposed in responses.
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL ??= 'postgresql://lumi:lumi@localhost:5432/lumi_test?schema=public';
process.env.REDIS_URL ??= 'redis://localhost:6379/15';
process.env.JWT_ACCESS_SECRET ??= 'test-access-secret-test-access-secret';
process.env.JWT_REFRESH_SECRET ??= 'test-refresh-secret-test-refresh-secret';
process.env.DEV_EXPOSE_CODES = 'true';
process.env.SMTP_HOST = '';
process.env.SOUL_MATCH_SECONDS = '6';
process.env.THROTTLE_DISABLED = 'true';
process.env.LIVEKIT_URL = 'ws://localhost:7880';
process.env.LIVEKIT_API_KEY = 'devkey';
process.env.LIVEKIT_API_SECRET = 'secret-secret-secret-secret-secret';
