import { Injectable } from '@nestjs/common';
import { isAdult } from '../common/age';
import { Errors } from '../common/errors';
import { PrismaService } from '../prisma/prisma.service';
import { OnboardingDto, UpdateProfileDto } from './dto/profile.dto';
import { publicSelect, toMe, toPublic } from './user.mapper';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

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
    const u = await this.prisma.user.update({
      where: { id: userId },
      data: { ...dto, interests: dto.interests ? [...new Set(dto.interests)] : undefined },
    });
    return toMe(u);
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
