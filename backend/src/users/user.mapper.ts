import { User } from '@prisma/client';
import { ageOn } from '../common/age';

export function toMe(u: User) {
  return {
    id: u.id,
    email: u.email,
    emailVerified: !!u.emailVerifiedAt,
    nickname: u.nickname,
    gender: u.gender,
    birthday: u.birthday ? u.birthday.toISOString().slice(0, 10) : null,
    age: u.birthday ? ageOn(u.birthday) : null,
    avatarId: u.avatarId,
    bio: u.bio,
    interests: u.interests,
    locale: u.locale,
    onboarded: !!u.onboardedAt,
    agePrefMin: u.agePrefMin,
    agePrefMax: u.agePrefMax,
    // Only whether a (coarsened) location is on file; coordinates are never echoed back.
    hasLocation: u.latCoarse != null && u.lngCoarse != null,
    locationHidden: u.locationHidden,
    locationAt: u.locationAt,
    createdAt: u.createdAt,
  };
}

export type PublicUser = ReturnType<typeof toPublic>;

export function toPublic(u: Pick<User, 'id' | 'nickname' | 'gender' | 'birthday' | 'avatarId' | 'bio' | 'interests' | 'lastSeenAt'>) {
  return {
    id: u.id,
    nickname: u.nickname ?? 'Lumi',
    gender: u.gender,
    age: u.birthday ? ageOn(u.birthday) : null,
    avatarId: u.avatarId ?? 'a01',
    bio: u.bio,
    interests: u.interests,
    lastSeenAt: u.lastSeenAt,
  };
}

export const publicSelect = {
  id: true, nickname: true, gender: true, birthday: true, avatarId: true, bio: true, interests: true, lastSeenAt: true,
} as const;
