import {
  Body, Controller, Get, Headers, HttpCode, Inject, Param, ParseUUIDPipe, Post, Query, Res, StreamableFile, UploadedFile, UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { AttachmentKind } from '@prisma/client';
import { Type } from 'class-transformer';
import { IsEnum, IsInt, IsOptional, IsString, Max, MaxLength, Min, MinLength } from 'class-validator';
import type { Response } from 'express';
import { AuthService } from '../auth/auth.service';
import { Public } from '../common/public.decorator';
import { loadEnv } from '../config/env';
import { MAX_CAPTION, MAX_VOICE_MS } from './media';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { ChatService, MAX_MESSAGE_LENGTH } from './chat.service';
import { HistoryQuery } from './dto/chat.dto';

class SendMessageDto {
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(MAX_MESSAGE_LENGTH) body: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(64) clientId?: string;
}

class SendMediaDto {
  @ApiProperty({ enum: AttachmentKind }) @IsEnum(AttachmentKind) kind: AttachmentKind;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(MAX_CAPTION) caption?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(64) clientId?: string;
  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(MAX_VOICE_MS) durationMs?: number;
  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(20000) width?: number;
  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(20000) height?: number;
}

class DownloadQuery {
  @IsOptional() @Type(() => Number) @IsInt() exp?: number;
  @IsOptional() @IsString() @MaxLength(128) sig?: string;
  @IsOptional() @IsString() download?: string;
}

// multer hard limit (+1 byte so the service can report FILE_TOO_LARGE with a clear code).
const UPLOAD_LIMIT = (() => {
  try {
    return loadEnv().storage.maxUploadBytes + 1;
  } catch {
    return 20 * 1024 * 1024 + 1;
  }
})();

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

  @Post(':id/media')
  @ApiConsumes('multipart/form-data')
  @ApiBody({ schema: { type: 'object', properties: { file: { type: 'string', format: 'binary' }, kind: { type: 'string' } } } })
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: UPLOAD_LIMIT, files: 1 } }))
  sendMedia(
    @CurrentUser() u: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @UploadedFile() file: Express.Multer.File | undefined,
    @Body() dto: SendMediaDto,
  ) {
    return this.chat.sendMedia(u.id, id, file, dto);
  }

  @Post(':id/read')
  @HttpCode(200)
  read(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.chat.markRead(u.id, id);
  }
}

/** Downloads: signed URL (?exp&sig) or Bearer token of a conversation member. */
@ApiTags('chat')
@Controller('attachments')
export class AttachmentsController {
  constructor(private readonly chat: ChatService, @Inject(AuthService) private readonly auth: AuthService) {}

  @Public()
  @Get(':id')
  async download(
    @Param('id', ParseUUIDPipe) id: string,
    @Query() q: DownloadQuery,
    @Headers('authorization') authz: string | undefined,
    @Res({ passthrough: true }) res: Response,
  ) {
    let userId: string | undefined;
    if (!q.sig && authz?.startsWith('Bearer ')) userId = (await this.auth.verifyAccessToken(authz.slice(7))).id;
    const { attachment: a, stream } = await this.chat.openAttachment(id, { userId, exp: q.exp, sig: q.sig });
    const inline = a.kind !== 'FILE' && q.download === undefined;
    res.set({
      'Content-Type': a.mimeType,
      'Content-Length': String(a.sizeBytes),
      'Content-Disposition': `${inline ? 'inline' : 'attachment'}; filename*=UTF-8''${encodeURIComponent(a.fileName)}`,
      'X-Content-Type-Options': 'nosniff',
      'Cache-Control': 'private, max-age=3600',
      'Cross-Origin-Resource-Policy': 'cross-origin',
      'Content-Security-Policy': "default-src 'none'; sandbox",
    });
    return new StreamableFile(stream);
  }
}
