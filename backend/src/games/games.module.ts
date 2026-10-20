import { Global, Module } from '@nestjs/common';
import { GamesService } from './games.service';

@Global()
@Module({ providers: [GamesService], exports: [GamesService] })
export class GamesModule {}
