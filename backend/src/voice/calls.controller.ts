import { Body, Controller, HttpCode, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiProperty, ApiTags } from '@nestjs/swagger';
import { IsUUID } from 'class-validator';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { CallsService } from './calls.service';

class StartCallDto {
  @ApiProperty() @IsUUID() conversationId: string;
}

@ApiTags('calls')
@ApiBearerAuth()
@Controller('calls')
export class CallsController {
  constructor(private readonly calls: CallsService) {}

  @Post()
  start(@CurrentUser() u: AuthUser, @Body() dto: StartCallDto) {
    return this.calls.start(u.id, dto.conversationId);
  }

  @Post(':id/accept')
  @HttpCode(200)
  accept(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.calls.accept(u.id, id);
  }

  @Post(':id/decline')
  @HttpCode(200)
  decline(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.calls.end(u.id, id, 'DECLINED');
  }

  @Post(':id/end')
  @HttpCode(200)
  end(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.calls.end(u.id, id, 'ENDED');
  }
}
