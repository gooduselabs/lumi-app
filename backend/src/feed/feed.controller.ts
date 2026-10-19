import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { CreatePostDto, FeedQuery } from './dto/feed.dto';
import { FeedService } from './feed.service';

@ApiTags('feed')
@ApiBearerAuth()
@Controller('posts')
export class FeedController {
  constructor(private readonly feed: FeedService) {}

  @Get()
  list(@CurrentUser() u: AuthUser, @Query() q: FeedQuery) {
    return this.feed.list(u.id, q.before, q.limit);
  }

  @Post()
  create(@CurrentUser() u: AuthUser, @Body() dto: CreatePostDto) {
    return this.feed.create(u.id, dto.body);
  }

  @Delete(':id')
  remove(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.feed.remove(u.id, id);
  }

  @Post(':id/like')
  @HttpCode(200)
  like(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.feed.like(u.id, id, true);
  }

  @Delete(':id/like')
  unlike(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.feed.like(u.id, id, false);
  }
}
