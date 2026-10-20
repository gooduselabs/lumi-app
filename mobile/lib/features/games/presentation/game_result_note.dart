import 'package:flutter/material.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/game_models.dart';
import 'game_common.dart';

/// Chat bubble for the SYSTEM `GAME:{…}` note posted when a game ends.
class GameResultNote extends StatelessWidget {
  const GameResultNote({super.key, required this.result, required this.meId, required this.peerName, this.onPlay});
  final GameResult result;
  final String? meId;
  final String peerName;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = result;
    final peerId = r.players.firstWhere((p) => p != meId, orElse: () => '');
    final my = r.scores[meId] ?? 0;
    final their = r.scores[peerId] ?? 0;
    return Center(
      child: Container(
        key: const Key('game-note'),
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(gradient: r.kind.gradient, borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: Text(r.kind.emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.kind.title(l), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(outcomeText(l, r, meId: meId ?? '', peerName: peerName), style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              if (r.kind != GameKind.knowMe)
                Text('${l.gameScoreLine} $my – $their', style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
            ]),
          ),
          if (onPlay != null) IconButton(tooltip: l.gameRematch, onPressed: onPlay, icon: const Icon(Icons.replay_rounded, color: AppColors.pink)),
        ]),
      ),
    );
  }
}
