import { Global, Module } from '@nestjs/common';
import { CallsController } from './calls.controller';
import { CallsService } from './calls.service';
import { LivekitService } from './livekit.service';

@Global()
@Module({ controllers: [CallsController], providers: [LivekitService, CallsService], exports: [LivekitService, CallsService] })
export class VoiceModule {}
