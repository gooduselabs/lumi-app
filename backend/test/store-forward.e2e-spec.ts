import { existsSync } from 'fs';
import { join } from 'path';
import { ChatService } from '../src/chat/chat.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { SocialService } from '../src/social/social.service';
import { bootApp, connect, createUser, emit, once, TestApp, TestUser } from './helpers';

const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==', 'base64');
const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
const uploads = process.env.UPLOAD_DIR!;

describe('store-and-forward chat (e2e)', () => {
  let t: TestApp;
  let prisma: PrismaService;
  beforeAll(async () => {
    t = await bootApp();
    prisma = t.app.get(PrismaService);
  });
  afterAll(async () => t.app.close());

  const pair = async () => {
    const a = await createUser(t);
    const b = await createUser(t);
    const { conversationId } = await t.app.get(SocialService).makeFriends(a.id, b.id, 'TEST');
    // drop the system notes so tests start clean
    for (const u of [a, b]) {
      const p = await t.http().get('/messages/pending').set(auth(u));
      await t.http().post('/messages/ack').set(auth(u)).send({ ids: p.body.items.map((m: any) => m.id) }).expect(200);
    }
    return { a, b, conv: conversationId as string };
  };

  it('history endpoint is gone', async () => {
    const { b, conv } = await pair();
    await t.http().get(`/conversations/${conv}/messages`).set(auth(b)).expect(404);
  });

  it('queues for an offline recipient, delivers on connect, deletes on ack and notifies the sender', async () => {
    const { a, b, conv } = await pair();
    const sa = await connect(t, a.token);
    const sent = await emit(sa, 'chat:send', { conversationId: conv, body: 'hello offline B', clientId: 'x1' });
    expect(sent.ok).toBe(true);
    expect(await prisma.message.count({ where: { id: sent.data.id } })).toBe(1);

    // sender's own device doesn't get it back as pending
    expect((await t.http().get('/messages/pending').set(auth(a))).body.items).toEqual([]);

    // B comes online: server pushes the queue
    const { io } = await import('socket.io-client');
    const sb = io(t.url, { auth: { token: b.token }, transports: ['websocket'], forceNew: true, reconnection: false });
    const pushed: any = await once(sb as any, 'chat:pending');
    expect(pushed.items.map((m: any) => m.id)).toEqual([sent.data.id]);

    const delivered = once(sa, 'chat:delivered');
    const ack = await emit(sb as any, 'chat:ack', { ids: [sent.data.id, 'not-mine'] });
    expect(ack).toMatchObject({ ok: true, data: { deleted: 1 } });
    expect(await delivered).toMatchObject({ conversationId: conv, messageIds: [sent.data.id] });
    expect(await prisma.message.count({ where: { id: sent.data.id } })).toBe(0);
    expect((await t.http().get('/messages/pending').set(auth(b))).body.items).toEqual([]);

    // read receipts still work
    const read = once(sa, 'chat:read');
    await emit(sb as any, 'chat:read', { conversationId: conv });
    expect((await read).conversationId).toBe(conv);
    sa.disconnect();
    sb.disconnect();
  });

  it('only the recipient can ack; attachments blobs are deleted on ack', async () => {
    const { a, b, conv } = await pair();
    const img = await t.http().post(`/conversations/${conv}/media`).set(auth(a)).field('kind', 'IMAGE')
      .attach('file', PNG, { filename: 'p.png', contentType: 'image/png' }).expect(201);
    const att = await prisma.attachment.findUniqueOrThrow({ where: { id: img.body.attachment.id } });
    const path = join(uploads, att.storageKey);
    expect(existsSync(path)).toBe(true);

    // sender acking does nothing
    expect((await t.http().post('/messages/ack').set(auth(a)).send({ ids: [img.body.id] }).expect(200)).body.deleted).toBe(0);
    // recipient downloads, then acks
    await t.http().get(`/attachments/${att.id}`).set(auth(b)).expect(200);
    expect((await t.http().post('/messages/ack').set(auth(b)).send({ ids: [img.body.id] }).expect(200)).body.deleted).toBe(1);
    expect(existsSync(path)).toBe(false);
    expect(await prisma.attachment.count({ where: { id: att.id } })).toBe(0);
    await t.http().get(`/attachments/${att.id}`).set(auth(b)).expect(404);
    await t.http().post('/messages/ack').set(auth(b)).send({ ids: ['nope'] }).expect(400);
  });

  it('TTL purge removes undelivered messages and their blobs', async () => {
    const { a, b, conv } = await pair();
    const keep = await t.http().post(`/conversations/${conv}/messages`).set(auth(a)).send({ body: 'fresh' }).expect(201);
    const old = await t.http().post(`/conversations/${conv}/media`).set(auth(a)).field('kind', 'FILE')
      .attach('file', Buffer.from('hello'), { filename: 'a.txt', contentType: 'text/plain' }).expect(201);
    const att = await prisma.attachment.findUniqueOrThrow({ where: { id: old.body.attachment.id } });
    await prisma.message.update({ where: { id: old.body.id }, data: { expiresAt: new Date(Date.now() - 1000) } });
    // expired items are no longer offered
    const p = await t.http().get('/messages/pending').set(auth(b));
    expect(p.body.items.map((m: any) => m.id)).toEqual([keep.body.id]);

    const r = await t.app.get(ChatService).purgeExpired();
    expect(r.messages).toBeGreaterThanOrEqual(1);
    expect(await prisma.message.count({ where: { id: old.body.id } })).toBe(0);
    expect(await prisma.message.count({ where: { id: keep.body.id } })).toBe(1);
    expect(existsSync(join(uploads, att.storageKey))).toBe(false);
  });

  it('new messages expire after MESSAGE_TTL_DAYS', async () => {
    const { a, conv } = await pair();
    const m = await t.http().post(`/conversations/${conv}/messages`).set(auth(a)).send({ body: 'ttl' }).expect(201);
    const row = await prisma.message.findUniqueOrThrow({ where: { id: m.body.id } });
    const days = (row.expiresAt.getTime() - row.createdAt.getTime()) / 86_400_000;
    expect(days).toBeCloseTo(30, 1);
  });
});
