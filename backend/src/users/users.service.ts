import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { ageOn, isAdult } from '../common/age';
import { approxKm, boundingBox, coarsen, geohash, haversineKm, isValidLatLng } from '../common/geo';
import { ageAccepts, clampAgeRange } from '../match/match.logic';
import { RealtimeEmitter } from '../realtime/realtime.emitter';
import { SocialService } from '../social/social.service';
import { Errors } from '../common/errors';
import { PrismaService } from '../prisma/prisma.service';
import { NearbyQuery, OnboardingDto, UpdateProfileDto } from './dto/profile.dto';
import { publicSelect, toMe, toPublic } from './user.mapper';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly social: SocialService,
    private readonly rt: RealtimeEmitter,
  ) {}

  async me(userId: string) {
    const u = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!u) throw Errors.unauthorized();
    return toMe(u);
  }

  async onboard(userId: string, dto: OnboardingDto) {
    const birthday = new Date(`${dto.birthday}T00:00:00Z`);
    if (Number.isNaN(birthday.getTime()) || birthday.getUTCFullYear() < 1900) {
      throw Errors.badRequest('INVALID_BIRTHDAY', 'Invalid birthday');
    }
    if (!isAdult(birthday)) throw Errors.underage();
    const u = await this.prisma.user.update({
      where: { id: userId },
      data: {
        nickname: dto.nickname,
        gender: dto.gender,
        birthday,
        avatarId: dto.avatarId,
        bio: dto.bio ?? null,
        interests: [...new Set(dto.interests)],
        onboardedAt: new Date(),
      },
    });
    return toMe(u);
  }

  async update(userId: string, dto: UpdateProfileDto) {
    const data: Prisma.UserUpdateInput = { ...dto, interests: dto.interests ? [...new Set(dto.interests)] : undefined };
    if (dto.agePrefMin != null || dto.agePrefMax != null) {
      const cur = await this.prisma.user.findUnique({ where: { id: userId }, select: { agePrefMin: true, agePrefMax: true } });
      if (!cur) throw Errors.unauthorized();
      const min = dto.agePrefMin ?? cur.agePrefMin;
      const max = dto.agePrefMax ?? cur.agePrefMax;
      if (min > max) throw Errors.badRequest('INVALID_AGE_RANGE', 'agePrefMin must be <= agePrefMax');
    }
    const u = await this.prisma.user.update({ where: { id: userId }, data });
    return toMe(u);
  }

  /** Store a coarsened (~1 km) location. The raw fix is discarded immediately. */
  async setLocation(userId: string, lat: number, lng: number) {
    if (!isValidLatLng(lat, lng)) throw Errors.badRequest('INVALID_LOCATION', 'Invalid coordinates');
    const c = coarsen({ lat, lng });
    const u = await this.prisma.user.update({
      where: { id: userId },
      data: { latCoarse: c.lat, lngCoarse: c.lng, geohash: geohash(c, 6), locationAt: new Date() },
    });
    return toMe(u);
  }

  async clearLocation(userId: string) {
    const u = await this.prisma.user.update({
      where: { id: userId },
      data: { latCoarse: null, lngCoarse: null, geohash: null, locationAt: null },
    });
    return toMe(u);
  }

  /**
   * People near me. Both sides' age ranges must accept each other, the viewer's
   * query filters narrow further. Only an approximate distance is returned.
   */
  async nearby(viewerId: string, q: NearbyQuery) {
    const me = await this.prisma.user.findUnique({ where: { id: viewerId } });
    if (!me) throw Errors.unauthorized();
    if (!me.onboardedAt) throw Errors.notOnboarded();
    if (me.latCoarse == null || me.lngCoarse == null) throw Errors.badRequest('LOCATION_REQUIRED', 'Share your location first');
    if (me.locationHidden) throw Errors.badRequest('LOCATION_HIDDEN', 'Your location is hidden');
    const radiusKm = q.radiusKm ?? 25;
    const origin = { lat: me.latCoarse, lng: me.lngCoarse };
    const box = boundingBox(origin, radiusKm + 1);
    const myAge = me.birthday ? ageOn(me.birthday) : null;
    const range = clampAgeRange(q.minAge ?? me.agePrefMin, q.maxAge ?? me.agePrefMax);
    const blocked = await this.social.blockedIds(viewerId);
    const rows = await this.prisma.user.findMany({
      where: {
        id: { not: viewerId, notIn: [...blocked] },
        onboardedAt: { not: null },
        locationHidden: false,
        latCoarse: { gte: box.minLat, lte: box.maxLat },
        lngCoarse: { gte: box.minLng, lte: box.maxLng },
        ...(q.gender && q.gender !== 'ANY' ? { gender: q.gender } : {}),
      },
      select: { ...publicSelect, latCoarse: true, lngCoarse: true, agePrefMin: true, agePrefMax: true },
      take: 1000,
    });
    const limit = q.limit ?? 50;
    return rows
      .map((r) => ({ r, km: haversineKm(origin, { lat: r.latCoarse!, lng: r.lngCoarse! }) }))
      .filter(({ r, km }) => {
        if (km > radiusKm) return false;
        const age = r.birthday ? ageOn(r.birthday) : null;
        return ageAccepts(range.min, range.max, age) && ageAccepts(r.agePrefMin, r.agePrefMax, myAge);
      })
      .sort((a, b) => a.km - b.km || +(b.r.lastSeenAt ?? 0) - +(a.r.lastSeenAt ?? 0))
      .slice(0, limit)
      .map(({ r, km }) => ({ ...toPublic(r), online: this.rt.isOnline(r.id), distanceKm: approxKm(km) }));
  }

  async publicProfile(viewerId: string, userId: string) {
    const blocked = await this.prisma.block.findFirst({
      where: { OR: [{ blockerId: viewerId, blockedId: userId }, { blockerId: userId, blockedId: viewerId }] },
    });
    const u = await this.prisma.user.findUnique({ where: { id: userId }, select: publicSelect });
    if (!u || (blocked && blocked.blockerId === userId)) throw Errors.notFound('User');
    return { ...toPublic(u), blockedByMe: !!blocked };
  }

  async deleteAccount(userId: string) {
    await this.prisma.user.delete({ where: { id: userId } });
    return { ok: true };
  }

  async touch(userId: string) {
    await this.prisma.user.update({ where: { id: userId }, data: { lastSeenAt: new Date() } }).catch(() => undefined);
  }
}
