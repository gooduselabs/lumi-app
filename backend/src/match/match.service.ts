import { Inject, Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { MatchMode, MatchSession } from '@prisma/client';
import { randomUUID } from 'crypto';
import Redis from 'ioredis';
import { APP_ENV, AppEnv } from '../config/env';
import { Errors } from '../common/errors';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeEmitter } from '../realtime/realtime.emitter';
import { REDIS } from '../redis/redis.module';
import { SocialService } from '../social/social.service';
import { publicSelect, toPublic } from '../users/user.mapper';
import { LivekitService } from '../voice/livekit.service';
import { commonInterests, compatible, GenderPref, QueueEntry } from './match.logic';

const K = {
  queue: (mode: MatchMode) => `mq:${mode}`,
  entry: (userId: string) => `mq:entry:${userId}`,
  lock: (mode: MatchMode) => `mq:lock:${mode}`,
  active: (userId: string) => `ms:user:${userId}`,
  recent: (userId: string) => `mrecent:${userId}`,
};

const RELEASE_LOCK = `if redis.call("get", KEYS[1]) == ARGV[1] then return redis.call("del", KEYS[1]) else return 0 end`;
const MAX_SOUL_MESSAGE = 500;
const DISCONNECT_GRACE_MS = 8000;

export type EndReason = 'TIMEOUT' | 'SKIPPED' | 'PARTNER_LEFT' | 'BLOCKED' | 'SERVER_RESTART';

@Injectable()
export class MatchService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(MatchService.name);
  private readonly timers = new Map<string, NodeJS.Timeout>();

  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: Redis,
    @Inject(APP_ENV) private readonly env: AppEnv,
    private readonly rt: RealtimeEmitter,
    private readonly social: SocialService,
    private readonly livekit: LivekitService,
  ) {}

  async onModuleInit() {
    // Timers live in memory: sessions left ACTIVE by a previous process are closed on boot.
    const res = await this.prisma.matchSession.updateMany({
      where: { status: 'ACTIVE' },
      data: { status: 'ENDED', endedAt: new Date(), endReason: 'SERVER_RESTART' },
    });
    if (res.count) this.logger.log(`Closed ${res.count} stale match sessions`);
  }

  onModuleDestroy() {
    this.timers.forEach((t) => clearTimeout(t));
    this.timers.clear();
  }

  durationFor(mode: MatchMode) {
    return mode === 'VOICE' ? this.env.voiceMatchSeconds : this.env.soulMatchSeconds;
  }

  // ---------------- queue ----------------

  async join(userId: string, mode: MatchMode, pref: GenderPref = 'ANY') {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw Errors.unauthorized();
    if (!user.onboardedAt) throw Errors.notOnboarded();
    if (mode === 'VOICE' && !this.livekit.enabled) throw Errors.voiceUnavailable();
    if (await this.activeSessionRow(userId)) throw Errors.inSession();

    await this.leave(userId);
    const blocked = await this.social.blockedIds(userId);
    const recent = await this.redis.get(K.recent(userId));
    const me: QueueEntry = { userId, mode, gender: user.gender, pref, at: Date.now() };

    const partnerId = await this.withLock(mode, async () => {
      const candidates = await this.redis.lrange(K.queue(mode), 0, 199);
      for (const c of candidates) {
        if (c === userId || blocked.has(c) || c === recent) continue;
        const raw = await this.redis.get(K.entry(c));
        const entry: QueueEntry | null = raw ? JSON.parse(raw) : null;
        if (!entry || entry.mode !== mode || !this.rt.isOnline(c)) {
          await this.redis.lrem(K.queue(mode), 0, c);
          if (entry && !this.rt.isOnline(c)) await this.redis.del(K.entry(c));
          continue;
        }
        if (!compatible(me, entry)) continue;
        await this.redis.multi().lrem(K.queue(mode), 0, c).del(K.entry(c)).exec();
        return c;
      }
      await this.redis.multi().rpush(K.queue(mode), userId).set(K.entry(userId), JSON.stringify(me), 'EX', 600).exec();
      return null;
    });

    if (!partnerId) {
      const waiting = await this.redis.llen(K.queue(mode));
      return { status: 'waiting' as const, mode, waiting };
    }
    const session = await this.createSession(mode, partnerId, userId);
    return { status: 'matched' as const, mode, session: await this.payloadFor(session, userId) };
  }

  async leave(userId: string) {
    const raw = await this.redis.get(K.entry(userId));
    const modes: MatchMode[] = raw ? [JSON.parse(raw).mode] : ['SOUL', 'VOICE'];
    const m = this.redis.multi();
    for (const mode of modes) m.lrem(K.queue(mode), 0, userId);
    await m.del(K.entry(userId)).exec();
    return { ok: true };
  }

  async stats() {
    const [soul, voice] = await Promise.all([this.redis.llen(K.queue('SOUL')), this.redis.llen(K.queue('VOICE'))]);
    return { online: this.rt.onlineCount(), waiting: { SOUL: soul, VOICE: voice }, voiceEnabled: this.livekit.enabled };
  }

  // ---------------- sessions ----------------

  private async createSession(mode: MatchMode, aId: string, bId: string) {
    const seconds = this.durationFor(mode);
    const session = await this.prisma.matchSession.create({
      data: { mode, userAId: aId, userBId: bId, endsAt: new Date(Date.now() + seconds * 1000) },
    });
    await this.redis
      .multi()
      .set(K.active(aId), session.id, 'EX', seconds + 60)
      .set(K.active(bId), session.id, 'EX', seconds + 60)
      .set(K.recent(aId), bId, 'EX', 120)
      .set(K.recent(bId), aId, 'EX', 120)
      .exec();
    this.timers.set(
      session.id,
      setTimeout(() => void this.end(session.id, 'TIMEOUT').catch((e) => this.logger.error(e)), seconds * 1000),
    );
    // Notify the user that was waiting; the joiner receives the payload in the ack AND as an event.
    for (const uid of [aId, bId]) this.rt.toUser(uid, 'match:found', await this.payloadFor(session, uid));
    return session;
  }

  async payloadFor(session: MatchSession, viewerId: string) {
    const partnerId = session.userAId === viewerId ? session.userBId : session.userAId;
    const [me, partner] = await Promise.all([
      this.prisma.user.findUniqueOrThrow({ where: { id: viewerId }, select: { interests: true, nickname: true } }),
      this.prisma.user.findUniqueOrThrow({ where: { id: partnerId }, select: publicSelect }),
    ]);
    const p = toPublic(partner);
    const iLiked = session.userAId === viewerId ? session.likedByA : session.likedByB;
    const voice =
      session.mode === 'VOICE' && this.livekit.enabled
        ? {
            url: this.livekit.url!,
            room: `voice_${session.id}`,
            token: await this.livekit.token(viewerId, `voice_${session.id}`, me.nickname ?? 'Lumi', this.durationFor('VOICE') + 120),
          }
        : null;
    return {
      sessionId: session.id,
      mode: session.mode,
      startedAt: session.startedAt,
      endsAt: session.endsAt,
      serverNow: new Date(),
      durationSec: this.durationFor(session.mode),
      iLiked,
      // Anonymous: no nickname / id until mutual like.
      partner: {
        avatarId: p.avatarId,
        gender: p.gender,
        age: p.age,
        interests: p.interests,
        commonInterests: commonInterests(me.interests, p.interests),
        bio: p.bio,
      },
      voice,
    };
  }

  private async activeSessionRow(userId: string) {
    const sid = await this.redis.get(K.active(userId));
    if (!sid) return null;
    const s = await this.prisma.matchSession.findUnique({ where: { id: sid } });
    if (!s || s.status !== 'ACTIVE' || s.endsAt.getTime() < Date.now() - 2000) {
      await this.redis.del(K.active(userId));
      return null;
    }
    return s;
  }

  async activeSession(userId: string) {
    const s = await this.activeSessionRow(userId);
    return s ? this.payloadFor(s, userId) : null;
  }

  private async requireSession(userId: string, sessionId: string) {
    const s = await this.prisma.matchSession.findUnique({ where: { id: sessionId } });
    if (!s || (s.userAId !== userId && s.userBId !== userId)) throw Errors.notFound('Session');
    if (s.status !== 'ACTIVE' || s.endsAt.getTime() < Date.now() - 1500) throw Errors.sessionClosed();
    return { s, partnerId: s.userAId === userId ? s.userBId : s.userAId, isA: s.userAId === userId };
  }

  async like(userId: string, sessionId: string) {
    const { s, partnerId, isA } = await this.requireSession(userId, sessionId);
    const updated = await this.prisma.matchSession.update({
      where: { id: s.id },
      data: isA ? { likedByA: true } : { likedByB: true },
    });
    if (!(updated.likedByA && updated.likedByB)) {
      this.rt.toUser(partnerId, 'match:liked', { sessionId });
      return { ok: true, mutual: false };
    }
    const claimed = await this.prisma.matchSession.updateMany({
      where: { id: s.id, status: 'ACTIVE' },
      data: { status: 'MUTUAL', endedAt: new Date(), endReason: 'MUTUAL' },
    });
    if (claimed.count === 0) return { ok: true, mutual: true };
    this.clearSession(s);
    const { conversationId } = await this.social.makeFriends(s.userAId, s.userBId, 'MATCHED_SOUL');
    const users = await this.prisma.user.findMany({ where: { id: { in: [s.userAId, s.userBId] } }, select: publicSelect });
    for (const viewer of [s.userAId, s.userBId]) {
      const friend = users.find((u) => u.id !== viewer)!;
      this.rt.toUser(viewer, 'match:mutual', { sessionId, conversationId, friend: toPublic(friend) });
    }
    return { ok: true, mutual: true, conversationId };
  }

  async skip(userId: string, sessionId: string) {
    await this.requireSession(userId, sessionId);
    await this.end(sessionId, 'SKIPPED', userId);
    return { ok: true };
  }

  async end(sessionId: string, reason: EndReason, byUserId?: string) {
    const claimed = await this.prisma.matchSession.updateMany({
      where: { id: sessionId, status: 'ACTIVE' },
      data: { status: 'ENDED', endedAt: new Date(), endReason: reason },
    });
    if (claimed.count === 0) return;
    const s = await this.prisma.matchSession.findUniqueOrThrow({ where: { id: sessionId } });
    this.clearSession(s);
    for (const uid of [s.userAId, s.userBId]) {
      this.rt.toUser(uid, 'match:ended', { sessionId, reason, byMe: uid === byUserId });
    }
  }

  private clearSession(s: MatchSession) {
    const t = this.timers.get(s.id);
    if (t) clearTimeout(t);
    this.timers.delete(s.id);
    void this.redis.del(K.active(s.userAId), K.active(s.userBId));
  }

  async soulMessage(userId: string, sessionId: string, text: string, clientId?: string) {
    const body = (text ?? '').trim();
    if (!body) throw Errors.badRequest('EMPTY_MESSAGE', 'Message is empty');
    if (body.length > MAX_SOUL_MESSAGE) throw Errors.badRequest('MESSAGE_TOO_LONG', 'Message too long');
    const { partnerId } = await this.requireSession(userId, sessionId);
    // Ephemeral by design: anonymous session messages are relayed, never stored.
    const msg = { id: randomUUID(), sessionId, text: body, clientId: clientId?.slice(0, 64), at: new Date() };
    this.rt.toUser(partnerId, 'soul:message', msg);
    return msg;
  }

  async soulTyping(userId: string, sessionId: string) {
    const { partnerId } = await this.requireSession(userId, sessionId);
    this.rt.toUser(partnerId, 'soul:typing', { sessionId });
    return { ok: true };
  }

  /** Called when a user's last socket disconnects. */
  async onOffline(userId: string) {
    await this.leave(userId);
    setTimeout(() => {
      if (this.rt.isOnline(userId)) return;
      void this.activeSessionRow(userId)
        .then((s) => (s ? this.end(s.id, 'PARTNER_LEFT', userId) : undefined))
        .catch((e) => this.logger.error(e));
    }, DISCONNECT_GRACE_MS).unref();
  }

  async endIfPartner(userId: string, otherId: string) {
    const s = await this.activeSessionRow(userId);
    if (s && (s.userAId === otherId || s.userBId === otherId)) await this.end(s.id, 'BLOCKED', userId);
  }

  /** Report / block the anonymous partner of a session (their id is never sent to the client). */
  async partnerOf(userId: string, sessionId: string) {
    const s = await this.prisma.matchSession.findUnique({ where: { id: sessionId } });
    if (!s || (s.userAId !== userId && s.userBId !== userId)) throw Errors.notFound('Session');
    return s.userAId === userId ? s.userBId : s.userAId;
  }

  async blockPartner(userId: string, sessionId: string) {
    const partnerId = await this.partnerOf(userId, sessionId);
    await this.social.block(userId, partnerId);
    await this.end(sessionId, 'BLOCKED', userId);
    return { ok: true };
  }

  // ---------------- lock ----------------

  private async withLock<T>(mode: MatchMode, fn: () => Promise<T>): Promise<T> {
    const key = K.lock(mode);
    const token = randomUUID();
    for (let i = 0; i < 100; i++) {
      if (await this.redis.set(key, token, 'PX', 5000, 'NX')) {
        try {
          return await fn();
        } finally {
          await this.redis.eval(RELEASE_LOCK, 1, key, token);
        }
      }
      await new Promise((r) => setTimeout(r, 15 + Math.random() * 25));
    }
    throw new Error('Matchmaking busy, try again');
  }
}
