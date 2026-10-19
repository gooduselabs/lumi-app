import { Inject, Injectable, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { hash, verify } from '@node-rs/argon2';
import { CodePurpose, User } from '@prisma/client';
import { randomUUID } from 'crypto';
import { APP_ENV, AppEnv } from '../config/env';
import { Errors } from '../common/errors';
import { MailService } from '../mail/mail.service';
import { PrismaService } from '../prisma/prisma.service';
import { toMe } from '../users/user.mapper';
import { CODE_COOLDOWN_MS, CODE_MAX_ATTEMPTS, CODE_TTL_MS, generateCode, hashCode, safeEqualHex } from './codes';

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

export interface CodeSent {
  ok: true;
  email: string;
  /** Present only when DEV_EXPOSE_CODES=true outside production. */
  devCode?: string;
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly mail: MailService,
    @Inject(APP_ENV) private readonly env: AppEnv,
  ) {}

  // ---------- Sign up / verification ----------

  async register(email: string, password: string, locale = 'vi'): Promise<CodeSent> {
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing?.emailVerifiedAt) throw Errors.emailTaken();
    const passwordHash = await hash(password);
    if (existing) {
      await this.prisma.user.update({ where: { id: existing.id }, data: { passwordHash, locale } });
    } else {
      await this.prisma.user.create({ data: { email, passwordHash, locale } });
    }
    return this.issueCode(email, CodePurpose.VERIFY_EMAIL, locale);
  }

  async resendVerification(email: string): Promise<CodeSent> {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user || user.emailVerifiedAt) return { ok: true, email }; // do not leak account state
    return this.issueCode(email, CodePurpose.VERIFY_EMAIL, user.locale);
  }

  async verifyEmail(email: string, code: string, userAgent?: string) {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) throw Errors.invalidCode();
    await this.consumeCode(email, CodePurpose.VERIFY_EMAIL, code);
    const verified = user.emailVerifiedAt
      ? user
      : await this.prisma.user.update({ where: { id: user.id }, data: { emailVerifiedAt: new Date() } });
    return this.session(verified, userAgent);
  }

  // ---------- Login / tokens ----------

  async login(email: string, password: string, userAgent?: string) {
    const user = await this.prisma.user.findUnique({ where: { email } });
    // Always run a hash verification to keep timing uniform.
    const ok = user ? await verify(user.passwordHash, password).catch(() => false) : await this.dummyVerify(password);
    if (!user || !ok) throw Errors.invalidCredentials();
    if (!user.emailVerifiedAt) {
      await this.issueCode(email, CodePurpose.VERIFY_EMAIL, user.locale).catch(() => undefined);
      throw Errors.emailNotVerified();
    }
    return this.session(user, userAgent);
  }

  async refresh(refreshToken: string, userAgent?: string) {
    let payload: { sub: string; jti: string; typ: string };
    try {
      payload = await this.jwt.verifyAsync(refreshToken, { secret: this.env.jwtRefreshSecret });
    } catch {
      throw Errors.invalidRefresh();
    }
    if (payload.typ !== 'refresh') throw Errors.invalidRefresh();
    const stored = await this.prisma.refreshToken.findUnique({ where: { id: payload.jti } });
    if (!stored || stored.userId !== payload.sub) throw Errors.invalidRefresh();
    if (stored.revokedAt) {
      // Token reuse => likely theft. Revoke the whole family.
      this.logger.warn(`Refresh token reuse detected for user ${stored.userId}`);
      await this.revokeAll(stored.userId);
      throw Errors.invalidRefresh();
    }
    if (stored.expiresAt < new Date()) throw Errors.invalidRefresh();
    await this.prisma.refreshToken.update({ where: { id: stored.id }, data: { revokedAt: new Date() } });
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: stored.userId } });
    return this.session(user, userAgent);
  }

  async logout(refreshToken: string): Promise<{ ok: true }> {
    try {
      const payload = await this.jwt.verifyAsync(refreshToken, { secret: this.env.jwtRefreshSecret });
      await this.prisma.refreshToken.updateMany({ where: { id: payload.jti, revokedAt: null }, data: { revokedAt: new Date() } });
    } catch {
      /* already invalid: nothing to do */
    }
    return { ok: true };
  }

  // ---------- Password reset ----------

  async forgotPassword(email: string): Promise<CodeSent> {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) return { ok: true, email };
    return this.issueCode(email, CodePurpose.RESET_PASSWORD, user.locale);
  }

  async resetPassword(email: string, code: string, newPassword: string, userAgent?: string) {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) throw Errors.invalidCode();
    await this.consumeCode(email, CodePurpose.RESET_PASSWORD, code);
    const updated = await this.prisma.user.update({
      where: { id: user.id },
      data: { passwordHash: await hash(newPassword), emailVerifiedAt: user.emailVerifiedAt ?? new Date() },
    });
    await this.revokeAll(user.id);
    return this.session(updated, userAgent);
  }

  // ---------- Internals ----------

  async verifyAccessToken(token: string): Promise<{ id: string }> {
    try {
      const p = await this.jwt.verifyAsync(token, { secret: this.env.jwtAccessSecret });
      if (p.typ !== 'access') throw new Error('wrong type');
      return { id: p.sub };
    } catch {
      throw Errors.unauthorized();
    }
  }

  private async session(user: User, userAgent?: string) {
    const tokens = await this.issueTokens(user.id, userAgent);
    return { ...tokens, user: toMe(user) };
  }

  private async issueTokens(userId: string, userAgent?: string): Promise<TokenPair> {
    const jti = randomUUID();
    const expiresAt = new Date(Date.now() + this.env.jwtRefreshTtlDays * 86400_000);
    await this.prisma.refreshToken.create({ data: { id: jti, userId, expiresAt, userAgent: userAgent?.slice(0, 200) } });
    const accessToken = await this.jwt.signAsync(
      { sub: userId, typ: 'access' },
      { secret: this.env.jwtAccessSecret, expiresIn: this.env.jwtAccessTtl },
    );
    const refreshToken = await this.jwt.signAsync(
      { sub: userId, jti, typ: 'refresh' },
      { secret: this.env.jwtRefreshSecret, expiresIn: `${this.env.jwtRefreshTtlDays}d` },
    );
    return { accessToken, refreshToken, expiresIn: this.env.jwtAccessTtl };
  }

  private async revokeAll(userId: string) {
    await this.prisma.refreshToken.updateMany({ where: { userId, revokedAt: null }, data: { revokedAt: new Date() } });
  }

  private async issueCode(email: string, purpose: CodePurpose, locale = 'vi'): Promise<CodeSent> {
    const last = await this.prisma.emailCode.findFirst({ where: { email, purpose }, orderBy: { createdAt: 'desc' } });
    if (last && Date.now() - last.createdAt.getTime() < CODE_COOLDOWN_MS) {
      throw Errors.codeCooldown(Math.ceil((CODE_COOLDOWN_MS - (Date.now() - last.createdAt.getTime())) / 1000));
    }
    const code = generateCode();
    await this.prisma.$transaction([
      this.prisma.emailCode.updateMany({ where: { email, purpose, consumedAt: null }, data: { consumedAt: new Date() } }),
      this.prisma.emailCode.create({
        data: {
          email,
          purpose,
          codeHash: hashCode(this.env.codeHmacSecret, email, purpose, code),
          expiresAt: new Date(Date.now() + CODE_TTL_MS),
        },
      }),
    ]);
    await this.mail.sendCode(email, code, purpose === CodePurpose.VERIFY_EMAIL ? 'verify' : 'reset', locale);
    return this.env.devExposeCodes ? { ok: true, email, devCode: code } : { ok: true, email };
  }

  private async consumeCode(email: string, purpose: CodePurpose, code: string): Promise<void> {
    const rec = await this.prisma.emailCode.findFirst({
      where: { email, purpose, consumedAt: null },
      orderBy: { createdAt: 'desc' },
    });
    if (!rec || rec.expiresAt < new Date()) throw Errors.invalidCode();
    if (rec.attempts >= CODE_MAX_ATTEMPTS) throw Errors.tooManyAttempts();
    const ok = safeEqualHex(rec.codeHash, hashCode(this.env.codeHmacSecret, email, purpose, code));
    if (!ok) {
      const updated = await this.prisma.emailCode.update({ where: { id: rec.id }, data: { attempts: { increment: 1 } } });
      if (updated.attempts >= CODE_MAX_ATTEMPTS) throw Errors.tooManyAttempts();
      throw Errors.invalidCode();
    }
    await this.prisma.emailCode.update({ where: { id: rec.id }, data: { consumedAt: new Date() } });
  }

  private dummyHash?: string;
  private async dummyVerify(password: string) {
    this.dummyHash ??= await hash('dummy-password-for-timing');
    await verify(this.dummyHash, password).catch(() => false);
    return false;
  }
}
