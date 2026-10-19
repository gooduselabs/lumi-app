import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import 'network/api_exception.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension AppLocalizationsX on AppLocalizations {
  /// Maps any error to a friendly, localized message.
  String errorText(Object error) {
    if (error is! ApiException) return somethingWrong;
    return switch (error.code) {
      'NETWORK' => errNetwork,
      'INVALID_CREDENTIALS' => errInvalidCredentials,
      'EMAIL_TAKEN' => errEmailTaken,
      'INVALID_CODE' => errInvalidCode,
      'TOO_MANY_ATTEMPTS' => errTooManyAttempts,
      'CODE_COOLDOWN' => errCooldown(error.retryAfter ?? 60),
      'INVALID_REFRESH_TOKEN' || 'UNAUTHORIZED' => errSession,
      'UNDERAGE' => underageError,
      'RATE_LIMITED' || 'ThrottlerException' || 'HTTP_429' => errRateLimited,
      'SESSION_CLOSED' => errSessionClosed,
      'BLOCKED' => errBlocked,
      'VOICE_UNAVAILABLE' => voiceUnavailable,
      'VALIDATION' => error.message,
      _ => error.message.isNotEmpty ? error.message : somethingWrong,
    };
  }

  String interest(String key) => switch (key) {
        'music' => interest_music,
        'movies' => interest_movies,
        'gaming' => interest_gaming,
        'travel' => interest_travel,
        'food' => interest_food,
        'sports' => interest_sports,
        'reading' => interest_reading,
        'anime' => interest_anime,
        'photography' => interest_photography,
        'art' => interest_art,
        'tech' => interest_tech,
        'pets' => interest_pets,
        'fitness' => interest_fitness,
        'coffee' => interest_coffee,
        'fashion' => interest_fashion,
        'kpop' => interest_kpop,
        'astrology' => interest_astrology,
        'dance' => interest_dance,
        'nature' => interest_nature,
        'study' => interest_study,
        _ => key,
      };

  String genderLabel(String? g) => switch (g) {
        'MALE' => genderMale,
        'FEMALE' => genderFemale,
        'OTHER' => genderOther,
        _ => '',
      };
}

const kInterestKeys = [
  'music', 'movies', 'gaming', 'travel', 'food', 'sports', 'reading', 'anime', 'photography', 'art',
  'tech', 'pets', 'fitness', 'coffee', 'fashion', 'kpop', 'astrology', 'dance', 'nature', 'study',
];

const kInterestEmoji = {
  'music': '🎧', 'movies': '🎬', 'gaming': '🎮', 'travel': '✈️', 'food': '🍜', 'sports': '⚽', 'reading': '📚',
  'anime': '🌸', 'photography': '📷', 'art': '🎨', 'tech': '💻', 'pets': '🐾', 'fitness': '💪', 'coffee': '☕',
  'fashion': '👗', 'kpop': '💜', 'astrology': '🔮', 'dance': '💃', 'nature': '🌿', 'study': '📝',
};
