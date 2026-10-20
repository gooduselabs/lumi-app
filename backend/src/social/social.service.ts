import { Injectable } from '@nestjs/common';
import { messageTtlMs } from '../chat/ttl';
import { Prisma } from '@prisma/client';
import { Errors } from '../common/errors';
import { orderedPair } from '../common/pair';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeEmitter } from '../realtime/realtime.emitter';
import { publicSelect, toPublic } from '../users/user.mapper';
import { ReportDto } from './dto/social.dto';

@Injectable()
export class SocialService {
  constructor(private readonly prisma: PrismaService, private readonly rt: RealtimeEmitter) {}

  // ----- blocks -----
  async isBlockedEither(a: string, b: string): Promise<boolean> {
    const n = await this.prisma.block.count({
      where: { OR: [{ blockerId: a, blockedId: b }, { blockerId: b, blockedId: a }] },
    });
    return n > 0;
  }

  async blockedIds(userId: string): Promise<Set<string>> {
    const rows = await this.prisma.block.findMany({
      where: { OR: [{ blockerId: userId }, { blockedId: userId }] },
      select: { blockerId: true, blockedId: true },
    });
    return new Set(rows.map((r) => (r.blockerId === userId ? r.blockedId : r.blockerId)));
  }

  async block(userId: string, targetId: string) {
    if (userId === targetId) throw Errors.badRequest('SELF', 'Cannot block yourself');
    const target = await this.prisma.user.findUnique({ where: { id: targetId }, select: { id: true } });
    if (!target) throw Errors.notFound('User');
    await this.prisma.block.upsert({
      where: { blockerId_blockedId: { blockerId: userId, blockedId: targetId } },
      create: { blockerId: userId, blockedId: targetId },
      update: {},
    });
    this.rt.toUser(targetId, 'friends:changed', {});
    this.rt.toUser(userId, 'friends:changed', {});
    return { ok: true };
  }

  async unblock(userId: string, targetId: string) {
    await this.prisma.block.deleteMany({ where: { blockerId: userId, blockedId: targetId } });
    this.rt.toUser(userId, 'friends:changed', {});
    return { ok: true };
  }

  async listBlocks(userId: string) {
    const rows = await this.prisma.block.findMany({
      where: { blockerId: userId },
      include: { blocked: { select: publicSelect } },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map((r) => ({ ...toPublic(r.blocked), blockedAt: r.createdAt }));
  }

  async report(userId: string, dto: ReportDto) {
    if (userId === dto.targetId) throw Errors.badRequest('SELF', 'Cannot report yourself');
    const target = await this.prisma.user.findUnique({ where: { id: dto.targetId }, select: { id: true } });
    if (!target) throw Errors.notFound('User');
    const r = await this.prisma.report.create({
      data: { reporterId: userId, targetId: dto.targetId, reason: dto.reason, details: dto.details, context: dto.context },
    });
    return { ok: true, id: r.id };
  }

  // ----- friends -----
  async areFriends(a: string, b: string) {
    const [x, y] = orderedPair(a, b);
    return this.prisma.friendship.findUnique({ where: { userAId_userBId: { userAId: x, userBId: y } } });
  }

  /** Idempotently creates friendship + its private conversation. */
  async makeFriends(a: string, b: string, systemText: string) {
    const [x, y] = orderedPair(a, b);
    try {
      return await this.prisma.$transaction(async (tx) => {
        const existing = await tx.friendship.findUnique({ where: { userAId_userBId: { userAId: x, userBId: y } } });
        if (existing) return { conversationId: existing.conversationId, created: false };
        const conv = await tx.conversation.create({
          data: { members: { create: [{ userId: x }, { userId: y }] }, lastMessageAt: new Date() },
        });
        await tx.friendship.create({ data: { userAId: x, userBId: y, conversationId: conv.id } });
        // One queued copy per member: each device stores it locally once delivered.
        const expiresAt = new Date(Date.now() + messageTtlMs());
        await tx.message.createMany({
          data: [x, y].map((recipientId) => ({ conversationId: conv.id, senderId: a, recipientId, expiresAt, type: 'SYSTEM' as const, body: systemText })),
        });
        return { conversationId: conv.id, created: true };
      });
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        const f = await this.areFriends(a, b);
        if (f) return { conversationId: f.conversationId, created: false };
      }
      throw e;
    }
  }

  async listFriends(userId: string) {
    const blocked = await this.blockedIds(userId);
    const rows = await this.prisma.friendship.findMany({
      where: { OR: [{ userAId: userId }, { userBId: userId }] },
      include: { userA: { select: publicSelect }, userB: { select: publicSelect } },
      orderBy: { createdAt: 'desc' },
    });
    return rows
      .map((f) => ({ friend: f.userAId === userId ? f.userB : f.userA, f }))
      .filter(({ friend }) => !blocked.has(friend.id))
      .map(({ friend, f }) => ({
        ...toPublic(friend),
        conversationId: f.conversationId,
        friendsSince: f.createdAt,
        online: this.rt.isOnline(friend.id),
      }));
  }

  async unfriend(userId: string, friendId: string) {
    const [x, y] = orderedPair(userId, friendId);
    const f = await this.prisma.friendship.findUnique({ where: { userAId_userBId: { userAId: x, userBId: y } } });
    if (!f) throw Errors.notFound('Friendship');
    // Deleting the conversation cascades its messages and the friendship row.
    await this.prisma.conversation.delete({ where: { id: f.conversationId } });
    this.rt.toUser(friendId, 'friends:changed', {});
    this.rt.toUser(userId, 'friends:changed', {});
    return { ok: true };
  }

  async friendIds(userId: string): Promise<string[]> {
    const rows = await this.prisma.friendship.findMany({
      where: { OR: [{ userAId: userId }, { userBId: userId }] },
      select: { userAId: true, userBId: true },
    });
    return rows.map((r) => (r.userAId === userId ? r.userBId : r.userAId));
  }
}
