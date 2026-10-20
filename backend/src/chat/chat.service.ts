import { Inject, Injectable, Logger } from '@nestjs/common';
import { Attachment, AttachmentKind, Message } from '@prisma/client';
import { randomUUID } from 'crypto';
import { APP_ENV, AppEnv } from '../config/env';
import { STORAGE, StorageDriver } from '../storage/storage.driver';
import { extFor, MAX_CAPTION, MAX_VOICE_MS, resolveMime, safeFileName, signAttachment, sniffImage, verifyAttachmentSig } from './media';
import { Errors } from '../common/errors';
import { PushService } from '../notifications/push.service';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeEmitter } from '../realtime/realtime.emitter';
import { SocialService } from '../social/social.service';
import { publicSelect, toPublic } from '../users/user.mapper';

export const MAX_MESSAGE_LENGTH = 2000;

export type Signer = (attachmentId: string) => string;

export const toAttachmentDto = (a: Attachment, sign?: Signer) => ({
  id: a.id,
  kind: a.kind,
  mimeType: a.mimeType,
  sizeBytes: a.sizeBytes,
  fileName: a.fileName,
  durationMs: a.durationMs,
  width: a.width,
  height: a.height,
  url: sign ? sign(a.id) : `/attachments/${a.id}`,
});

export const toMessageDto = (m: Message & { attachment?: Attachment | null }, sign?: Signer) => ({
  id: m.id,
  conversationId: m.conversationId,
  senderId: m.senderId,
  type: m.type,
  body: m.body,
  clientId: m.clientId,
  createdAt: m.createdAt,
  attachment: m.attachment ? toAttachmentDto(m.attachment, sign) : null,
});

export interface UploadedMedia {
  buffer: Buffer;
  size: number;
  mimetype?: string;
  originalname?: string;
}

/** Busboy decodes multipart filenames as latin1; recover UTF-8 names (e.g. Vietnamese). */
export function fixMulterName(name?: string): string | undefined {
  if (!name || !/[\u0080-\u00ff]/.test(name)) return name;
  const utf8 = Buffer.from(name, 'latin1').toString('utf8');
  return utf8.includes('\uFFFD') ? name : utf8;
}

export interface MediaMeta {
  kind: AttachmentKind;
  caption?: string;
  clientId?: string;
  durationMs?: number;
  width?: number;
  height?: number;
}

@Injectable()
export class ChatService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly social: SocialService,
    private readonly rt: RealtimeEmitter,
    private readonly push: PushService,
    @Inject(APP_ENV) private readonly env: AppEnv,
    @Inject(STORAGE) private readonly storage: StorageDriver,
  ) {}

  private readonly logger = new Logger(ChatService.name);

  /** Short-lived signed URL so image/audio widgets can load without auth headers. */
  readonly sign: Signer = (id) => {
    const ttl = this.env.storage.urlTtlSeconds;
    // Bucket expiry to the hour so URLs are cache-friendly across history reloads.
    const exp = (Math.floor(Date.now() / 1000 / 3600) + 1) * 3600 + ttl;
    return `/attachments/${id}?exp=${exp}&sig=${signAttachment(this.env.storage.urlSecret, id, exp)}`;
  };

  private dto(m: Message & { attachment?: Attachment | null }) {
    return toMessageDto(m, this.sign);
  }

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
            // Only messages still queued for me exist server-side.
            messages: { where: { recipientId: userId }, orderBy: { createdAt: 'desc' }, take: 1, include: { attachment: true } },
          },
        },
      },
    });
    const items = await Promise.all(
      memberships.map(async (m) => {
        const other = m.conversation.members.find((x) => x.userId !== userId);
        if (!other || blocked.has(other.userId)) return null;
        // Server-side unread = undelivered for me; devices add their own local unread count.
        const unread = await this.prisma.message.count({
          where: { conversationId: m.conversationId, recipientId: userId, type: { not: 'SYSTEM' } },
        });
        const last = m.conversation.messages[0];
        return {
          id: m.conversationId,
          peer: { ...toPublic(other.user), online: this.rt.isOnline(other.userId) },
          lastMessage: last ? this.dto(last) : null,
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

  /** Messages queued for this user's device (oldest first). The device must ack them. */
  async pending(userId: string, limit = 200) {
    const rows = await this.prisma.message.findMany({
      where: { recipientId: userId, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'asc' },
      take: Math.min(Math.max(limit, 1), 500),
      include: { attachment: true },
    });
    const total = await this.prisma.message.count({ where: { recipientId: userId, expiresAt: { gt: new Date() } } });
    return { items: rows.map((m) => this.dto(m)), hasMore: total > rows.length };
  }

  /**
   * Device confirms it stored these messages (and downloaded their attachments):
   * the server forgets them for good and tells the senders they were delivered.
   */
  async ack(userId: string, ids: string[]) {
    const unique = [...new Set((ids ?? []).filter((x) => typeof x === 'string'))].slice(0, 500);
    if (!unique.length) return { deleted: 0 };
    const rows = await this.prisma.message.findMany({
      where: { id: { in: unique }, recipientId: userId },
      include: { attachment: true },
    });
    if (!rows.length) return { deleted: 0 };
    await this.deleteMessages(rows);
    const deliveredAt = new Date();
    const bySender = new Map<string, { conversationId: string; ids: string[] }[]>();
    for (const r of rows) {
      if (r.type === 'SYSTEM' || r.senderId === userId) continue;
      const list = bySender.get(r.senderId) ?? [];
      const g = list.find((x) => x.conversationId === r.conversationId);
      if (g) g.ids.push(r.id);
      else list.push({ conversationId: r.conversationId, ids: [r.id] });
      bySender.set(r.senderId, list);
    }
    for (const [senderId, groups] of bySender) {
      for (const g of groups) this.rt.toUser(senderId, 'chat:delivered', { conversationId: g.conversationId, messageIds: g.ids, deliveredAt });
    }
    return { deleted: rows.length };
  }

  private async deleteMessages(rows: (Message & { attachment: Attachment | null })[]) {
    const atts = rows.map((r) => r.attachment).filter((a): a is Attachment => !!a);
    await this.prisma.$transaction([
      this.prisma.message.deleteMany({ where: { id: { in: rows.map((r) => r.id) } } }),
      this.prisma.attachment.deleteMany({ where: { id: { in: atts.map((a) => a.id) } } }),
    ]);
    await Promise.all(atts.map((a) => this.storage.delete(a.storageKey).catch((e) => this.logger.warn(`blob delete ${a.storageKey}: ${e}`))));
  }

  /** TTL job: drop undelivered messages (and orphaned uploads) past their expiry. */
  async purgeExpired(now = new Date()) {
    let total = 0;
    for (;;) {
      const rows = await this.prisma.message.findMany({ where: { expiresAt: { lte: now } }, include: { attachment: true }, take: 500 });
      if (!rows.length) break;
      await this.deleteMessages(rows);
      total += rows.length;
    }
    const orphanCutoff = new Date(now.getTime() - 24 * 3600 * 1000);
    const orphans = await this.prisma.attachment.findMany({ where: { message: null, createdAt: { lt: orphanCutoff } }, take: 1000 });
    if (orphans.length) {
      await this.prisma.attachment.deleteMany({ where: { id: { in: orphans.map((o) => o.id) } } });
      await Promise.all(orphans.map((a) => this.storage.delete(a.storageKey).catch(() => undefined)));
    }
    return { messages: total, orphans: orphans.length };
  }

  async send(userId: string, conversationId: string, body: string, clientId?: string) {
    const text = (body ?? '').trim();
    if (!text) throw Errors.badRequest('EMPTY_MESSAGE', 'Message is empty');
    if (text.length > MAX_MESSAGE_LENGTH) throw Errors.badRequest('MESSAGE_TOO_LONG', 'Message too long');
    const { other } = await this.canSend(userId, conversationId);
    if (clientId) {
      const dup = await this.findDup(conversationId, userId, clientId);
      if (dup) return dup;
    }
    return this.persist(userId, other.userId, conversationId, { body: text, clientId }, text.slice(0, 100));
  }

  private async canSend(userId: string, conversationId: string) {
    const { conv, other } = await this.membership(userId, conversationId);
    if (!conv.friendship) throw Errors.forbidden('Not friends');
    if (await this.social.isBlockedEither(userId, other.userId)) throw Errors.blocked();
    return { other };
  }

  private async findDup(conversationId: string, senderId: string, clientId: string) {
    const dup = await this.prisma.message.findFirst({ where: { conversationId, senderId, clientId }, include: { attachment: true } });
    return dup ? this.dto(dup) : null;
  }

  private async persist(
    userId: string,
    otherId: string,
    conversationId: string,
    d: { body: string; clientId?: string; type?: Message['type']; attachmentId?: string },
    preview: string,
  ) {
    const now = new Date();
    const [msg] = await this.prisma.$transaction([
      this.prisma.message.create({
        data: {
          conversationId,
          senderId: userId,
          recipientId: otherId,
          expiresAt: new Date(Date.now() + this.env.messageTtlDays * 86_400_000),
          body: d.body,
          type: d.type ?? 'TEXT',
          attachmentId: d.attachmentId,
          clientId: d.clientId?.slice(0, 64),
        },
        include: { attachment: true },
      }),
      this.prisma.conversation.update({ where: { id: conversationId }, data: { lastMessageAt: now } }),
      this.prisma.conversationMember.update({
        where: { conversationId_userId: { conversationId, userId } },
        data: { lastReadAt: now },
      }),
    ]);
    const dto = this.dto(msg);
    this.rt.toUser(otherId, 'chat:message', dto);
    this.rt.toUser(userId, 'chat:message', dto);
    if (!this.rt.isOnline(otherId)) {
      const sender = await this.prisma.user.findUnique({ where: { id: userId }, select: { nickname: true } });
      void this.push.notify(otherId, sender?.nickname ?? 'Lumi', preview, { conversationId });
    }
    return dto;
  }

  /** Validate + store an uploaded image / voice note / file and post it as a message. */
  async sendMedia(userId: string, conversationId: string, file: UploadedMedia | undefined, meta: MediaMeta) {
    if (!file?.buffer?.length) throw Errors.badRequest('FILE_REQUIRED', 'No file uploaded');
    const max = this.env.storage.maxUploadBytes;
    if (file.size > max || file.buffer.length > max) {
      throw Errors.badRequest('FILE_TOO_LARGE', `File exceeds ${Math.round(max / 1024 / 1024)} MB`);
    }
    const kind = meta.kind;
    const fallback = kind === 'VOICE' ? 'voice.m4a' : kind === 'IMAGE' ? 'image.jpg' : 'file';
    const fileName = safeFileName(fixMulterName(file.originalname), fallback);
    let mime = resolveMime(kind, file.mimetype, fileName);
    if (kind === 'IMAGE') {
      const sniffed = sniffImage(file.buffer);
      if (!sniffed) throw Errors.badRequest('UNSUPPORTED_FILE_TYPE', 'Not a supported image');
      mime = sniffed;
    }
    if (!mime) throw Errors.badRequest('UNSUPPORTED_FILE_TYPE', 'File type not allowed');
    if (kind === 'VOICE' && (!meta.durationMs || meta.durationMs > MAX_VOICE_MS)) {
      throw Errors.badRequest('INVALID_DURATION', 'Voice message duration missing or too long');
    }
    const caption = (meta.caption ?? '').trim();
    if (caption.length > MAX_CAPTION) throw Errors.badRequest('MESSAGE_TOO_LONG', 'Caption too long');

    const { other } = await this.canSend(userId, conversationId);
    if (meta.clientId) {
      const dup = await this.findDup(conversationId, userId, meta.clientId);
      if (dup) return dup;
    }
    const id = randomUUID();
    const storageKey = `conv/${conversationId}/${id}${extFor(mime, kind)}`;
    await this.storage.put(storageKey, file.buffer, mime);
    try {
      await this.prisma.attachment.create({
        data: {
          id,
          ownerId: userId,
          conversationId,
          kind,
          storageKey,
          mimeType: mime,
          sizeBytes: file.buffer.length,
          fileName,
          durationMs: kind === 'VOICE' ? meta.durationMs : null,
          width: kind === 'IMAGE' ? meta.width ?? null : null,
          height: kind === 'IMAGE' ? meta.height ?? null : null,
        },
      });
      const preview = kind === 'IMAGE' ? '📷' : kind === 'VOICE' ? '🎤' : `📎 ${fileName}`;
      return await this.persist(userId, other.userId, conversationId, { body: caption, clientId: meta.clientId, type: kind, attachmentId: id }, caption || preview);
    } catch (e) {
      await this.storage.delete(storageKey).catch((err) => this.logger.warn(`orphan cleanup failed: ${err}`));
      throw e;
    }
  }

  /**
   * Authorize a download: either a valid signed URL, or a member of the conversation.
   * Returns the stream + headers to send.
   */
  async openAttachment(id: string, auth: { userId?: string; exp?: number; sig?: string }) {
    const a = await this.prisma.attachment.findUnique({ where: { id } });
    if (!a) throw Errors.notFound('Attachment');
    const signed = auth.sig && auth.exp != null && verifyAttachmentSig(this.env.storage.urlSecret, id, auth.exp, auth.sig);
    if (!signed) {
      if (!auth.userId) throw Errors.unauthorized();
      const member = await this.prisma.conversationMember.findUnique({
        where: { conversationId_userId: { conversationId: a.conversationId, userId: auth.userId } },
      });
      if (!member) throw Errors.notFound('Attachment');
    }
    const { stream } = await this.storage.get(a.storageKey);
    return { attachment: a, stream };
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
