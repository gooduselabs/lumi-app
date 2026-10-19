import { Injectable } from '@nestjs/common';
import type { Server } from 'socket.io';

export const userRoom = (userId: string) => `user:${userId}`;

/**
 * Thin wrapper over the Socket.IO server so domain services can push events
 * without depending on the gateway (avoids circular deps).
 * Scaling note: add @socket.io/redis-adapter to fan out across API instances.
 */
@Injectable()
export class RealtimeEmitter {
  private server?: Server;

  attach(server: Server) {
    this.server = server;
  }

  toUser(userId: string, event: string, payload: unknown) {
    this.server?.to(userRoom(userId)).emit(event, payload);
  }

  onlineCount(): number {
    return this.server?.engine?.clientsCount ?? 0;
  }

  isOnline(userId: string): boolean {
    const room = this.server?.sockets?.adapter?.rooms?.get(userRoom(userId));
    return !!room && room.size > 0;
  }
}
