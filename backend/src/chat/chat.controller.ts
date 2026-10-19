import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { ChatService, MAX_MESSAGE_LENGTH } from './chat.service';
import { HistoryQuery } from './dto/chat.dto';

class SendMessageDto {
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(MAX_MESSAGE_LENGTH) body: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(64) clientId?: string;
}

@ApiTags('chat')
@ApiBearerAuth()
@Controller('conversations')
export class ChatController {
  constructor(private readonly chat: ChatService) {}

  @Get()
  list(@CurrentUser() u: AuthUser) {
    return this.chat.listConversations(u.id);
  }

  @Get(':id')
  get(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.chat.conversation(u.id, id);
  }

  @Get(':id/messages')
  history(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Query() q: HistoryQuery) {
    return this.chat.history(u.id, id, q.before, q.limit);
  }

  @Post(':id/messages')
  send(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: SendMessageDto) {
    return this.chat.send(u.id, id, dto.body, dto.clientId);
  }

  @Post(':id/read')
  @HttpCode(200)
  read(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.chat.markRead(u.id, id);
  }
}
