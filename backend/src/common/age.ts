export function ageOn(birthday: Date, now = new Date()): number {
  let age = now.getUTCFullYear() - birthday.getUTCFullYear();
  const m = now.getUTCMonth() - birthday.getUTCMonth();
  if (m < 0 || (m === 0 && now.getUTCDate() < birthday.getUTCDate())) age--;
  return age;
}

export const MIN_AGE = 18;
export const isAdult = (birthday: Date, now = new Date()) => ageOn(birthday, now) >= MIN_AGE;
