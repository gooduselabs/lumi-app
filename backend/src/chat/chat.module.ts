import { Global, Module } from '@nestjs/common';
import { AttachmentsController, ChatController, MessagesController } from './chat.controller';
import { ChatService } from './chat.service';
import { PurgeJob } from './purge.job';

@Global()
@Module({ controllers: [ChatController, AttachmentsController, MessagesController], providers: [ChatService, PurgeJob], exports: [ChatService] })
export class ChatModule {}
