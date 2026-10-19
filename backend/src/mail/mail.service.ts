import { Inject, Injectable, Logger } from '@nestjs/common';
import nodemailer, { Transporter } from 'nodemailer';
import { APP_ENV, AppEnv } from '../config/env';

export type CodeMailKind = 'verify' | 'reset';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private readonly transporter?: Transporter;

  constructor(@Inject(APP_ENV) private readonly env: AppEnv) {
    if (env.smtp.host) {
      this.transporter = nodemailer.createTransport({
        host: env.smtp.host,
        port: env.smtp.port,
        secure: env.smtp.secure,
        auth: env.smtp.user ? { user: env.smtp.user, pass: env.smtp.pass } : undefined,
      });
    }
  }

  async sendCode(to: string, code: string, kind: CodeMailKind, locale = 'vi'): Promise<void> {
    const vi = locale !== 'en';
    const subject =
      kind === 'verify'
        ? vi ? `Mã xác minh Lumi: ${code}` : `Your Lumi verification code: ${code}`
        : vi ? `Mã đặt lại mật khẩu Lumi: ${code}` : `Your Lumi password reset code: ${code}`;
    const line = vi
      ? `Mã của bạn là <b style="font-size:24px;letter-spacing:6px">${code}</b>. Mã có hiệu lực trong 10 phút.`
      : `Your code is <b style="font-size:24px;letter-spacing:6px">${code}</b>. It expires in 10 minutes.`;
    const html = `<div style="font-family:system-ui,sans-serif;padding:24px;background:#0f0b1e;color:#fff;border-radius:16px">
      <h2 style="margin:0 0 12px;color:#b794ff">Lumi</h2><p>${line}</p>
      <p style="color:#9a93b8;font-size:12px">${vi ? 'Nếu bạn không yêu cầu, hãy bỏ qua email này.' : 'If you did not request this, ignore this email.'}</p></div>`;

    if (!this.transporter) {
      this.logger.warn(`[DEV MAIL] to=${to} kind=${kind} code=${code}`);
      return;
    }
    await this.transporter.sendMail({ from: this.env.smtp.from, to, subject, html, text: `${subject}` });
  }
}
