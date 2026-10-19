import { Injectable } from '@nestjs/common';
import { Errors } from '../common/errors';
import { PrismaService } from '../prisma/prisma.service';
import { SocialService } from '../social/social.service';
import { publicSelect, toPublic } from '../users/user.mapper';

@Injectable()
export class FeedService {
  constructor(private readonly prisma: PrismaService, private readonly social: SocialService) {}

  async list(userId: string, before?: string, limit = 20) {
    const blocked = [...(await this.social.blockedIds(userId))];
    const rows = await this.prisma.post.findMany({
      where: { authorId: { notIn: blocked }, ...(before ? { createdAt: { lt: new Date(before) } } : {}) },
      include: {
        author: { select: publicSelect },
        _count: { select: { likes: true } },
        likes: { where: { userId }, select: { userId: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
    return {
      items: rows.map((p) => ({
        id: p.id,
        body: p.body,
        createdAt: p.createdAt,
        author: toPublic(p.author),
        likeCount: p._count.likes,
        likedByMe: p.likes.length > 0,
        mine: p.authorId === userId,
      })),
      hasMore: rows.length === limit,
    };
  }

  async create(userId: string, body: string) {
    const u = await this.prisma.user.findUnique({ where: { id: userId }, select: { onboardedAt: true } });
    if (!u?.onboardedAt) throw Errors.notOnboarded();
    const p = await this.prisma.post.create({ data: { authorId: userId, body }, include: { author: { select: publicSelect } } });
    return { id: p.id, body: p.body, createdAt: p.createdAt, author: toPublic(p.author), likeCount: 0, likedByMe: false, mine: true };
  }

  async remove(userId: string, postId: string) {
    const res = await this.prisma.post.deleteMany({ where: { id: postId, authorId: userId } });
    if (!res.count) throw Errors.notFound('Post');
    return { ok: true };
  }

  async like(userId: string, postId: string, like: boolean) {
    const post = await this.prisma.post.findUnique({ where: { id: postId }, select: { id: true } });
    if (!post) throw Errors.notFound('Post');
    if (like) {
      await this.prisma.postLike.upsert({
        where: { postId_userId: { postId, userId } },
        create: { postId, userId },
        update: {},
      });
    } else {
      await this.prisma.postLike.deleteMany({ where: { postId, userId } });
    }
    const likeCount = await this.prisma.postLike.count({ where: { postId } });
    return { ok: true, likeCount, likedByMe: like };
  }
}
