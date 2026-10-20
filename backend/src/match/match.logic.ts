import { Gender } from '@prisma/client';
import { haversineKm, LatLng } from '../common/geo';

export type GenderPref = 'ANY' | 'MALE' | 'FEMALE';

export const AGE_MIN = 18;
export const AGE_MAX = 99;
/** Candidates within this distance are preferred when "prefer nearby" is on. */
export const NEARBY_PREFER_KM = 30;

export interface QueueEntry {
  userId: string;
  mode: 'SOUL' | 'VOICE';
  gender: Gender | null;
  pref: GenderPref;
  at: number;
  /** Own age (null = unknown, never accepted by a narrowed range). */
  age?: number | null;
  ageMin?: number;
  ageMax?: number;
  /** Coarsened location, only when the user shares it. */
  loc?: LatLng | null;
  preferNearby?: boolean;
}

export function clampAgeRange(min?: number, max?: number): { min: number; max: number } {
  const lo = Math.max(AGE_MIN, Math.min(AGE_MAX, Math.round(min ?? AGE_MIN)));
  const hi = Math.max(AGE_MIN, Math.min(AGE_MAX, Math.round(max ?? AGE_MAX)));
  return lo <= hi ? { min: lo, max: hi } : { min: hi, max: lo };
}

/** Does a range accept this age? Full range accepts anyone, even with unknown age. */
export function ageAccepts(min: number | undefined, max: number | undefined, age: number | null | undefined): boolean {
  const r = clampAgeRange(min, max);
  if (r.min === AGE_MIN && r.max === AGE_MAX) return true;
  return age != null && age >= r.min && age <= r.max;
}

/** Both users' gender AND age preferences must accept each other. */
export function compatible(a: QueueEntry, b: QueueEntry): boolean {
  const accepts = (who: QueueEntry, other: QueueEntry) =>
    (who.pref === 'ANY' || who.pref === other.gender) && ageAccepts(who.ageMin, who.ageMax, other.age);
  return a.mode === b.mode && accepts(a, b) && accepts(b, a);
}

export function distanceKm(a: QueueEntry, b: QueueEntry): number | null {
  return a.loc && b.loc ? haversineKm(a.loc, b.loc) : null;
}

/**
 * Choose a partner among compatible waiting entries (queue order = FIFO).
 * When `me` prefers nearby and shares a location, the closest candidate within
 * NEARBY_PREFER_KM wins; otherwise the longest-waiting compatible one.
 */
export function pickPartner(me: QueueEntry, candidates: QueueEntry[]): QueueEntry | null {
  const ok = candidates.filter((c) => c.userId !== me.userId && compatible(me, c));
  if (!ok.length) return null;
  if (me.preferNearby && me.loc) {
    let best: QueueEntry | null = null;
    let bestKm = Infinity;
    for (const c of ok) {
      const d = distanceKm(me, c);
      if (d != null && d <= NEARBY_PREFER_KM && d < bestKm) {
        best = c;
        bestKm = d;
      }
    }
    if (best) return best;
  }
  return ok[0];
}

export function commonInterests(a: string[], b: string[]): string[] {
  const set = new Set(a);
  return b.filter((x) => set.has(x));
}
