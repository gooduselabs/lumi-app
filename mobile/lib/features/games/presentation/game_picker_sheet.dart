import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lumi_avatar.dart';
import '../application/games_controller.dart';
import '../domain/game_models.dart';
import 'game_common.dart';

Future<void> showGamePicker(BuildContext context, {required String conversationId, required String peerName, String? peerAvatar}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => GamePickerSheet(conversationId: conversationId, peerName: peerName, peerAvatar: peerAvatar),
    );

class GamePickerSheet extends ConsumerStatefulWidget {
  const GamePickerSheet({super.key, required this.conversationId, required this.peerName, this.peerAvatar});
  final String conversationId;
  final String peerName;
  final String? peerAvatar;
  @override
  ConsumerState<GamePickerSheet> createState() => _GamePickerSheetState();
}

class _GamePickerSheetState extends ConsumerState<GamePickerSheet> {
  GameKind? _sending;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _invite(GameKind k) async {
    setState(() => _sending = k);
    try {
      await ref.read(gamesControllerProvider.notifier).invite(widget.conversationId, k);
    } catch (e) {
      if (mounted) showSnack(context, context.l10n.errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final st = ref.watch(gamesControllerProvider);
    // The game started -> the shell navigates; just close the sheet.
    ref.listen(gamesControllerProvider.select((s) => s.game?.id), (prev, next) {
      if (next != null && next != prev && Navigator.of(context).canPop()) Navigator.of(context).pop();
    });
    final out = st.outgoing;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.stroke, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            LumiAvatar(avatarId: widget.peerAvatar, size: 40),
            const SizedBox(width: 12),
            Expanded(child: Text(l.gamePickTitle(widget.peerName), style: Theme.of(context).textTheme.titleLarge)),
          ]),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: out == null
                ? GridView.count(
                    key: const ValueKey('grid'),
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.92,
                    children: [
                      for (final k in GameKind.values)
                        _GameCard(kind: k, loading: _sending == k, onTap: _sending == null ? () => _invite(k) : null),
                    ],
                  )
                : _Waiting(key: const ValueKey('wait'), invite: out, peerName: widget.peerName),
          ),
        ]),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.kind, required this.onTap, this.loading = false});
  final GameKind kind;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('game-${kind.wire}'),
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: AppColors.surface,
            border: Border.all(color: AppColors.stroke),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(gradient: kind.gradient, borderRadius: BorderRadius.circular(16)),
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(kind.emoji, style: const TextStyle(fontSize: 26)),
            ),
            const Spacer(),
            Text(kind.title(l), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            Text(kind.subtitle(l), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.3)),
          ]),
        ),
      ),
    );
  }
}

class _Waiting extends ConsumerWidget {
  const _Waiting({super.key, required this.invite, required this.peerName});
  final PendingInvite invite;
  final String peerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final left = invite.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 60);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(children: [
        _Pulse(child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(gradient: invite.kind.gradient, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(invite.kind.emoji, style: const TextStyle(fontSize: 40)),
        )),
        const SizedBox(height: 18),
        Text(invite.kind.title(l), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 6),
        Text(
          invite.declined ? l.gameDeclined(peerName) : '${l.gameInviteSent(peerName)}  ${left}s',
          style: TextStyle(color: invite.declined ? AppColors.amber : AppColors.textMuted),
        ),
        const SizedBox(height: 18),
        OutlinedButton(onPressed: () => ref.read(gamesControllerProvider.notifier).cancelInvite(), child: Text(invite.declined ? l.games : l.gameCancel)),
      ]),
    );
  }
}

/// Soft breathing glow used while waiting.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.scale(
          scale: 1 + 0.06 * Curves.easeInOut.transform(_c.value),
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
              BoxShadow(color: AppColors.pink.withValues(alpha: 0.2 + 0.3 * _c.value), blurRadius: 30, spreadRadius: 4),
            ]),
            child: child,
          ),
        ),
        child: widget.child,
      );
}

/// Incoming invite: shown by the home shell.
Future<void> showGameInviteDialog(BuildContext context, WidgetRef ref, GameInvite i) async {
  final l = context.l10n;
  final accept = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bgElevated,
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, children: [
          LumiAvatar(avatarId: i.from.avatarId, size: 76, ring: true),
          Positioned(
            right: -8,
            bottom: -6,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(gradient: i.kind.gradient, shape: BoxShape.circle, border: Border.all(color: AppColors.bgElevated, width: 3)),
              alignment: Alignment.center,
              child: Text(i.kind.emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        Text(l.gameInvitedYou(i.from.nickname), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text(i.kind.title(l), textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(i.kind.subtitle(l), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textFaint, fontSize: 13)),
      ]),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(key: const Key('game-decline'), onPressed: () => Navigator.pop(ctx, false), child: Text(l.gameDecline)),
        FilledButton(key: const Key('game-accept'), onPressed: () => Navigator.pop(ctx, true), child: Text(l.gameAccept)),
      ],
    ),
  );
  if (accept == null && !context.mounted) return;
  try {
    await ref.read(gamesControllerProvider.notifier).respond(i, accept ?? false);
  } catch (e) {
    if (context.mounted) showSnack(context, context.l10n.errorText(e), error: true);
  }
}
