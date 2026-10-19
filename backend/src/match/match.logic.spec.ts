import { commonInterests, compatible, QueueEntry } from './match.logic';

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
