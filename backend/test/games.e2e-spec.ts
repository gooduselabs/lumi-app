import { CARO_SIZE } from '../src/games/engines';
import { GamesService } from '../src/games/games.service';
import { SocialService } from '../src/social/social.service';
import { bootApp, connect, createUser, emit, once, TestApp, TestUser } from './helpers';

const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });

describe('couple mini-games (e2e)', () => {
  let t: TestApp;
  beforeAll(async () => {
    t = await bootApp();
  });
  afterAll(async () => t.app.close());

  const pair = async () => {
    const a = await createUser(t, { nickname: 'An' });
    const b = await createUser(t, { nickname: 'Bình', gender: 'FEMALE' });
    const { conversationId } = await t.app.get(SocialService).makeFriends(a.id, b.id, 'TEST');
    const [sa, sb] = await Promise.all([connect(t, a.token), connect(t, b.token)]);
    return { a, b, sa, sb, conv: conversationId as string };
  };

  const start = async (p: Awaited<ReturnType<typeof pair>>, kind: string) => {
    const invited = once(p.sb, 'game:invite');
    const inv = await emit(p.sa, 'game:invite', { conversationId: p.conv, kind });
    expect(inv.ok).toBe(true);
    const got = await invited;
    expect(got).toMatchObject({ kind, conversationId: p.conv, from: { id: p.a.id, nickname: 'An' } });
    const startedA = once(p.sa, 'game:started');
    const acc = await emit(p.sb, 'game:respond', { inviteId: got.inviteId, accept: true });
    expect(acc.ok).toBe(true);
    const g = await startedA;
    expect(g.players.map((x: any) => x.id)).toEqual([p.a.id, p.b.id]);
    return g;
  };

  it('rejects strangers and unknown games; decline notifies the inviter', async () => {
    const p = await pair();
    const stranger = await createUser(t);
    const ss = await connect(t, stranger.token);
    expect((await emit(ss, 'game:invite', { conversationId: p.conv, kind: 'CARO' })).ok).toBe(false);
    expect((await emit(p.sa, 'game:invite', { conversationId: p.conv, kind: 'CHESS' })).code).toBe('BAD_GAME');
    const invited = once(p.sb, 'game:invite');
    await emit(p.sa, 'game:invite', { conversationId: p.conv, kind: 'DRAW' });
    const { inviteId } = await invited;
    expect((await emit(ss, 'game:respond', { inviteId, accept: true })).ok).toBe(false);
    const declined = once(p.sa, 'game:declined');
    expect((await emit(p.sb, 'game:respond', { inviteId, accept: false })).data.declined).toBe(true);
    expect((await declined).inviteId).toBe(inviteId);
    for (const s of [p.sa, p.sb, ss]) s.close();
  });

  it('caro: server-validated moves, win, result posted to chat, rematch swaps the first player', async () => {
    const p = await pair();
    const g = await start(p, 'CARO');
    expect(g.turn).toBe(p.a.id);
    expect((await emit(p.sa, 'game:invite', { conversationId: p.conv, kind: 'CARO' })).code).toBe('GAME_BUSY');
    const place = (s: any, r: number, c: number) => emit(s, 'game:action', { gameId: g.id, action: { type: 'place', cell: r * CARO_SIZE + c } });
    expect((await place(p.sb, 0, 0)).code).toBe('NOT_YOUR_TURN');
    for (let i = 0; i < 4; i++) {
      expect((await place(p.sa, 7, i)).ok).toBe(true);
      expect((await place(p.sb, 8, i)).ok).toBe(true);
    }
    expect((await place(p.sa, 8, 0)).code).toBe('BAD_MOVE');
    const ended = once(p.sb, 'game:ended');
    const sysMsg = once(p.sb, 'chat:message');
    await place(p.sa, 7, 4);
    const end = await ended;
    expect(end.result).toMatchObject({ kind: 'CARO', winnerId: p.a.id, reason: 'finished' });
    expect(end.data.winLine).toHaveLength(5);
    const m = await sysMsg;
    expect(m.type).toBe('SYSTEM');
    expect(JSON.parse(m.body.slice(5))).toMatchObject({ kind: 'CARO', winnerId: p.a.id });

    const asked = once(p.sb, 'game:rematch');
    expect((await emit(p.sa, 'game:rematch', { gameId: g.id })).data.rematch).toEqual([p.a.id]);
    await asked;
    const restarted = once(p.sa, 'game:started');
    const r = await emit(p.sb, 'game:rematch', { gameId: g.id });
    const g2 = await restarted;
    expect(r.data.id).toBe(g2.id);
    expect(g2.turn).toBe(p.b.id);
    p.sa.close();
    p.sb.close();
  });

  it('truth or dare + who-knows-who: turns, hidden answers, compatibility result card', async () => {
    const p = await pair();
    const td = await start(p, 'TRUTH_DARE');
    const act = (s: any, id: string, action: any) => emit(s, 'game:action', { gameId: id, action });
    const picked = await act(p.sa, td.id, { type: 'pick', choice: 'truth' });
    expect(picked.data.data.prompt).toHaveProperty('vi');
    expect((await act(p.sb, td.id, { type: 'done' })).code).toBe('NOT_YOUR_TURN');
    await act(p.sa, td.id, { type: 'done' });
    const left = once(p.sa, 'game:ended');
    await emit(p.sb, 'game:leave', { gameId: td.id });
    expect((await left).result).toMatchObject({ reason: 'forfeit', winnerId: p.a.id });

    const km = await start(p, 'KNOW_ME');
    const n = km.data.count;
    for (let q = 0; q < n; q++) {
      const a1 = await act(p.sa, km.id, { type: 'answer', q, self: 0, guess: 1 });
      expect(a1.data.data.answers).toBeNull();
      const b1 = await act(p.sb, km.id, { type: 'answer', q, self: 1, guess: q % 2 === 0 ? 0 : 3 });
      expect(b1.data.data.phase).toBe('reveal');
      expect(b1.data.data.answers[p.a.id]).toEqual({ self: 0, guess: 1 });
      if (q === n - 1) {
        const ended = once(p.sb, 'game:ended');
        await act(p.sa, km.id, { type: 'next', q });
        const e = await ended;
        // A always right (6), B right on even questions (3) → 9/12
        expect(e.result).toMatchObject({ kind: 'KNOW_ME', compatibility: 75, winnerId: p.a.id });
      } else {
        await act(p.sb, km.id, { type: 'next', q });
      }
    }
    p.sa.close();
    p.sb.close();
  });

  it('draw & guess: strokes are relayed, word hidden from guesser, correct guess scores, timers advance rounds', async () => {
    const p = await pair();
    const svc = t.app.get(GamesService);
    const g = await start(p, 'DRAW');
    const viewB = (await emit(p.sb, 'game:get', { gameId: g.id })).data;
    expect(viewB.data.word).toBeNull();
    const viewA = (await emit(p.sa, 'game:get', { gameId: g.id })).data;
    expect(viewA.data.word.en).toBeTruthy();
    const stroke = once(p.sb, 'game:stroke');
    expect((await emit(p.sa, 'game:action', { gameId: g.id, action: { type: 'stroke', stroke: { c: '#ffcc00', w: 6, p: [0.1, 0.1, 0.5, 0.5] } } })).ok).toBe(true);
    expect((await stroke).stroke.c).toBe('#ffcc00');
    const st = once(p.sa, 'game:state');
    const right = await emit(p.sb, 'game:action', { gameId: g.id, action: { type: 'guess', text: viewA.data.word.vi } });
    expect(right.data.data.phase).toBe('reveal');
    expect((await st).data.scores[p.b.id]).toBeGreaterThan(10);
    svc.tick(g.id); // reveal -> round 2, drawer swaps
    const r2 = (await emit(p.sb, 'game:get', { gameId: g.id })).data;
    expect(r2.data.round).toBe(2);
    expect(r2.data.drawer).toBe(p.b.id);
    expect(r2.data.word).not.toBeNull();
    expect(r2.data.strokes).toEqual([]);
    p.sa.close();
    p.sb.close();
  });

  it('abandons a game when a player stays offline past the grace period', async () => {
    const svc = t.app.get(GamesService);
    svc.abandonMs = 400;
    try {
      const p = await pair();
      const g = await start(p, 'CARO');
      await emit(p.sa, 'game:action', { gameId: g.id, action: { type: 'place', cell: 112 } });
      const peer = once(p.sa, 'game:peer');
      p.sb.close();
      expect(await peer).toMatchObject({ online: false });
      const ended = once(p.sa, 'game:ended');
      expect((await ended).result).toMatchObject({ reason: 'abandoned', winnerId: p.a.id });
      p.sa.close();
    } finally {
      svc.abandonMs = 45_000;
    }
  });

  it('REST pending queue carries the game result note for offline players', async () => {
    const p = await pair();
    const g = await start(p, 'CARO');
    await emit(p.sa, 'game:action', { gameId: g.id, action: { type: 'place', cell: 0 } });
    p.sb.close();
    await emit(p.sa, 'game:leave', { gameId: g.id });
    await new Promise((r) => setTimeout(r, 300));
    const pend = await t.http().get('/messages/pending').set(auth(p.b));
    expect(pend.body.items.some((m: any) => m.type === 'SYSTEM' && m.body.startsWith('GAME:'))).toBe(true);
    p.sa.close();
  });
});
