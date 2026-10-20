import { HttpStatus, Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { ApiError, Errors } from '../common/errors';
import { ChatService } from '../chat/chat.service';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeEmitter } from '../realtime/realtime.emitter';
import { ENGINES, GAME_KINDS, GameKind, GameResult, Rng, Step } from './engines';

export const INVITE_TTL_MS = 60_000;
export const ABANDON_MS = 45_000;
const KEEP_ENDED_MS = 10 * 60_000;

interface Profile {
  id: string;
  nickname: string;
  avatarId: string;
}
interface Invite {
  id: string;
  kind: GameKind;
  from: string;
  to: string;
  conversationId: string;
  expiresAt: number;
  timer: NodeJS.Timeout;
}
interface Game {
  id: string;
  kind: GameKind;
  conversationId: string;
  players: [string, string];
  profiles: Profile[];
  state: any;
  version: number;
  actions: number;
  startedAt: number;
  timer?: NodeJS.Timeout;
  abandon: Map<string, NodeJS.Timeout>;
  rematch: Set<string>;
  result?: GameResult;
  nextGameId?: string;
}

const busy = () => new ApiError(HttpStatus.CONFLICT, 'GAME_BUSY', 'Already in a game');

/**
 * Server-authoritative 2-player games. State lives in memory on this API instance (games are short);
 * every move is validated by the pure engines in engines.ts and each player gets their own view.
 */
@Injectable()
export class GamesService implements OnModuleDestroy {
  private readonly logger = new Logger(GamesService.name);
  private readonly invites = new Map<string, Invite>();
  private readonly games = new Map<string, Game>();
  private readonly active = new Map<string, string>(); // userId -> gameId
  rng: Rng = Math.random;
  abandonMs = ABANDON_MS;
  now: () => number = Date.now;

  constructor(
    private readonly chat: ChatService,
    private readonly prisma: PrismaService,
    private readonly rt: RealtimeEmitter,
  ) {}

  onModuleDestroy() {
    for (const i of this.invites.values()) clearTimeout(i.timer);
    for (const g of this.games.values()) this.clearTimers(g);
  }

  // ───────── invites ─────────
  async invite(userId: string, conversationId: string, kind: string) {
    if (!GAME_KINDS.includes(kind as GameKind)) throw Errors.badRequest('BAD_GAME', 'Unknown game');
    const to = await this.chat.friendPeer(userId, conversationId);
    if (this.active.has(userId) || this.active.has(to)) throw busy();
    for (const i of this.invites.values()) {
      if ((i.from === userId && i.to === to) || (i.from === to && i.to === userId)) this.dropInvite(i);
    }
    const id = randomUUID();
    const expiresAt = this.now() + INVITE_TTL_MS;
    const inv: Invite = {
      id, kind: kind as GameKind, from: userId, to, conversationId, expiresAt,
      timer: setTimeout(() => {
        if (!this.invites.has(id)) return;
        this.dropInvite(inv);
        for (const u of [inv.from, inv.to]) this.rt.toUser(u, 'game:invite_expired', { inviteId: id });
      }, INVITE_TTL_MS),
    };
    inv.timer.unref?.();
    this.invites.set(id, inv);
    const [from] = await this.profiles([userId]);
    this.rt.toUser(to, 'game:invite', { inviteId: id, kind, conversationId, from, expiresAt });
    return { inviteId: id, kind, expiresAt };
  }

  cancelInvite(userId: string, inviteId: string) {
    const inv = this.invites.get(inviteId);
    if (!inv || inv.from !== userId) throw Errors.notFound('Invite');
    this.dropInvite(inv);
    this.rt.toUser(inv.to, 'game:invite_expired', { inviteId });
    return { cancelled: true };
  }

  async respond(userId: string, inviteId: string, accept: boolean) {
    const inv = this.invites.get(inviteId);
    if (!inv || inv.to !== userId) throw Errors.notFound('Invite');
    this.dropInvite(inv);
    if (!accept) {
      this.rt.toUser(inv.from, 'game:declined', { inviteId, kind: inv.kind, conversationId: inv.conversationId });
      return { declined: true };
    }
    if (this.active.has(inv.from) || this.active.has(inv.to)) throw busy();
    const g = await this.start(inv.kind, inv.conversationId, [inv.from, inv.to]);
    return this.view(g, userId);
  }

  private dropInvite(i: Invite) {
    clearTimeout(i.timer);
    this.invites.delete(i.id);
  }

  // ───────── lifecycle ─────────
  private async start(kind: GameKind, conversationId: string, players: [string, string]) {
    const step = ENGINES[kind].init(players, this.rng, this.now());
    const g: Game = {
      id: randomUUID(), kind, conversationId, players, profiles: await this.profiles(players),
      state: step.state, version: 1, actions: 0, startedAt: this.now(), abandon: new Map(), rematch: new Set(),
    };
    this.games.set(g.id, g);
    for (const p of players) this.active.set(p, g.id);
    this.arm(g, step.timerMs);
    for (const p of players) if (!this.rt.isOnline(p)) this.onOffline(p);
    this.broadcast(g, 'game:started');
    return g;
  }

  act(userId: string, gameId: string, action: Record<string, unknown>) {
    const g = this.games.get(gameId);
    if (!g || !g.players.includes(userId)) throw Errors.notFound('Game');
    if (g.result) {
      if (action?.type === 'next') return this.view(g, userId);
      throw Errors.badRequest('GAME_OVER', 'Game is over');
    }
    const step = ENGINES[g.kind].act(g.state, userId, action ?? {}, this.rng, this.now());
    g.actions++;
    this.apply(g, step);
    if (step.relay) {
      // Drawing strokes: relay only (cheap); full state is re-sent on the next "real" change.
      const peer = g.players.find((p) => p !== userId)!;
      this.rt.toUser(peer, step.relay.event, { gameId, version: g.version, ...(step.relay.payload as object) });
      return { version: g.version };
    }
    if (ENGINES[g.kind].over(g.state)) void this.finish(g, 'finished');
    else this.broadcast(g);
    return this.view(g, userId);
  }

  private apply(g: Game, step: Step<unknown>) {
    g.state = step.state;
    g.version++;
    if (step.timerMs !== undefined) this.arm(g, step.timerMs);
  }

  private arm(g: Game, ms: number | null | undefined) {
    if (g.timer) clearTimeout(g.timer);
    g.timer = undefined;
    if (ms == null) return;
    g.timer = setTimeout(() => this.tick(g.id), ms);
    g.timer.unref?.();
  }

  /** Engine timer (draw rounds). Public for tests. */
  tick(gameId: string) {
    const g = this.games.get(gameId);
    const engine = g && ENGINES[g.kind];
    if (!g || g.result || !engine?.onTimer) return;
    this.apply(g, engine.onTimer(g.state, this.rng, this.now()));
    if (engine.over(g.state)) void this.finish(g, 'finished');
    else this.broadcast(g);
  }

  leave(userId: string, gameId: string) {
    const g = this.games.get(gameId);
    if (!g || !g.players.includes(userId)) throw Errors.notFound('Game');
    if (!g.result) void this.finish(g, 'forfeit', userId);
    return { left: true };
  }

  async rematch(userId: string, gameId: string) {
    const g = this.games.get(gameId);
    if (!g || !g.players.includes(userId)) throw Errors.notFound('Game');
    if (!g.result) throw Errors.badRequest('GAME_NOT_OVER', 'Finish this game first');
    if (g.nextGameId) {
      const n = this.games.get(g.nextGameId);
      if (n) return this.view(n, userId);
    }
    const peer = g.players.find((p) => p !== userId)!;
    g.rematch.add(userId);
    if (g.rematch.size < 2) {
      this.rt.toUser(peer, 'game:rematch', { gameId, by: userId, kind: g.kind });
      this.broadcast(g);
      return this.view(g, userId);
    }
    if (this.active.has(userId) || this.active.has(peer)) throw busy();
    // Swap who starts.
    const next = await this.start(g.kind, g.conversationId, [g.players[1], g.players[0]]);
    g.nextGameId = next.id;
    return this.view(next, userId);
  }

  current(userId: string) {
    const id = this.active.get(userId);
    const g = id ? this.games.get(id) : undefined;
    const invites = [...this.invites.values()].filter((i) => i.to === userId || i.from === userId).map((i) => ({
      inviteId: i.id, kind: i.kind, conversationId: i.conversationId, from: i.from, to: i.to, expiresAt: i.expiresAt,
    }));
    return { game: g ? this.view(g, userId) : null, invites };
  }

  get(userId: string, gameId: string) {
    const g = this.games.get(gameId);
    if (!g || !g.players.includes(userId)) throw Errors.notFound('Game');
    return this.view(g, userId);
  }

  // ───────── presence ─────────
  onOffline(userId: string) {
    const g = this.games.get(this.active.get(userId) ?? '');
    if (!g || g.result || g.abandon.has(userId)) return;
    const t = setTimeout(() => {
      g.abandon.delete(userId);
      if (!g.result && !this.rt.isOnline(userId)) void this.finish(g, 'abandoned', userId);
    }, this.abandonMs);
    t.unref?.();
    g.abandon.set(userId, t);
    const peer = g.players.find((p) => p !== userId)!;
    this.rt.toUser(peer, 'game:peer', { gameId: g.id, userId, online: false, graceMs: this.abandonMs });
  }

  onOnline(userId: string) {
    const g = this.games.get(this.active.get(userId) ?? '');
    const t = g?.abandon.get(userId);
    if (!g || !t) return;
    clearTimeout(t);
    g.abandon.delete(userId);
    const peer = g.players.find((p) => p !== userId)!;
    this.rt.toUser(peer, 'game:peer', { gameId: g.id, userId, online: true });
  }

  // ───────── results ─────────
  private async finish(g: Game, reason: GameResult['reason'], quitter?: string) {
    if (g.result) return;
    this.clearTimers(g);
    const base = ENGINES[g.kind].result(g.state);
    const result: GameResult = {
      kind: g.kind,
      ...base,
      winnerId: quitter ? g.players.find((p) => p !== quitter)! : base.winnerId,
      reason,
    };
    g.result = result;
    for (const p of g.players) if (this.active.get(p) === g.id) this.active.delete(p);
    this.broadcast(g, 'game:ended');
    setTimeout(() => this.games.delete(g.id), KEEP_ENDED_MS).unref?.();
    if (g.actions === 0 && reason !== 'finished') return; // nothing worth posting
    try {
      await this.chat.postSystem(g.conversationId, g.players[0], `GAME:${JSON.stringify({ ...result, gameId: g.id, players: g.players })}`);
    } catch (e) {
      this.logger.warn(`could not post game result: ${(e as Error).message}`);
    }
  }

  private clearTimers(g: Game) {
    if (g.timer) clearTimeout(g.timer);
    g.timer = undefined;
    for (const t of g.abandon.values()) clearTimeout(t);
    g.abandon.clear();
  }

  private view(g: Game, viewer: string) {
    const engine = ENGINES[g.kind];
    return {
      id: g.id,
      kind: g.kind,
      conversationId: g.conversationId,
      players: g.profiles,
      you: viewer,
      status: g.result ? 'ended' : 'active',
      version: g.version,
      turn: g.result ? null : engine.turn(g.state),
      data: engine.view(g.state, viewer),
      result: g.result ?? null,
      rematch: [...g.rematch],
      nextGameId: g.nextGameId ?? null,
      serverTime: this.now(),
    };
  }

  private broadcast(g: Game, event = 'game:state') {
    for (const p of g.players) this.rt.toUser(p, event, this.view(g, p));
  }

  private async profiles(ids: string[]): Promise<Profile[]> {
    const rows = await this.prisma.user.findMany({ where: { id: { in: ids } }, select: { id: true, nickname: true, avatarId: true } });
    return ids.map((id) => {
      const r = rows.find((x) => x.id === id);
      return { id, nickname: r?.nickname ?? 'Lumi', avatarId: r?.avatarId ?? 'a01' };
    });
  }
}
