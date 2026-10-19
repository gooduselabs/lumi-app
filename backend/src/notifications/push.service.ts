import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Push notification stub. Wire firebase-admin here when FCM_SERVICE_ACCOUNT_JSON is provided.
 * The app already registers `fcmToken` via PATCH /me.
 */
@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);
  private readonly enabled = !!process.env.FCM_SERVICE_ACCOUNT_JSON;

  constructor(private readonly prisma: PrismaService) {}

  async notify(userId: string, title: string, body: string, data: Record<string, string> = {}) {
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { fcmToken: true } });
    if (!user?.fcmToken) return;
    if (!this.enabled) {
      this.logger.debug(`[PUSH STUB] -> ${userId}: ${title} | ${body} ${JSON.stringify(data)}`);
      return;
    }
    // TODO(push): firebase-admin messaging().send({ token: user.fcmToken, notification: { title, body }, data })
  }
}
