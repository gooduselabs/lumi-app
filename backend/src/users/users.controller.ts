import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Put, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser, AuthUser } from '../common/current-user.decorator';
import { Public } from '../common/public.decorator';
import { LocationDto, NearbyQuery, OnboardingDto, UpdateProfileDto } from './dto/profile.dto';
import { AVATAR_IDS, INTERESTS, MAX_INTERESTS } from './meta';
import { UsersService } from './users.service';

@ApiTags('users')
@ApiBearerAuth()
@Controller()
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Public()
  @Get('meta')
  meta() {
    return { avatars: AVATAR_IDS, interests: INTERESTS, maxInterests: MAX_INTERESTS, minAge: 18 };
  }

  @Get('me')
  me(@CurrentUser() u: AuthUser) {
    return this.users.me(u.id);
  }

  @Put('me/onboarding')
  onboard(@CurrentUser() u: AuthUser, @Body() dto: OnboardingDto) {
    return this.users.onboard(u.id, dto);
  }

  @Patch('me')
  update(@CurrentUser() u: AuthUser, @Body() dto: UpdateProfileDto) {
    return this.users.update(u.id, dto);
  }

  @Put('me/location')
  setLocation(@CurrentUser() u: AuthUser, @Body() dto: LocationDto) {
    return this.users.setLocation(u.id, dto.lat, dto.lng);
  }

  @Delete('me/location')
  clearLocation(@CurrentUser() u: AuthUser) {
    return this.users.clearLocation(u.id);
  }

  @Get('nearby')
  nearby(@CurrentUser() u: AuthUser, @Query() q: NearbyQuery) {
    return this.users.nearby(u.id, q);
  }

  @Delete('me')
  remove(@CurrentUser() u: AuthUser) {
    return this.users.deleteAccount(u.id);
  }

  @Get('users/:id')
  profile(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.users.publicProfile(u.id, id);
  }
}
