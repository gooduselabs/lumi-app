import { ageAccepts, clampAgeRange, commonInterests, compatible, pickPartner, QueueEntry } from './match.logic';

const e = (gender: QueueEntry['gender'], pref: QueueEntry['pref'], mode: QueueEntry['mode'] = 'SOUL'): QueueEntry => ({
  userId: Math.random().toString(), mode, gender, pref, at: Date.now(),
});

describe('match logic', () => {
  it('matches anyone when both prefs are ANY', () => {
    expect(compatible(e('MALE', 'ANY'), e('MALE', 'ANY'))).toBe(true);
  });
  it('requires both sides to accept each other', () => {
    expect(compatible(e('MALE', 'FEMALE'), e('FEMALE', 'ANY'))).toBe(true);
    expect(compatible(e('MALE', 'FEMALE'), e('MALE', 'ANY'))).toBe(false);
    expect(compatible(e('MALE', 'ANY'), e('FEMALE', 'FEMALE'))).toBe(false);
    expect(compatible(e('FEMALE', 'MALE'), e('MALE', 'FEMALE'))).toBe(true);
  });
  it('never mixes modes', () => {
    expect(compatible(e('MALE', 'ANY', 'SOUL'), e('MALE', 'ANY', 'VOICE'))).toBe(false);
  });
  it('computes common interests', () => {
    expect(commonInterests(['music', 'art'], ['art', 'tech', 'music'])).toEqual(['art', 'music']);
  });
});

describe('age range', () => {
  const a = (age: number | null, ageMin = 18, ageMax = 99): QueueEntry => ({ ...e('MALE', 'ANY'), age, ageMin, ageMax });
  it('default range accepts everyone, including unknown age', () => {
    expect(compatible(a(20), a(60))).toBe(true);
    expect(compatible(a(null), a(30))).toBe(true);
  });
  it('requires BOTH ranges to accept each other', () => {
    expect(compatible(a(25, 20, 30), a(28, 18, 99))).toBe(true);
    expect(compatible(a(25, 20, 30), a(35))).toBe(false); // I reject them
    expect(compatible(a(40), a(25, 20, 30))).toBe(false); // they reject me
    expect(compatible(a(25, 24, 26), a(26, 25, 25))).toBe(true);
    expect(compatible(a(null), a(25, 20, 30))).toBe(false);
  });
  it('clamps and orders ranges', () => {
    expect(clampAgeRange(10, 200)).toEqual({ min: 18, max: 99 });
    expect(clampAgeRange(40, 30)).toEqual({ min: 30, max: 40 });
    expect(ageAccepts(30, 30, 30)).toBe(true);
  });
});

describe('pickPartner', () => {
  const hcm = { lat: 10.775, lng: 106.705 };
  const at = (loc: { lat: number; lng: number } | null, id: string): QueueEntry => ({ ...e('MALE', 'ANY'), userId: id, loc });
  it('is FIFO without nearby preference', () => {
    const me = at(hcm, 'me');
    expect(pickPartner(me, [at({ lat: 21.03, lng: 105.85 }, 'far'), at(hcm, 'near')])!.userId).toBe('far');
  });
  it('prefers the closest compatible candidate within range', () => {
    const me = { ...at(hcm, 'me'), preferNearby: true };
    const c = [at({ lat: 21.03, lng: 105.85 }, 'hanoi'), at({ lat: 10.8, lng: 106.7 }, 'near3'), at({ lat: 10.776, lng: 106.704 }, 'near0')];
    expect(pickPartner(me, c)!.userId).toBe('near0');
  });
  it('falls back to FIFO when nobody is nearby', () => {
    const me = { ...at(hcm, 'me'), preferNearby: true };
    expect(pickPartner(me, [at(null, 'x'), at({ lat: 21.03, lng: 105.85 }, 'y')])!.userId).toBe('x');
  });
  it('skips incompatible and self', () => {
    const me = { ...at(hcm, 'me'), pref: 'FEMALE' as const };
    expect(pickPartner(me, [at(hcm, 'me'), at(hcm, 'm2')])).toBeNull();
  });
});
