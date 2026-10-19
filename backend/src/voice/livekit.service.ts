import { Inject, Injectable } from '@nestjs/common';
import { AccessToken } from 'livekit-server-sdk';
import { APP_ENV, AppEnv } from '../config/env';

@Injectable()
export class LivekitService {
  constructor(@Inject(APP_ENV) private readonly env: AppEnv) {}

  get enabled(): boolean {
    const { url, apiKey, apiSecret } = this.env.livekit;
    return !!(url && apiKey && apiSecret);
  }

  get url(): string | undefined {
    return this.env.livekit.url;
  }

  /** Short-lived token allowing a user to publish/subscribe audio in a single 1-1 room. */
  async token(identity: string, room: string, name: string, ttlSeconds: number): Promise<string> {
    const at = new AccessToken(this.env.livekit.apiKey!, this.env.livekit.apiSecret!, {
      identity,
      name,
      ttl: ttlSeconds,
    });
    at.addGrant({ room, roomJoin: true, canPublish: true, canSubscribe: true, canPublishData: true });
    return at.toJwt();
  }
}
