import { Gender } from '@prisma/client';

export type GenderPref = 'ANY' | 'MALE' | 'FEMALE';

export interface QueueEntry {
  userId: string;
  mode: 'SOUL' | 'VOICE';
  gender: Gender | null;
  pref: GenderPref;
  at: number;
}

/** Both users' gender preferences must accept each other. */
export function compatible(a: QueueEntry, b: QueueEntry): boolean {
  const accepts = (who: QueueEntry, other: QueueEntry) => who.pref === 'ANY' || who.pref === other.gender;
  return a.mode === b.mode && accepts(a, b) && accepts(b, a);
}

export function commonInterests(a: string[], b: string[]): string[] {
  const set = new Set(a);
  return b.filter((x) => set.has(x));
}
