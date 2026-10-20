import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import Redis from 'ioredis';
import { AddressInfo } from 'net';
import { io, Socket } from 'socket.io-client';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/bootstrap';
import { REDIS } from '../src/redis/redis.module';

export interface TestApp {
  app: INestApplication;
  url: string;
  http: () => ReturnType<typeof request>;
  redis: Redis;
}

export async function bootApp(): Promise<TestApp> {
  const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
  const app = mod.createNestApplication({ logger: ['error'] });
  configureApp(app, { swagger: false });
  await app.listen(0, '127.0.0.1');
  const { port } = app.getHttpServer().address() as AddressInfo;
  const redis = app.get<Redis>(REDIS);
  await redis.flushdb();
  return { app, url: `http://127.0.0.1:${port}`, http: () => request(app.getHttpServer()), redis };
}

let seq = 0;
export const uniqueEmail = (p = 'u') => `${p}${Date.now()}${++seq}@test.lumi`;

export interface TestUser {
  id: string;
  email: string;
  token: string;
  refreshToken: string;
}

export async function createUser(
  t: TestApp,
  profile: Partial<{ nickname: string; gender: 'MALE' | 'FEMALE' | 'OTHER'; interests: string[]; birthday: string }> = {},
): Promise<TestUser> {
  const email = uniqueEmail();
  const reg = await t.http().post('/auth/register').send({ email, password: 'Passw0rd!' }).expect(201);
  const ver = await t.http().post('/auth/verify-email').send({ email, code: reg.body.devCode }).expect(200);
  const token = ver.body.accessToken;
  await t
    .http()
    .put('/me/onboarding')
    .set('Authorization', `Bearer ${token}`)
    .send({
      nickname: profile.nickname ?? 'Tester',
      gender: profile.gender ?? 'MALE',
      birthday: profile.birthday ?? '1999-04-12',
      avatarId: 'a05',
      bio: 'hello',
      interests: profile.interests ?? ['music', 'travel'],
    })
    .expect(200);
  return { id: ver.body.user.id, email, token, refreshToken: ver.body.refreshToken };
}

export function connect(t: TestApp, token: string): Promise<Socket> {
  return new Promise((resolve, reject) => {
    const s = io(t.url, { auth: { token }, transports: ['websocket'], forceNew: true, reconnection: false });
    s.once('ready', () => resolve(s));
    s.once('connect_error', reject);
    s.once('auth_error', () => reject(new Error('auth_error')));
  });
}

export function once<T = any>(s: Socket, event: string, timeoutMs = 9000): Promise<T> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`timeout waiting for ${event}`)), timeoutMs);
    s.once(event, (data: T) => {
      clearTimeout(timer);
      resolve(data);
    });
  });
}

export const emit = <T = any>(s: Socket, event: string, payload?: unknown): Promise<T> =>
  s.timeout(5000).emitWithAck(event, payload ?? {}) as Promise<T>;
