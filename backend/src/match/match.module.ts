import { Global, Module } from '@nestjs/common';
import { LivekitService } from '../voice/livekit.service';
import { MatchController } from './match.controller';
import { MatchService } from './match.service';

@Global()
@Module({ controllers: [MatchController], providers: [MatchService, LivekitService], exports: [MatchService, LivekitService] })
export class MatchModule {}
