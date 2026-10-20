import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/game_models.dart';

extension GameKindUi on GameKind {
  String title(AppLocalizations l) => switch (this) {
        GameKind.truthDare => l.gameTruthDare,
        GameKind.knowMe => l.gameKnowMe,
        GameKind.caro => l.gameCaro,
        GameKind.draw => l.gameDraw,
      };
  String subtitle(AppLocalizations l) => switch (this) {
        GameKind.truthDare => l.gameTruthDareDesc,
        GameKind.knowMe => l.gameKnowMeDesc,
        GameKind.caro => l.gameCaroDesc,
        GameKind.draw => l.gameDrawDesc,
      };
  String get emoji => switch (this) {
        GameKind.truthDare => '🎡',
        GameKind.knowMe => '💞',
        GameKind.caro => '⭕',
        GameKind.draw => '🎨',
      };
  Gradient get gradient => switch (this) {
        GameKind.truthDare => AppColors.warmGradient,
        GameKind.knowMe => AppColors.primaryGradient,
        GameKind.caro => AppColors.coolGradient,
        GameKind.draw => const LinearGradient(colors: [Color(0xFF4BE3A4), Color(0xFF3DDCFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      };
}

/// Localized pick of a `{vi, en}` map coming from the server content packs.
String bi(BuildContext context, Object? m) {
  if (m is! Map) return '';
  final lang = Localizations.localeOf(context).languageCode;
  return (m[lang] ?? m['vi'] ?? m['en'] ?? '').toString();
}

String compatTier(AppLocalizations l, int pct) => pct >= 80
    ? l.kmTier1
    : pct >= 60
        ? l.kmTier2
        : pct >= 35
            ? l.kmTier3
            : l.kmTier4;

/// "You win" / "Mai wins" / tie / forfeit line for a result, from the viewer's perspective.
String outcomeText(AppLocalizations l, GameResult r, {required String meId, required String peerName}) {
  if (r.reason == 'forfeit' && r.winnerId == meId) return l.gameForfeit(peerName);
  if (r.reason == 'abandoned' && r.winnerId == meId) return l.gameAbandoned(peerName);
  if (r.kind == GameKind.knowMe && r.compatibility != null) return '${l.kmCompat} ${r.compatibility}% · ${compatTier(l, r.compatibility!)}';
  if (r.winnerId == null) return l.gameTie;
  return r.winnerId == meId ? l.gameYouWin : l.gamePeerWins(peerName);
}

/// Pill showing whose turn it is, animating between states.
class TurnPill extends StatelessWidget {
  const TurnPill({super.key, required this.text, required this.active});
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: active ? AppColors.primaryGradient : null,
          color: active ? null : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
          boxShadow: active ? [BoxShadow(color: AppColors.pink.withValues(alpha: 0.35), blurRadius: 16)] : null,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(text, key: ValueKey(text), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      );
}
