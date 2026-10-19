import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { ReportDto } from './dto/social.dto';
import { SocialService } from './social.service';

@ApiTags('social')
@ApiBearerAuth()
@Controller()
export class SocialController {
  constructor(private readonly social: SocialService) {}

  @Get('friends')
  friends(@CurrentUser() u: AuthUser) {
    return this.social.listFriends(u.id);
  }

  @Delete('friends/:userId')
  unfriend(@CurrentUser() u: AuthUser, @Param('userId', ParseUUIDPipe) id: string) {
    return this.social.unfriend(u.id, id);
  }

  @Get('blocks')
  blocks(@CurrentUser() u: AuthUser) {
    return this.social.listBlocks(u.id);
  }

  @Post('blocks/:userId')
  @HttpCode(200)
  block(@CurrentUser() u: AuthUser, @Param('userId', ParseUUIDPipe) id: string) {
    return this.social.block(u.id, id);
  }

  @Delete('blocks/:userId')
  unblock(@CurrentUser() u: AuthUser, @Param('userId', ParseUUIDPipe) id: string) {
    return this.social.unblock(u.id, id);
  }

  @Post('reports')
  report(@CurrentUser() u: AuthUser, @Body() dto: ReportDto) {
    return this.social.report(u.id, dto);
  }
}
