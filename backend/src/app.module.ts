import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AuthModule } from './auth/auth.module';
import { ChatModule } from './chat/chat.module';
import { AppConfigModule } from './config/config.module';
import { FeedModule } from './feed/feed.module';
import { HealthController } from './health/health.controller';
import { MailModule } from './mail/mail.module';
import { MatchModule } from './match/match.module';
import { PrismaModule } from './prisma/prisma.module';
import { RealtimeCoreModule } from './realtime/realtime.module';
import { RealtimeGatewayModule } from './realtime/realtime.module.gateway';
import { RedisModule } from './redis/redis.module';
import { StorageModule } from './storage/storage.module';
import { SocialModule } from './social/social.module';
import { VoiceModule } from './voice/voice.module';
import { UsersModule } from './users/users.module';

@Module({
  imports: [
    AppConfigModule,
    ThrottlerModule.forRoot({
      throttlers: [{ name: 'default', ttl: 60_000, limit: Number(process.env.THROTTLE_LIMIT ?? 120) }],
      skipIf: () => process.env.THROTTLE_DISABLED === 'true',
    }),
    PrismaModule,
    RedisModule,
    StorageModule,
    MailModule,
    RealtimeCoreModule,
    AuthModule,
    UsersModule,
    SocialModule,
    ChatModule,
    VoiceModule,
    MatchModule,
    FeedModule,
    RealtimeGatewayModule,
  ],
  controllers: [HealthController],
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}
