/** Avatars are generated client-side from these ids (original vector art, no external assets). */
export const AVATAR_IDS = Array.from({ length: 24 }, (_, i) => `a${String(i + 1).padStart(2, '0')}`);

export const INTERESTS = [
  'music', 'movies', 'gaming', 'travel', 'food', 'sports', 'reading', 'anime', 'photography', 'art',
  'tech', 'pets', 'fitness', 'coffee', 'fashion', 'kpop', 'astrology', 'dance', 'nature', 'study',
] as const;

export const MAX_INTERESTS = 8;
