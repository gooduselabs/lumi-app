import { Global, Module } from '@nestjs/common';
import { SocialController } from './social.controller';
import { SocialService } from './social.service';

@Global()
@Module({ controllers: [SocialController], providers: [SocialService], exports: [SocialService] })
export class SocialModule {}
