import { RoomServiceClient } from 'livekit-server-sdk';
import { Socket } from 'socket.io-client';
import { SocialService } from '../src/social/social.service';
import { bootApp, connect, createUser, emit, once, TestApp, TestUser } from './helpers';

const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
const yearsAgo = (y: number) => `${new Date().getUTCFullYear() - y}-01-01`;
// 1x1 transparent PNG
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==', 'base64');

describe('v1.1 features (e2e)', () => {
  let t: TestApp;
  const sockets: Socket[] = [];
  const open = async (token: string) => {
    const s = await connect(t, token);
    sockets.push(s);
    return s;
  };
  beforeAll(async () => (t = await bootApp()));
  afterEach(() => sockets.splice(0).forEach((s) => s.disconnect()));
  afterAll(async () => t.app.close());

  const friends = async (a: TestUser, b: TestUser) => {
    const { conversationId } = await t.app.get(SocialService).makeFriends(a.id, b.id, 'TEST');
    return conversationId as string;
  };

  describe('age range preference', () => {
    it('defaults to 18-99 and validates updates', async () => {
      const u = await createUser(t);
      const me = await t.http().get('/me').set(auth(u)).expect(200);
      expect(me.body).toMatchObject({ agePrefMin: 18, agePrefMax: 99, hasLocation: false, locationHidden: false });
      await t.http().patch('/me').set(auth(u)).send({ agePrefMin: 25, agePrefMax: 30 }).expect(200);
      const bad = await t.http().patch('/me').set(auth(u)).send({ agePrefMin: 40 }).expect(400);
      expect(bad.body.code).toBe('INVALID_AGE_RANGE');
      await t.http().patch('/me').set(auth(u)).send({ agePrefMin: 17 }).expect(400);
    });

    it('queue only pairs users whose ranges accept each other', async () => {
      const young = await createUser(t, { birthday: yearsAgo(21) });
      const old = await createUser(t, { birthday: yearsAgo(45) });
      const mid = await createUser(t, { birthday: yearsAgo(24) });
      await t.http().patch('/me').set(auth(young)).send({ agePrefMin: 18, agePrefMax: 26 }).expect(200);
      const [sy, so, sm] = [await open(young.token), await open(old.token), await open(mid.token)];

      expect((await emit(sy, 'match:join', { mode: 'SOUL' })).data.status).toBe('waiting');
      // 45-year-old is outside young's range -> no match
      expect((await emit(so, 'match:join', { mode: 'SOUL' })).data.status).toBe('waiting');
      const r = await emit(sm, 'match:join', { mode: 'SOUL' });
      expect(r.data.status).toBe('matched');
      expect(r.data.session.partner.age).toBeLessThan(26);
      await emit(so, 'match:leave');
    });
  });

  describe('location + nearby', () => {
    it('stores coarsened location, never returns coordinates, filters by radius/age/gender', async () => {
      const me = await createUser(t, { birthday: yearsAgo(25), gender: 'MALE' });
      const near = await createUser(t, { nickname: 'Near', gender: 'FEMALE', birthday: yearsAgo(24) });
      const mid = await createUser(t, { nickname: 'Mid', gender: 'MALE', birthday: yearsAgo(30) });
      const far = await createUser(t, { nickname: 'Far', gender: 'FEMALE', birthday: yearsAgo(26) });
      const picky = await createUser(t, { nickname: 'Picky', gender: 'FEMALE', birthday: yearsAgo(40) });
      const hidden = await createUser(t, { nickname: 'Hidden', gender: 'FEMALE', birthday: yearsAgo(25) });

      const loc = await t.http().put('/me/location').set(auth(me)).send({ lat: 10.77689, lng: 106.70081 }).expect(200);
      expect(loc.body.hasLocation).toBe(true);
      expect(JSON.stringify(loc.body)).not.toContain('10.77');
      await t.http().put('/me/location').set(auth(near)).send({ lat: 10.79, lng: 106.71 }).expect(200);
      await t.http().put('/me/location').set(auth(mid)).send({ lat: 10.85, lng: 106.76 }).expect(200);
      await t.http().put('/me/location').set(auth(far)).send({ lat: 21.03, lng: 105.85 }).expect(200);
      await t.http().put('/me/location').set(auth(picky)).send({ lat: 10.78, lng: 106.7 }).expect(200);
      await t.http().put('/me/location').set(auth(hidden)).send({ lat: 10.78, lng: 106.7 }).expect(200);
      await t.http().patch('/me').set(auth(picky)).send({ agePrefMin: 35, agePrefMax: 50 }).expect(200);
      await t.http().patch('/me').set(auth(hidden)).send({ locationHidden: true }).expect(200);
      await t.http().put('/me/location').set(auth(me)).send({ lat: 95, lng: 0 }).expect(400);

      const all = await t.http().get('/nearby?radiusKm=25').set(auth(me)).expect(200);
      const names = all.body.map((u: any) => u.nickname);
      expect(names).toEqual(['Near', 'Mid']); // sorted by distance; far/picky/hidden excluded
      expect(all.body[0].distanceKm).toBeGreaterThanOrEqual(1);
      expect(Number.isInteger(all.body[0].distanceKm)).toBe(true);
      for (const u of all.body) {
        expect(u).not.toHaveProperty('latCoarse');
        expect(u).not.toHaveProperty('lngCoarse');
        expect(u).not.toHaveProperty('agePrefMin');
      }
      const women = await t.http().get('/nearby?radiusKm=25&gender=FEMALE').set(auth(me)).expect(200);
      expect(women.body.map((u: any) => u.nickname)).toEqual(['Near']);
      const age = await t.http().get('/nearby?radiusKm=25&minAge=28&maxAge=35').set(auth(me)).expect(200);
      expect(age.body.map((u: any) => u.nickname)).toEqual(['Mid']);
      const wide = await t.http().get('/nearby?radiusKm=200').set(auth(me)).expect(200);
      expect(wide.body.map((u: any) => u.nickname)).not.toContain('Far');

      await t.http().patch('/me').set(auth(me)).send({ locationHidden: true }).expect(200);
      expect((await t.http().get('/nearby').set(auth(me)).expect(400)).body.code).toBe('LOCATION_HIDDEN');
      await t.http().delete('/me/location').set(auth(me)).expect(200);
      expect((await t.http().get('/me').set(auth(me))).body.hasLocation).toBe(false);
    });

    it('match prefers a nearby partner when requested', async () => {
      // far + near only want men, so they never pair with each other while waiting.
      const farU = await createUser(t, { gender: 'FEMALE' });
      const nearU = await createUser(t, { gender: 'FEMALE' });
      const me = await createUser(t, { gender: 'MALE' });
      await t.http().put('/me/location').set(auth(farU)).send({ lat: 21.03, lng: 105.85 }).expect(200);
      await t.http().put('/me/location').set(auth(nearU)).send({ lat: 10.78, lng: 106.7 }).expect(200);
      await t.http().put('/me/location').set(auth(me)).send({ lat: 10.77, lng: 106.71 }).expect(200);
      const [sf, sn, sm] = [await open(farU.token), await open(nearU.token), await open(me.token)];
      await emit(sf, 'match:join', { mode: 'SOUL', gender: 'MALE' });
      await emit(sn, 'match:join', { mode: 'SOUL', gender: 'MALE' });
      const found = once(sn, 'match:found');
      const r = await emit(sm, 'match:join', { mode: 'SOUL', preferNearby: true });
      expect(r.data.status).toBe('matched');
      await found; // the nearby user got the match, not the longest-waiting one
      await emit(sf, 'match:leave');
    });
  });

  describe('chat media', () => {
    it('uploads image / voice / file, downloads with auth or signed url, enforces validation', async () => {
      const a = await createUser(t);
      const b = await createUser(t);
      const c = await createUser(t);
      const conv = await friends(a, b);
      const sb = await open(b.token);
      const got = once(sb, 'chat:message');

      const img = await t.http().post(`/conversations/${conv}/media`).set(auth(a))
        .field('kind', 'IMAGE').field('width', '1').field('height', '1').field('clientId', 'img-1')
        .attach('file', PNG, { filename: 'pic.png', contentType: 'image/png' }).expect(201);
      expect(img.body).toMatchObject({ type: 'IMAGE', attachment: { kind: 'IMAGE', mimeType: 'image/png', width: 1, sizeBytes: PNG.length } });
      expect((await got).id).toBe(img.body.id);

      // idempotent by clientId
      const again = await t.http().post(`/conversations/${conv}/media`).set(auth(a))
        .field('kind', 'IMAGE').field('clientId', 'img-1').attach('file', PNG, { filename: 'pic.png', contentType: 'image/png' }).expect(201);
      expect(again.body.id).toBe(img.body.id);

      const voice = await t.http().post(`/conversations/${conv}/media`).set(auth(a))
        .field('kind', 'VOICE').field('durationMs', '4200')
        .attach('file', Buffer.from('fake-aac-bytes'), { filename: 'v.m4a', contentType: 'audio/mp4' }).expect(201);
      expect(voice.body.attachment).toMatchObject({ kind: 'VOICE', durationMs: 4200 });

      const file = await t.http().post(`/conversations/${conv}/media`).set(auth(a))
        .field('kind', 'FILE').field('caption', 'notes')
        .attach('file', Buffer.from('%PDF-1.4 test'), { filename: '../Kế hoạch.pdf', contentType: 'application/pdf' }).expect(201);
      expect(file.body).toMatchObject({ body: 'notes', attachment: { fileName: 'Kế hoạch.pdf', mimeType: 'application/pdf' } });

      // validation
      const exe = await t.http().post(`/conversations/${conv}/media`).set(auth(a)).field('kind', 'FILE')
        .attach('file', Buffer.from('MZ'), { filename: 'x.exe', contentType: 'application/octet-stream' }).expect(400);
      expect(exe.body.code).toBe('UNSUPPORTED_FILE_TYPE');
      const fakeImg = await t.http().post(`/conversations/${conv}/media`).set(auth(a)).field('kind', 'IMAGE')
        .attach('file', Buffer.from('<svg onload=alert(1)>'), { filename: 'x.png', contentType: 'image/png' }).expect(400);
      expect(fakeImg.body.code).toBe('UNSUPPORTED_FILE_TYPE');
      const noDur = await t.http().post(`/conversations/${conv}/media`).set(auth(a)).field('kind', 'VOICE')
        .attach('file', Buffer.from('x'), { filename: 'v.m4a', contentType: 'audio/mp4' }).expect(400);
      expect(noDur.body.code).toBe('INVALID_DURATION');
      const big = await t.http().post(`/conversations/${conv}/media`).set(auth(a)).field('kind', 'FILE')
        .attach('file', Buffer.alloc(1024 * 1024 + 10), { filename: 'big.txt', contentType: 'text/plain' });
      expect([400, 413]).toContain(big.status);
      await t.http().post(`/conversations/${conv}/media`).set(auth(c)).field('kind', 'FILE')
        .attach('file', Buffer.from('hi'), { filename: 'a.txt', contentType: 'text/plain' }).expect(404);

      // downloads
      const id = img.body.attachment.id;
      const dl = await t.http().get(`/attachments/${id}`).set(auth(b)).expect(200);
      expect(dl.headers['content-type']).toBe('image/png');
      expect(Buffer.compare(dl.body, PNG)).toBe(0);
      await t.http().get(`/attachments/${id}`).expect(401);
      await t.http().get(`/attachments/${id}`).set(auth(c)).expect(404);
      await t.http().get(img.body.attachment.url).expect(200);
      await t.http().get(img.body.attachment.url.replace(/sig=[^&]+/, 'sig=forged')).expect(401);
      const fdl = await t.http().get(`/attachments/${file.body.attachment.id}`).set(auth(b)).expect(200);
      expect(fdl.headers['content-disposition']).toContain('attachment;');

      const hist = await t.http().get('/messages/pending').set(auth(b)).expect(200);
      expect(hist.body.items.slice(-3).map((m: any) => m.type)).toEqual(['IMAGE', 'VOICE', 'FILE']);
      const list = await t.http().get('/conversations').set(auth(b)).expect(200);
      expect(list.body[0].lastMessage.type).toBe('FILE');
    });
  });

  describe('friend voice calls', () => {
    it('rings, accepts with LiveKit tokens, and ends for both', async () => {
      const a = await createUser(t);
      const b = await createUser(t);
      const stranger = await createUser(t);
      const conv = await friends(a, b);
      const [sa, sb] = [await open(a.token), await open(b.token)];
      const incoming = once(sb, 'call:incoming');
      const start = await t.http().post('/calls').set(auth(a)).send({ conversationId: conv }).expect(201);
      expect(start.body.voice).toMatchObject({ url: process.env.LIVEKIT_URL, room: `call_${start.body.callId}` });
      expect(start.body.voice.token.split('.')).toHaveLength(3);
      expect((await incoming).from.id).toBe(a.id);

      await t.http().post('/calls').set(auth(stranger)).send({ conversationId: conv }).expect(404);
      await t.http().post(`/calls/${start.body.callId}/accept`).set(auth(a)).expect(403);
      const accepted = once(sa, 'call:accepted');
      const acc = await t.http().post(`/calls/${start.body.callId}/accept`).set(auth(b)).expect(200);
      expect(acc.body.voice.room).toBe(start.body.voice.room);
      await accepted;
      const payload = JSON.parse(Buffer.from(acc.body.voice.token.split('.')[1], 'base64url').toString());
      expect(payload.sub).toBe(b.id);
      expect(payload.video).toMatchObject({ room: `call_${start.body.callId}`, roomJoin: true });

      const ended = once(sa, 'call:ended');
      await t.http().post(`/calls/${start.body.callId}/end`).set(auth(b)).expect(200);
      expect((await ended).reason).toBe('ENDED');
      await t.http().post(`/calls/${start.body.callId}/end`).set(auth(b)).expect(404);
    });

    it('callee decline notifies caller', async () => {
      const a = await createUser(t);
      const b = await createUser(t);
      const conv = await friends(a, b);
      const sa = await open(a.token);
      const start = await t.http().post('/calls').set(auth(a)).send({ conversationId: conv }).expect(201);
      const ended = once(sa, 'call:ended');
      await t.http().post(`/calls/${start.body.callId}/decline`).set(auth(b)).expect(200);
      expect((await ended).reason).toBe('DECLINED');
    });

    // Runs only when a LiveKit server is reachable (e.g. `livekit-server --dev` locally).
    const lkUrl = process.env.LIVEKIT_TEST_URL;
    (lkUrl ? it : it.skip)('LiveKit server accepts our API credentials', async () => {
      const svc = new RoomServiceClient(lkUrl!.replace(/^ws/, 'http'), process.env.LIVEKIT_TEST_KEY ?? 'devkey', process.env.LIVEKIT_TEST_SECRET ?? 'secret');
      const room = await svc.createRoom({ name: `ci_${Date.now()}`, emptyTimeout: 10 });
      expect(room.name).toMatch(/^ci_/);
      await svc.deleteRoom(room.name);
      // A token minted by our API is accepted by the server's signalling endpoint.
      const a = await createUser(t);
      const b = await createUser(t);
      const conv = await friends(a, b);
      const start = await t.http().post('/calls').set(auth(a)).send({ conversationId: conv }).expect(201);
      const res = await fetch(`${lkUrl!.replace(/^ws/, 'http')}/rtc/validate?access_token=${start.body.voice.token}`);
      expect(res.status).toBe(200);
      const bad = await fetch(`${lkUrl!.replace(/^ws/, 'http')}/rtc/validate?access_token=${start.body.voice.token}x`);
      expect(bad.status).toBe(401);
      await t.http().post(`/calls/${start.body.callId}/end`).set(auth(a)).expect(200);
    });
  });
});
