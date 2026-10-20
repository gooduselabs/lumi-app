import { loadEnv } from '../config/env';

let cached: number | undefined;
/** Message TTL in ms (MESSAGE_TTL_DAYS, default 30). */
export function messageTtlMs(): number {
  if (cached === undefined) {
    try {
      cached = loadEnv().messageTtlDays * 86_400_000;
    } catch {
      cached = 30 * 86_400_000;
    }
  }
  return cached;
}
