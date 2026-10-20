import { HttpException, Logger } from '@nestjs/common';
import {
  ConnectedSocket, MessageBody, OnGatewayConnection, OnGatewayDisconnect, OnGatewayInit,
  SubscribeMessage, WebSocketGateway,
} from '@nestjs/websockets';
import { MatchMode } from '@prisma/client';
import type { Server, Socket } from 'socket.io';
import { AuthService } from '../auth/auth.service';
import { ChatService } from '../chat/chat.service';
import { GamesService } from '../games/games.service';
import { MatchService } from '../match/match.service';
import { GenderPref } from '../match/match.logic';
import { SocialService } from '../social/social.service';
import { UsersService } from '../users/users.service';
import { RealtimeEmitter, userRoom } from './realtime.emitter';

type Ack<T = unknown> = { ok: true; data: T } | { ok: false; code: string; message: string };

/** Simple per-socket rate limiter: `limit` events per `windowMs`. */
class Bucket {
  private hits: number[] = [];
  constructor(private readonly limit: number, private readonly windowMs: number) {}
  take(): boolean {
    const now = Date.now();
    this.hits = this.hits.filter((t) => now - t < this.windowMs);
    if (this.hits.length >= this.limit) return false;
    this.hits.push(now);
    return true;
  }
}

@WebSocketGateway({ cors: { origin: true, credentials: true }, pingInterval: 20000, pingTimeout: 20000 })
export class RealtimeGateway implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect {
  private readonly logger = new Logger(RealtimeGateway.name);

  constructor(
    private readonly rt: RealtimeEmitter,
    private readonly auth: AuthService,
    private readonly match: MatchService,
    private readonly chat: ChatService,
    private readonly social: SocialService,
    private readonly users: UsersService,
    private readonly games: GamesService,
  ) {}

  afterInit(server: Server) {
    this.rt.attach(server);
  }

  async handleConnection(socket: Socket) {
    try {
      const raw = (socket.handshake.auth?.token as string | undefined) ?? (socket.handshake.query?.token as string | undefined);
      const token = raw?.replace(/^Bearer /, '');
      if (!token) throw new Error('missing token');
      const { id } = await this.auth.verifyAccessToken(token);
      socket.data.userId = id;
      socket.data.bucket = new Bucket(20, 5000);
      // Drawing streams many small stroke batches.
      socket.data.drawBucket = new Bucket(120, 5000);
      const wasOnline = this.rt.isOnline(id);
      await socket.join(userRoom(id));
      socket.emit('ready', { userId: id });
      // Store-and-forward: hand the device whatever was queued while it was offline.
      void this.chat
        .pending(id)
        .then((p) => p.items.length && socket.emit('chat:pending', p))
        .catch((e) => this.logger.error(e));
      this.games.onOnline(id);
      if (!wasOnline) void this.broadcastPresence(id, true);
    } catch {
      socket.emit('auth_error', { code: 'UNAUTHORIZED' });
      socket.disconnect(true);
    }
  }

  async handleDisconnect(socket: Socket) {
    const id: string | undefined = socket.data.userId;
    if (!id || this.rt.isOnline(id)) return;
    void this.users.touch(id);
    this.games.onOffline(id);
    void this.broadcastPresence(id, false);
    await this.match.onOffline(id).catch((e) => this.logger.error(e));
  }

  private async broadcastPresence(userId: string, online: boolean) {
    const friends = await this.social.friendIds(userId).catch(() => []);
    for (const f of friends) this.rt.toUser(f, 'presence:update', { userId, online, at: new Date() });
  }

  private async run<T>(socket: Socket, fn: (userId: string) => Promise<T> | T, bucket = 'bucket'): Promise<Ack<T>> {
    const userId: string | undefined = socket.data.userId;
    if (!userId) return { ok: false, code: 'UNAUTHORIZED', message: 'Unauthorized' };
    if (!(socket.data[bucket] as Bucket).take()) return { ok: false, code: 'RATE_LIMITED', message: 'Slow down' };
    try {
      return { ok: true, data: await fn(userId) };
    } catch (e) {
      if (e instanceof HttpException) {
        const r = e.getResponse() as { code?: string; message?: string };
        return { ok: false, code: r.code ?? 'ERROR', message: r.message ?? e.message };
      }
      this.logger.error(e);
      return { ok: false, code: 'INTERNAL', message: 'Something went wrong' };
    }
  }

  // ---------- matching ----------
  @SubscribeMessage('match:join')
  join(@ConnectedSocket() s: Socket, @MessageBody() b: { mode?: MatchMode; gender?: GenderPref; preferNearby?: boolean }) {
    const mode: MatchMode = b?.mode === 'VOICE' ? 'VOICE' : 'SOUL';
    const pref: GenderPref = b?.gender === 'MALE' || b?.gender === 'FEMALE' ? b.gender : 'ANY';
    return this.run(s, (uid) => this.match.join(uid, mode, pref, { preferNearby: b?.preferNearby === true }));
  }

  @SubscribeMessage('match:leave')
  leave(@ConnectedSocket() s: Socket) {
    return this.run(s, (uid) => this.match.leave(uid));
  }

  @SubscribeMessage('match:like')
  like(@ConnectedSocket() s: Socket, @MessageBody() b: { sessionId: string }) {
    return this.run(s, (uid) => this.match.like(uid, String(b?.sessionId)));
  }

  @SubscribeMessage('match:skip')
  skip(@ConnectedSocket() s: Socket, @MessageBody() b: { sessionId: string }) {
    return this.run(s, (uid) => this.match.skip(uid, String(b?.sessionId)));
  }

  @SubscribeMessage('soul:message')
  soulMessage(@ConnectedSocket() s: Socket, @MessageBody() b: { sessionId: string; text: string; clientId?: string }) {
    return this.run(s, (uid) => this.match.soulMessage(uid, String(b?.sessionId), String(b?.text ?? ''), b?.clientId));
  }

  @SubscribeMessage('soul:typing')
  soulTyping(@ConnectedSocket() s: Socket, @MessageBody() b: { sessionId: string }) {
    return this.run(s, (uid) => this.match.soulTyping(uid, String(b?.sessionId)));
  }

  // ---------- 1-1 chat ----------
  @SubscribeMessage('chat:send')
  chatSend(@ConnectedSocket() s: Socket, @MessageBody() b: { conversationId: string; body: string; clientId?: string }) {
    return this.run(s, (uid) => this.chat.send(uid, String(b?.conversationId), String(b?.body ?? ''), b?.clientId));
  }

  @SubscribeMessage('chat:typing')
  chatTyping(@ConnectedSocket() s: Socket, @MessageBody() b: { conversationId: string; isTyping: boolean }) {
    return this.run(s, (uid) => this.chat.typing(uid, String(b?.conversationId), !!b?.isTyping));
  }

  @SubscribeMessage('chat:ack')
  chatAck(@ConnectedSocket() s: Socket, @MessageBody() b: { ids?: string[] }) {
    return this.run(s, (uid) => this.chat.ack(uid, Array.isArray(b?.ids) ? b.ids.map(String) : []));
  }

  @SubscribeMessage('chat:pending')
  chatPending(@ConnectedSocket() s: Socket) {
    return this.run(s, (uid) => this.chat.pending(uid));
  }

  @SubscribeMessage('chat:read')
  chatRead(@ConnectedSocket() s: Socket, @MessageBody() b: { conversationId: string }) {
    return this.run(s, (uid) => this.chat.markRead(uid, String(b?.conversationId)));
  }

  // ---------- couple mini-games ----------
  @SubscribeMessage('game:invite')
  gameInvite(@ConnectedSocket() s: Socket, @MessageBody() b: { conversationId: string; kind: string }) {
    return this.run(s, (uid) => this.games.invite(uid, String(b?.conversationId), String(b?.kind)));
  }

  @SubscribeMessage('game:cancel')
  gameCancel(@ConnectedSocket() s: Socket, @MessageBody() b: { inviteId: string }) {
    return this.run(s, (uid) => this.games.cancelInvite(uid, String(b?.inviteId)));
  }

  @SubscribeMessage('game:respond')
  gameRespond(@ConnectedSocket() s: Socket, @MessageBody() b: { inviteId: string; accept: boolean }) {
    return this.run(s, (uid) => this.games.respond(uid, String(b?.inviteId), b?.accept === true));
  }

  @SubscribeMessage('game:action')
  gameAction(@ConnectedSocket() s: Socket, @MessageBody() b: { gameId: string; action: Record<string, unknown> }) {
    const stroke = b?.action?.type === 'stroke';
    return this.run(s, (uid) => this.games.act(uid, String(b?.gameId), b?.action ?? {}), stroke ? 'drawBucket' : 'bucket');
  }

  @SubscribeMessage('game:leave')
  gameLeave(@ConnectedSocket() s: Socket, @MessageBody() b: { gameId: string }) {
    return this.run(s, (uid) => this.games.leave(uid, String(b?.gameId)));
  }

  @SubscribeMessage('game:rematch')
  gameRematch(@ConnectedSocket() s: Socket, @MessageBody() b: { gameId: string }) {
    return this.run(s, (uid) => this.games.rematch(uid, String(b?.gameId)));
  }

  @SubscribeMessage('game:get')
  gameGet(@ConnectedSocket() s: Socket, @MessageBody() b: { gameId?: string }) {
    return this.run(s, (uid) => (b?.gameId ? this.games.get(uid, String(b.gameId)) : this.games.current(uid)));
  }
}
