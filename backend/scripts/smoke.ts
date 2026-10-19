/**
 * End-to-end smoke test against a RUNNING API (needs DEV_EXPOSE_CODES=true):
 *   API_URL=http://localhost:3000 npm run smoke
 * Signs up two users (email + code), onboards, logs in, matches them via Soul Match,
 * exchanges an anonymous message, double-likes -> friends, then sends a persistent 1-1 message.
 */
import { io, Socket } from 'socket.io-client';

const API = process.env.API_URL ?? 'http://localhost:3000';
const log = (...a: unknown[]) => console.log('✔', ...a);

async function call(method: string, path: string, body?: unknown, token?: string) {
  const r = await fetch(API + path, {
    method,
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(`${method} ${path} -> ${r.status} ${JSON.stringify(json)}`);
  return json as any;
}

function connect(token: string): Promise<Socket> {
  return new Promise((resolve, reject) => {
    const s = io(API, { auth: { token }, transports: ['websocket'] });
    s.once('ready', () => resolve(s));
    s.once('connect_error', reject);
  });
}
const once = (s: Socket, ev: string) => new Promise<any>((res) => s.once(ev, res));
const ack = (s: Socket, ev: string, p: unknown = {}) => s.timeout(5000).emitWithAck(ev, p);

async function user(name: string, gender: string, interests: string[]) {
  const email = `${name.toLowerCase()}.${Date.now()}@smoke.lumi`;
  const password = 'Passw0rd!';
  const reg = await call('POST', '/auth/register', { email, password });
  if (!reg.devCode) throw new Error('DEV_EXPOSE_CODES must be true for the smoke test');
  log(`${name}: registered ${email}, code ${reg.devCode} (also printed in API log)`);
  await call('POST', '/auth/verify-email', { email, code: reg.devCode });
  const login = await call('POST', '/auth/login', { email, password });
  log(`${name}: verified + logged in`);
  await call('PUT', '/me/onboarding', { nickname: name, gender, birthday: '1998-06-15', avatarId: 'a04', interests }, login.accessToken);
  log(`${name}: onboarded`);
  return { token: login.accessToken as string, id: login.user.id as string };
}

async function main() {
  console.log(`Lumi smoke test -> ${API}`);
  log('health', JSON.stringify(await call('GET', '/health')));
  const a = await user('Linh', 'FEMALE', ['music', 'coffee']);
  const b = await user('Minh', 'MALE', ['coffee', 'travel']);
  const sa = await connect(a.token);
  const sb = await connect(b.token);
  log('both sockets connected');

  const w = await ack(sa, 'match:join', { mode: 'SOUL' });
  log('Linh queued:', w.data.status);
  const foundA = once(sa, 'match:found');
  const j = await ack(sb, 'match:join', { mode: 'SOUL' });
  const session = j.data.session;
  await foundA;
  log(`matched! session ${session.sessionId}, ${session.durationSec}s, common interests: ${session.partner.commonInterests}`);

  const got = once(sb, 'soul:message');
  await ack(sa, 'soul:message', { sessionId: session.sessionId, text: 'Chào bạn, mình thích cà phê ☕' });
  log('anonymous message relayed:', (await got).text);

  const mutual = once(sa, 'match:mutual');
  await ack(sa, 'match:like', { sessionId: session.sessionId });
  await ack(sb, 'match:like', { sessionId: session.sessionId });
  const m = await mutual;
  log(`mutual like -> friends with ${m.friend.nickname}, conversation ${m.conversationId}`);

  const chatMsg = once(sb, 'chat:message');
  await ack(sa, 'chat:send', { conversationId: m.conversationId, body: 'Giờ mình là bạn rồi nhé!' });
  log('persistent chat delivered:', (await chatMsg).body);
  const readEv = once(sa, 'chat:read');
  await ack(sb, 'chat:read', { conversationId: m.conversationId });
  await readEv;
  log('read receipt delivered');

  const hist = await call('GET', `/conversations/${m.conversationId}/messages`, undefined, b.token);
  log(`history has ${hist.items.length} messages:`, hist.items.map((x: any) => `${x.type}:${x.body}`).join(' | '));
  const friends = await call('GET', '/friends', undefined, b.token);
  log('Minh friends:', friends.map((f: any) => f.nickname).join(', '));

  sa.disconnect();
  sb.disconnect();
  console.log('\nSMOKE TEST PASSED');
}

main().catch((e) => {
  console.error('SMOKE TEST FAILED:', e);
  process.exit(1);
});
