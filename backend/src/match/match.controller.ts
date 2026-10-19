import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ReportReason } from '@prisma/client';
import { IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';
import { SocialService } from '../social/social.service';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';

class SessionReportDto {
  @ApiProperty({ enum: ReportReason }) @IsEnum(ReportReason) reason: ReportReason;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(500) details?: string;
}
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { MatchService } from './match.service';

/** Matching itself runs over Socket.IO (see README "Realtime events"); these are read helpers. */
@ApiTags('match')
@ApiBearerAuth()
@Controller('match')
export class MatchController {
  constructor(private readonly match: MatchService, private readonly social: SocialService) {}

  @Post('sessions/:id/block')
  @HttpCode(200)
  block(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.match.blockPartner(u.id, id);
  }

  @Post('sessions/:id/report')
  async report(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: SessionReportDto) {
    const targetId = await this.match.partnerOf(u.id, id);
    return this.social.report(u.id, { targetId, reason: dto.reason, details: dto.details, context: `soul:${id}` });
  }

  @Get('stats')
  stats() {
    return this.match.stats();
  }

  @Get('active')
  active(@CurrentUser() u: AuthUser) {
    return this.match.activeSession(u.id);
  }
}
