import { bootApp, TestApp, uniqueEmail } from './helpers';

describe('Auth (e2e)', () => {
  let t: TestApp;
  beforeAll(async () => (t = await bootApp()));
  afterAll(async () => t.app.close());

  it('register -> verify -> login -> me', async () => {
    const email = uniqueEmail('Auth.').toUpperCase();
    const reg = await t.http().post('/auth/register').send({ email, password: 'Passw0rd!' }).expect(201);
    expect(reg.body.email).toBe(email.toLowerCase());
    expect(reg.body.devCode).toMatch(/^\d{6}$/);

    const blocked = await t.http().post('/auth/login').send({ email, password: 'Passw0rd!' }).expect(403);
    expect(blocked.body.code).toBe('EMAIL_NOT_VERIFIED');

    const wrongCode = reg.body.devCode === '000000' ? '111111' : '000000';
    const bad = await t.http().post('/auth/verify-email').send({ email, code: wrongCode }).expect(400);
    expect(bad.body.code).toBe('INVALID_CODE');

    const ok = await t.http().post('/auth/verify-email').send({ email, code: reg.body.devCode }).expect(200);
    expect(ok.body.accessToken).toBeDefined();
    expect(ok.body.user.emailVerified).toBe(true);
    expect(ok.body.user.onboarded).toBe(false);

    // the code cannot be reused
    await t.http().post('/auth/verify-email').send({ email, code: reg.body.devCode }).expect(400);

    const dup = await t.http().post('/auth/register').send({ email, password: 'Passw0rd!' }).expect(409);
    expect(dup.body.code).toBe('EMAIL_TAKEN');

    const wrongPw = await t.http().post('/auth/login').send({ email, password: 'nope1234' }).expect(401);
    expect(wrongPw.body.code).toBe('INVALID_CREDENTIALS');

    const login = await t.http().post('/auth/login').send({ email, password: 'Passw0rd!' }).expect(200);
    const me = await t.http().get('/me').set('Authorization', `Bearer ${login.body.accessToken}`).expect(200);
    expect(me.body.email).toBe(email.toLowerCase());
    expect(me.body).not.toHaveProperty('passwordHash');
  });

  it('rejects weak passwords and invalid emails', async () => {
    await t.http().post('/auth/register').send({ email: 'not-an-email', password: 'Passw0rd!' }).expect(400);
    await t.http().post('/auth/register').send({ email: uniqueEmail(), password: 'short1' }).expect(400);
    await t.http().post('/auth/register').send({ email: uniqueEmail(), password: 'onlyletters' }).expect(400);
  });

  it('requires auth on protected routes', async () => {
    await t.http().get('/me').expect(401);
    await t.http().get('/me').set('Authorization', 'Bearer garbage').expect(401);
  });

  it('enforces resend cooldown and attempt limit', async () => {
    const email = uniqueEmail();
    const reg = await t.http().post('/auth/register').send({ email, password: 'Passw0rd!' }).expect(201);
    const cd = await t.http().post('/auth/resend-code').send({ email }).expect(429);
    expect(cd.body.code).toBe('CODE_COOLDOWN');
    const wrong = reg.body.devCode === '999999' ? '888888' : '999999';
    for (let i = 0; i < 4; i++) await t.http().post('/auth/verify-email').send({ email, code: wrong }).expect(400);
    const locked = await t.http().post('/auth/verify-email').send({ email, code: wrong }).expect(429);
    expect(locked.body.code).toBe('TOO_MANY_ATTEMPTS');
    // even the right code is refused once locked
    await t.http().post('/auth/verify-email').send({ email, code: reg.body.devCode }).expect(429);
  });

  it('refresh rotates tokens and detects reuse', async () => {
    const email = uniqueEmail();
    const reg = await t.http().post('/auth/register').send({ email, password: 'Passw0rd!' });
    const v = await t.http().post('/auth/verify-email').send({ email, code: reg.body.devCode }).expect(200);
    const r1 = await t.http().post('/auth/refresh').send({ refreshToken: v.body.refreshToken }).expect(200);
    expect(r1.body.refreshToken).not.toBe(v.body.refreshToken);
    // reusing the old token revokes the whole family
    await t.http().post('/auth/refresh').send({ refreshToken: v.body.refreshToken }).expect(401);
    await t.http().post('/auth/refresh').send({ refreshToken: r1.body.refreshToken }).expect(401);
  });

  it('logout revokes the refresh token', async () => {
    const email = uniqueEmail();
    const reg = await t.http().post('/auth/register').send({ email, password: 'Passw0rd!' });
    const v = await t.http().post('/auth/verify-email').send({ email, code: reg.body.devCode }).expect(200);
    await t.http().post('/auth/logout').send({ refreshToken: v.body.refreshToken }).expect(200);
    await t.http().post('/auth/refresh').send({ refreshToken: v.body.refreshToken }).expect(401);
  });

  it('forgot password -> reset with code -> login with new password', async () => {
    const email = uniqueEmail();
    const reg = await t.http().post('/auth/register').send({ email, password: 'Passw0rd!' });
    await t.http().post('/auth/verify-email').send({ email, code: reg.body.devCode }).expect(200);

    const unknown = await t.http().post('/auth/forgot-password').send({ email: uniqueEmail() }).expect(200);
    expect(unknown.body.devCode).toBeUndefined(); // no account enumeration

    const f = await t.http().post('/auth/forgot-password').send({ email }).expect(200);
    expect(f.body.devCode).toMatch(/^\d{6}$/);
    await t.http().post('/auth/reset-password').send({ email, code: f.body.devCode, newPassword: 'N3wPassword' }).expect(200);
    await t.http().post('/auth/login').send({ email, password: 'Passw0rd!' }).expect(401);
    await t.http().post('/auth/login').send({ email, password: 'N3wPassword' }).expect(200);
  });

  it('onboarding enforces 18+ and validates fields', async () => {
    const email = uniqueEmail();
    const reg = await t.http().post('/auth/register').send({ email, password: 'Passw0rd!' });
    const v = await t.http().post('/auth/verify-email').send({ email, code: reg.body.devCode });
    const auth = { Authorization: `Bearer ${v.body.accessToken}` };
    const base = { nickname: 'Hải', gender: 'MALE', avatarId: 'a01', interests: ['music'] };
    const young = new Date();
    young.setUTCFullYear(young.getUTCFullYear() - 17);
    const u = await t.http().put('/me/onboarding').set(auth).send({ ...base, birthday: young.toISOString().slice(0, 10) }).expect(400);
    expect(u.body.code).toBe('UNDERAGE');
    await t.http().put('/me/onboarding').set(auth).send({ ...base, birthday: '2000-01-01', avatarId: 'zz' }).expect(400);
    await t.http().put('/me/onboarding').set(auth).send({ ...base, birthday: '2000-01-01', interests: ['hacking'] }).expect(400);
    const ok = await t.http().put('/me/onboarding').set(auth).send({ ...base, birthday: '2000-01-01' }).expect(200);
    expect(ok.body.onboarded).toBe(true);
    expect(ok.body.age).toBeGreaterThanOrEqual(18);
  });
});
