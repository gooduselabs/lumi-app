import { Inject, Injectable, Logger, OnApplicationBootstrap, OnModuleDestroy } from '@nestjs/common';
import { APP_ENV, AppEnv } from '../config/env';
import { ChatService } from './chat.service';

/** Periodically deletes undelivered messages / attachments older than MESSAGE_TTL_DAYS. */
@Injectable()
export class PurgeJob implements OnApplicationBootstrap, OnModuleDestroy {
  private readonly logger = new Logger(PurgeJob.name);
  private timer?: NodeJS.Timeout;

  constructor(private readonly chat: ChatService, @Inject(APP_ENV) private readonly env: AppEnv) {}

  onApplicationBootstrap() {
    const every = this.env.purgeIntervalMinutes;
    if (!every || this.env.nodeEnv === 'test') return;
    this.timer = setInterval(() => void this.run(), every * 60_000);
    this.timer.unref();
    setTimeout(() => void this.run(), 10_000).unref();
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  async run() {
    try {
      const r = await this.chat.purgeExpired();
      if (r.messages || r.orphans) this.logger.log(`Purged ${r.messages} expired messages, ${r.orphans} orphan uploads`);
    } catch (e) {
      this.logger.error(e);
    }
  }
}
