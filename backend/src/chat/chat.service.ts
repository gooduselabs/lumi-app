import { Injectable } from '@nestjs/common';
import { Message } from '@prisma/client';
import { Errors } from '../common/errors';
import { PushService } from '../notifications/push.service';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeEmitter } from '../realtime/realtime.emitter';
import { SocialService } from '../social/social.service';
import { publicSelect, toPublic } from '../users/user.mapper';

export const MAX_MESSAGE_LENGTH = 2000;

export const toMessageDto = (m: Message) => ({
  id: m.id,
  conversationId: m.conversationId,
  senderId: m.senderId,
  type: m.type,
  body: m.body,
  clientId: m.clientId,
  createdAt: m.createdAt,
});

@Injectable()
export class ChatService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly social: SocialService,
    private readonly rt: RealtimeEmitter,
    private readonly push: PushService,
  ) {}

  private async membership(userId: string, conversationId: string) {
    const conv = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: { members: true, friendship: true },
    });
    if (!conv || !conv.members.some((m) => m.userId === userId)) throw Errors.notFound('Conversation');
    const other = conv.members.find((m) => m.userId !== userId)!;
    return { conv, me: conv.members.find((m) => m.userId === userId)!, other };
  }

  async listConversations(userId: string) {
    const blocked = await this.social.blockedIds(userId);
    const memberships = await this.prisma.conversationMember.findMany({
      where: { userId, conversation: { friendship: { isNot: null } } },
      include: {
        conversation: {
          include: {
            members: { include: { user: { select: publicSelect } } },
            messages: { orderBy: { createdAt: 'desc' }, take: 1 },
          },
        },
      },
    });
    const items = await Promise.all(
      memberships.map(async (m) => {
        const other = m.conversation.members.find((x) => x.userId !== userId);
        if (!other || blocked.has(other.userId)) return null;
        const unread = await this.prisma.message.count({
          where: {
            conversationId: m.conversationId,
            senderId: { not: userId },
            ...(m.lastReadAt ? { createdAt: { gt: m.lastReadAt } } : {}),
          },
        });
        const last = m.conversation.messages[0];
        return {
          id: m.conversationId,
          peer: { ...toPublic(other.user), online: this.rt.isOnline(other.userId) },
          lastMessage: last ? toMessageDto(last) : null,
          unread,
          peerLastReadAt: other.lastReadAt,
          updatedAt: m.conversation.lastMessageAt ?? m.conversation.createdAt,
        };
      }),
    );
    return items
      .filter((x): x is NonNullable<typeof x> => !!x)
      .sort((a, b) => +new Date(b.updatedAt) - +new Date(a.updatedAt));
  }

  async conversation(userId: string, conversationId: string) {
    const { other } = await this.membership(userId, conversationId);
    const peer = await this.prisma.user.findUniqueOrThrow({ where: { id: other.userId }, select: publicSelect });
    return {
      id: conversationId,
      peer: { ...toPublic(peer), online: this.rt.isOnline(peer.id) },
      peerLastReadAt: other.lastReadAt,
      blocked: await this.social.isBlockedEither(userId, other.userId),
    };
  }

  async history(userId: string, conversationId: string, before?: string, limit = 30) {
    await this.membership(userId, conversationId);
    const rows = await this.prisma.message.findMany({
      where: { conversationId, ...(before ? { createdAt: { lt: new Date(before) } } : {}) },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
    return { items: rows.map(toMessageDto), hasMore: rows.length === limit };
  }

  async send(userId: string, conversationId: string, body: string, clientId?: string) {
    const text = (body ?? '').trim();
    if (!text) throw Errors.badRequest('EMPTY_MESSAGE', 'Message is empty');
    if (text.length > MAX_MESSAGE_LENGTH) throw Errors.badRequest('MESSAGE_TOO_LONG', 'Message too long');
    const { conv, other } = await this.membership(userId, conversationId);
    if (!conv.friendship) throw Errors.forbidden('Not friends');
    if (await this.social.isBlockedEither(userId, other.userId)) throw Errors.blocked();

    if (clientId) {
      const dup = await this.prisma.message.findFirst({ where: { conversationId, senderId: userId, clientId } });
      if (dup) return toMessageDto(dup);
    }
    const now = new Date();
    const [msg] = await this.prisma.$transaction([
      this.prisma.message.create({ data: { conversationId, senderId: userId, body: text, clientId: clientId?.slice(0, 64) } }),
      this.prisma.conversation.update({ where: { id: conversationId }, data: { lastMessageAt: now } }),
      this.prisma.conversationMember.update({
        where: { conversationId_userId: { conversationId, userId } },
        data: { lastReadAt: now },
      }),
    ]);
    const dto = toMessageDto(msg);
    this.rt.toUser(other.userId, 'chat:message', dto);
    this.rt.toUser(userId, 'chat:message', dto);
    if (!this.rt.isOnline(other.userId)) {
      const sender = await this.prisma.user.findUnique({ where: { id: userId }, select: { nickname: true } });
      void this.push.notify(other.userId, sender?.nickname ?? 'Lumi', text.slice(0, 100), { conversationId });
    }
    return dto;
  }

  async markRead(userId: string, conversationId: string) {
    const { other } = await this.membership(userId, conversationId);
    const readAt = new Date();
    await this.prisma.conversationMember.update({
      where: { conversationId_userId: { conversationId, userId } },
      data: { lastReadAt: readAt },
    });
    this.rt.toUser(other.userId, 'chat:read', { conversationId, userId, readAt });
    return { ok: true, readAt };
  }

  async typing(userId: string, conversationId: string, isTyping: boolean) {
    const { other } = await this.membership(userId, conversationId);
    this.rt.toUser(other.userId, 'chat:typing', { conversationId, userId, isTyping: !!isTyping });
    return { ok: true };
  }
}
