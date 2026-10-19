import { generateCode, hashCode, safeEqualHex } from './codes';
import { ageOn, isAdult } from '../common/age';

describe('verification codes', () => {
  it('are 6 digits', () => {
    for (let i = 0; i < 200; i++) expect(generateCode()).toMatch(/^\d{6}$/);
  });
  it('hash is bound to email and purpose', () => {
    const a = hashCode('s', 'x@y.z', 'VERIFY_EMAIL', '123456');
    expect(safeEqualHex(a, hashCode('s', 'x@y.z', 'VERIFY_EMAIL', '123456'))).toBe(true);
    expect(safeEqualHex(a, hashCode('s', 'x@y.z', 'RESET_PASSWORD', '123456'))).toBe(false);
    expect(safeEqualHex(a, hashCode('s', 'o@y.z', 'VERIFY_EMAIL', '123456'))).toBe(false);
  });
});

describe('age gate', () => {
  const now = new Date('2026-10-19T00:00:00Z');
  it('computes age on birthday boundaries', () => {
    expect(ageOn(new Date('2008-10-19T00:00:00Z'), now)).toBe(18);
    expect(ageOn(new Date('2008-10-20T00:00:00Z'), now)).toBe(17);
    expect(isAdult(new Date('2008-10-20T00:00:00Z'), now)).toBe(false);
    expect(isAdult(new Date('1990-01-01T00:00:00Z'), now)).toBe(true);
  });
});
