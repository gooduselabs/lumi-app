import { Inject, Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import Redis from 'ioredis';
import { Errors } from '../common/errors';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeEmitter } from '../realtime/realtime.emitter';
import { REDIS } from '../redis/redis.module';
import { SocialService } from '../social/social.service';
import { publicSelect, toPublic } from '../users/user.mapper';
import { LivekitService } from './livekit.service';

export const RING_SECONDS = 45;
const CALL_MAX_SECONDS = 2 * 3600;

interface CallState {
  id: string;
  conversationId: string;
  callerId: string;
  calleeId: string;
  status: 'RINGING' | 'ACTIVE';
  createdAt: number;
}

const K = { call: (id: string) => `call:${id}`, busy: (uid: string) => `call:user:${uid}` };

/** 1-1 friend voice calls: signalling over Socket.IO, media over LiveKit. */
@Injectable()
export class CallsService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: Redis,
    private readonly rt: RealtimeEmitter,
    private readonly social: SocialService,
    private readonly livekit: LivekitService,
  ) {}

  private room(id: string) {
    return `call_${id}`;
  }

  private async joinInfo(call: CallState, userId: string) {
    const me = await this.prisma.user.findUnique({ where: { id: userId }, select: { nickname: true } });
    return {
      url: this.livekit.url!,
      room: this.room(call.id),
      token: await this.livekit.token(userId, this.room(call.id), me?.nickname ?? 'Lumi', CALL_MAX_SECONDS),
    };
  }

  private async load(id: string, userId: string): Promise<CallState> {
    const raw = await this.redis.get(K.call(id));
    const c: CallState | null = raw ? JSON.parse(raw) : null;
    if (!c || (c.callerId !== userId && c.calleeId !== userId)) throw Errors.notFound('Call');
    return c;
  }

  async start(userId: string, conversationId: string) {
    if (!this.livekit.enabled) throw Errors.voiceUnavailable();
    const conv = await this.prisma.conversation.findUnique({ where: { id: conversationId }, include: { members: true, friendship: true } });
    if (!conv || !conv.members.some((m) => m.userId === userId)) throw Errors.notFound('Conversation');
    if (!conv.friendship) throw Errors.forbidden('Not friends');
    const calleeId = conv.members.find((m) => m.userId !== userId)!.userId;
    if (await this.social.isBlockedEither(userId, calleeId)) throw Errors.blocked();
    if (await this.redis.get(K.busy(userId))) throw Errors.inSession();
    if (await this.redis.get(K.busy(calleeId))) throw Errors.badRequest('PEER_BUSY', 'Your friend is in another call');

    const call: CallState = { id: randomUUID(), conversationId, callerId: userId, calleeId, status: 'RINGING', createdAt: Date.now() };
    const ok = await this.redis.set(K.busy(userId), call.id, 'EX', RING_SECONDS, 'NX');
    if (!ok) throw Errors.inSession();
    await this.redis.multi().set(K.busy(calleeId), call.id, 'EX', RING_SECONDS).set(K.call(call.id), JSON.stringify(call), 'EX', RING_SECONDS).exec();

    const caller = await this.prisma.user.findUniqueOrThrow({ where: { id: userId }, select: publicSelect });
    this.rt.toUser(calleeId, 'call:incoming', { callId: call.id, conversationId, from: toPublic(caller), ringSeconds: RING_SECONDS });
    return { callId: call.id, conversationId, status: call.status, ringSeconds: RING_SECONDS, voice: await this.joinInfo(call, userId) };
  }

  async accept(userId: string, callId: string) {
    const call = await this.load(callId, userId);
    if (call.calleeId !== userId) throw Errors.forbidden('Only the callee can accept');
    if (call.status !== 'RINGING') throw Errors.sessionClosed();
    call.status = 'ACTIVE';
    await this.redis
      .multi()
      .set(K.call(callId), JSON.stringify(call), 'EX', CALL_MAX_SECONDS)
      .set(K.busy(call.callerId), callId, 'EX', CALL_MAX_SECONDS)
      .set(K.busy(call.calleeId), callId, 'EX', CALL_MAX_SECONDS)
      .exec();
    this.rt.toUser(call.callerId, 'call:accepted', { callId });
    return { callId, conversationId: call.conversationId, status: call.status, voice: await this.joinInfo(call, userId) };
  }

  /** Decline (callee), cancel (caller while ringing) or hang up (either). */
  async end(userId: string, callId: string, reason: 'DECLINED' | 'ENDED' = 'ENDED') {
    const call = await this.load(callId, userId);
    await this.redis.del(K.call(callId), K.busy(call.callerId), K.busy(call.calleeId));
    const r = call.status !== 'RINGING' ? 'ENDED' : userId === call.calleeId || reason === 'DECLINED' ? 'DECLINED' : 'CANCELLED';
    for (const uid of [call.callerId, call.calleeId]) this.rt.toUser(uid, 'call:ended', { callId, reason: r, byMe: uid === userId });
    return { ok: true, reason: r };
  }
}
