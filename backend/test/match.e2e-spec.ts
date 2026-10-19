import { Socket } from 'socket.io-client';
import { bootApp, connect, createUser, emit, once, TestApp } from './helpers';

describe('Soul Match + chat (e2e)', () => {
  let t: TestApp;
  const sockets: Socket[] = [];
  const open = async (token: string) => {
    const s = await connect(t, token);
    sockets.push(s);
    return s;
  };

  beforeAll(async () => (t = await bootApp()));
  afterEach(() => {
    sockets.splice(0).forEach((s) => s.disconnect());
  });
  afterAll(async () => t.app.close());

  it('rejects sockets without a valid token', async () => {
    await expect(connect(t, 'bad')).rejects.toBeDefined();
  });

  it('requires onboarding before matching', async () => {
    const email = `nob${Date.now()}@test.lumi`;
    const reg = await t.http().post('/auth/register').send({ email, password: 'Passw0rd!' });
    const v = await t.http().post('/auth/verify-email').send({ email, code: reg.body.devCode });
    const s = await open(v.body.accessToken);
    const r = await emit(s, 'match:join', { mode: 'SOUL' });
    expect(r).toMatchObject({ ok: false, code: 'NOT_ONBOARDED' });
  });

  it('matches two strangers anonymously, relays messages, mutual like -> friends -> persistent chat', async () => {
    const a = await createUser(t, { nickname: 'Alice', gender: 'FEMALE', interests: ['music', 'anime'] });
    const b = await createUser(t, { nickname: 'Bao', gender: 'MALE', interests: ['music', 'travel'] });
    const sa = await open(a.token);
    const sb = await open(b.token);

    const wait = await emit(sa, 'match:join', { mode: 'SOUL' });
    expect(wait).toMatchObject({ ok: true, data: { status: 'waiting' } });

    const foundA = once(sa, 'match:found');
    const joinB = await emit(sb, 'match:join', { mode: 'SOUL' });
    expect(joinB.ok).toBe(true);
    expect(joinB.data.status).toBe('matched');
    const session = joinB.data.session;
    const fa = await foundA;
    expect(fa.sessionId).toBe(session.sessionId);
    expect(session.durationSec).toBe(6);
    // anonymity: nothing identifying is sent
    expect(session.partner).not.toHaveProperty('nickname');
    expect(session.partner).not.toHaveProperty('id');
    expect(session.partner.commonInterests).toEqual(['music']);
    expect(fa.partner.gender).toBe('MALE');

    // ephemeral anonymous chat + typing
    const typing = once(sb, 'soul:typing');
    await emit(sa, 'soul:typing', { sessionId: session.sessionId });
    await typing;
    const gotMsg = once(sb, 'soul:message');
    const sent = await emit(sa, 'soul:message', { sessionId: session.sessionId, text: '  Chào bạn!  ' });
    expect(sent.ok).toBe(true);
    expect((await gotMsg).text).toBe('Chào bạn!');

    // double like
    const likedB = once(sb, 'match:liked');
    const l1 = await emit(sa, 'match:like', { sessionId: session.sessionId });
    expect(l1.data.mutual).toBe(false);
    await likedB;
    const mutualA = once(sa, 'match:mutual');
    const l2 = await emit(sb, 'match:like', { sessionId: session.sessionId });
    expect(l2.data.mutual).toBe(true);
    const mA = await mutualA;
    expect(mA.friend.nickname).toBe('Bao');
    expect(mA.conversationId).toBe(l2.data.conversationId);
    const conversationId = mA.conversationId;

    // session is closed after mutual
    const late = await emit(sa, 'soul:message', { sessionId: session.sessionId, text: 'still there?' });
    expect(late).toMatchObject({ ok: false, code: 'SESSION_CLOSED' });

    // friends list both sides
    const fl = await t.http().get('/friends').set('Authorization', `Bearer ${a.token}`).expect(200);
    expect(fl.body.map((f: any) => f.id)).toContain(b.id);
    expect(fl.body[0].online).toBe(true);

    // realtime 1-1 chat with typing, delivery and read receipts
    const typingB = once(sb, 'chat:typing');
    await emit(sa, 'chat:typing', { conversationId, isTyping: true });
    expect((await typingB).isTyping).toBe(true);

    const gotChat = once(sb, 'chat:message');
    const send = await emit(sa, 'chat:send', { conversationId, body: 'Kết bạn rồi nè 🎉', clientId: 'c-1' });
    expect(send.ok).toBe(true);
    expect((await gotChat).body).toBe('Kết bạn rồi nè 🎉');
    // idempotent retry with same clientId
    const again = await emit(sa, 'chat:send', { conversationId, body: 'Kết bạn rồi nè 🎉', clientId: 'c-1' });
    expect(again.data.id).toBe(send.data.id);

    const convB = await t.http().get('/conversations').set('Authorization', `Bearer ${b.token}`).expect(200);
    expect(convB.body[0].unread).toBeGreaterThanOrEqual(1);
    expect(convB.body[0].peer.nickname).toBe('Alice');

    const readA = once(sa, 'chat:read');
    await emit(sb, 'chat:read', { conversationId });
    expect((await readA).conversationId).toBe(conversationId);
    const convB2 = await t.http().get('/conversations').set('Authorization', `Bearer ${b.token}`).expect(200);
    expect(convB2.body[0].unread).toBe(0);

    // persistent history over REST (system message + text)
    const hist = await t.http().get(`/conversations/${conversationId}/messages`).set('Authorization', `Bearer ${b.token}`).expect(200);
    expect(hist.body.items.map((m: any) => m.type)).toEqual(['TEXT', 'SYSTEM']);

    // outsiders cannot read it
    const c = await createUser(t);
    await t.http().get(`/conversations/${conversationId}/messages`).set('Authorization', `Bearer ${c.token}`).expect(404);

    // block hides the friend and stops messaging
    await t.http().post(`/blocks/${b.id}`).set('Authorization', `Bearer ${a.token}`).expect(200);
    const fl2 = await t.http().get('/friends').set('Authorization', `Bearer ${a.token}`).expect(200);
    expect(fl2.body.map((f: any) => f.id)).not.toContain(b.id);
    const blockedSend = await emit(sb, 'chat:send', { conversationId, body: 'hello?' });
    expect(blockedSend).toMatchObject({ ok: false, code: 'BLOCKED' });
  });

  it('skip ends the session for both sides', async () => {
    const c = await createUser(t, { gender: 'MALE' });
    const d = await createUser(t, { gender: 'FEMALE' });
    const sc = await open(c.token);
    const sd = await open(d.token);
    await emit(sc, 'match:join', { mode: 'SOUL' });
    const r = await emit(sd, 'match:join', { mode: 'SOUL' });
    const endedC = once(sc, 'match:ended');
    await emit(sd, 'match:skip', { sessionId: r.data.session.sessionId });
    const e = await endedC;
    expect(e).toMatchObject({ reason: 'SKIPPED', byMe: false });
  });

  it('session times out when the timer ends without mutual like', async () => {
    const c = await createUser(t);
    const d = await createUser(t);
    const sc = await open(c.token);
    const sd = await open(d.token);
    await emit(sc, 'match:join', { mode: 'SOUL' });
    const r = await emit(sd, 'match:join', { mode: 'SOUL' });
    await emit(sc, 'match:like', { sessionId: r.data.session.sessionId });
    const e = await once(sc, 'match:ended', 10000);
    expect(e.reason).toBe('TIMEOUT');
    const fl = await t.http().get('/friends').set('Authorization', `Bearer ${c.token}`).expect(200);
    expect(fl.body).toHaveLength(0);
  }, 15000);

  it('blocking from a session ends it and prevents re-matching; reports are stored', async () => {
    const e = await createUser(t);
    const f = await createUser(t);
    const se = await open(e.token);
    const sf = await open(f.token);
    await emit(se, 'match:join', { mode: 'SOUL' });
    const r = await emit(sf, 'match:join', { mode: 'SOUL' });
    const sid = r.data.session.sessionId;
    await t.http().post(`/match/sessions/${sid}/report`).set('Authorization', `Bearer ${f.token}`).send({ reason: 'SPAM' }).expect(201);
    const ended = once(se, 'match:ended');
    await t.http().post(`/match/sessions/${sid}/block`).set('Authorization', `Bearer ${f.token}`).expect(200);
    expect((await ended).reason).toBe('BLOCKED');

    const w1 = await emit(se, 'match:join', { mode: 'SOUL' });
    const w2 = await emit(sf, 'match:join', { mode: 'SOUL' });
    expect(w1.data.status).toBe('waiting');
    expect(w2.data.status).toBe('waiting');
    await emit(se, 'match:leave');
    await emit(sf, 'match:leave');
  });

  it('respects gender preference filters', async () => {
    const g = await createUser(t, { gender: 'MALE' });
    const h = await createUser(t, { gender: 'MALE' });
    const sg = await open(g.token);
    const sh = await open(h.token);
    await emit(sg, 'match:join', { mode: 'SOUL', gender: 'FEMALE' });
    const r = await emit(sh, 'match:join', { mode: 'SOUL' });
    expect(r.data.status).toBe('waiting');
    const i = await createUser(t, { gender: 'FEMALE' });
    const si = await open(i.token);
    const ri = await emit(si, 'match:join', { mode: 'SOUL' });
    expect(ri.data.status).toBe('matched'); // matched with g or h (FIFO -> g)
    await emit(sh, 'match:leave');
  });
});
