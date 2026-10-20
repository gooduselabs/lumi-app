import { Global, Module } from '@nestjs/common';
import { AttachmentsController, ChatController } from './chat.controller';
import { ChatService } from './chat.service';

@Global()
@Module({ controllers: [ChatController, AttachmentsController], providers: [ChatService], exports: [ChatService] })
export class ChatModule {}
