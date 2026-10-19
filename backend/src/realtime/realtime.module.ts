import { Global, Module } from '@nestjs/common';
import { PushService } from '../notifications/push.service';
import { RealtimeEmitter } from './realtime.emitter';

@Global()
@Module({ providers: [RealtimeEmitter, PushService], exports: [RealtimeEmitter, PushService] })
export class RealtimeCoreModule {}
