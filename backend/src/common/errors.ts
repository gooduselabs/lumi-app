import { HttpException, HttpStatus } from '@nestjs/common';

/** API errors always carry a stable machine-readable `code` the app can translate. */
export class ApiError extends HttpException {
  constructor(status: HttpStatus, code: string, message: string, extra: Record<string, unknown> = {}) {
    super({ statusCode: status, code, message, ...extra }, status);
  }
}

export const Errors = {
  emailTaken: () => new ApiError(HttpStatus.CONFLICT, 'EMAIL_TAKEN', 'Email already registered'),
  invalidCredentials: () => new ApiError(HttpStatus.UNAUTHORIZED, 'INVALID_CREDENTIALS', 'Wrong email or password'),
  emailNotVerified: () => new ApiError(HttpStatus.FORBIDDEN, 'EMAIL_NOT_VERIFIED', 'Email not verified'),
  invalidCode: () => new ApiError(HttpStatus.BAD_REQUEST, 'INVALID_CODE', 'Invalid or expired code'),
  tooManyAttempts: () => new ApiError(HttpStatus.TOO_MANY_REQUESTS, 'TOO_MANY_ATTEMPTS', 'Too many attempts, request a new code'),
  codeCooldown: (retryAfter: number) =>
    new ApiError(HttpStatus.TOO_MANY_REQUESTS, 'CODE_COOLDOWN', 'Please wait before requesting a new code', { retryAfter }),
  invalidRefresh: () => new ApiError(HttpStatus.UNAUTHORIZED, 'INVALID_REFRESH_TOKEN', 'Session expired'),
  unauthorized: () => new ApiError(HttpStatus.UNAUTHORIZED, 'UNAUTHORIZED', 'Unauthorized'),
  underage: () => new ApiError(HttpStatus.BAD_REQUEST, 'UNDERAGE', 'You must be 18 or older'),
  notOnboarded: () => new ApiError(HttpStatus.FORBIDDEN, 'NOT_ONBOARDED', 'Complete your profile first'),
  notFound: (what = 'Resource') => new ApiError(HttpStatus.NOT_FOUND, 'NOT_FOUND', `${what} not found`),
  forbidden: (msg = 'Forbidden') => new ApiError(HttpStatus.FORBIDDEN, 'FORBIDDEN', msg),
  blocked: () => new ApiError(HttpStatus.FORBIDDEN, 'BLOCKED', 'You cannot interact with this user'),
  inSession: () => new ApiError(HttpStatus.CONFLICT, 'ALREADY_IN_SESSION', 'Already in a match session'),
  sessionClosed: () => new ApiError(HttpStatus.CONFLICT, 'SESSION_CLOSED', 'This match session has ended'),
  voiceUnavailable: () => new ApiError(HttpStatus.SERVICE_UNAVAILABLE, 'VOICE_UNAVAILABLE', 'Voice server not configured'),
  badRequest: (code: string, msg: string) => new ApiError(HttpStatus.BAD_REQUEST, code, msg),
};
