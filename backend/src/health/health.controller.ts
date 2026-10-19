import { Controller, Get, Inject } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';
import Redis from 'ioredis';
import { Public } from '../common/public.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { REDIS } from '../redis/redis.module';

@ApiTags('health')
@Public()
@SkipThrottle()
@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService, @Inject(REDIS) private readonly redis: Redis) {}

  @Get()
  async health() {
    const [db, cache] = await Promise.all([
      this.prisma.$queryRaw`SELECT 1`.then(() => 'up').catch(() => 'down'),
      this.redis.ping().then(() => 'up').catch(() => 'down'),
    ]);
    return { status: db === 'up' && cache === 'up' ? 'ok' : 'degraded', db, redis: cache, time: new Date() };
  }
}
