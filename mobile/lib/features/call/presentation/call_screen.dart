import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lumi_avatar.dart';
import '../../match/presentation/voice_call_panel.dart';
import '../application/call_controller.dart';

/// Full-screen 1-1 friend voice call: outgoing ringing, incoming, active, ended.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key, this.conversationId});
  /// When set, starts an outgoing call to this conversation's friend.
  final String? conversationId;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  Timer? _close;

  @override
  void initState() {
    super.initState();
    final id = widget.conversationId;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(callControllerProvider.notifier).startCall(id));
    }
  }

  @override
  void dispose() {
    _close?.cancel();
    super.dispose();
  }

  void _leaveSoon() {
    _close ??= Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      ref.read(callControllerProvider.notifier).reset();
      if (context.canPop()) context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(callControllerProvider);
    final ctrl = ref.read(callControllerProvider.notifier);
    if (s.phase == CallPhase.ended) _leaveSoon();
    final peer = s.peer;
    final name = peer?.nickname ?? '';

    final Widget body = switch (s.phase) {
      CallPhase.active => VoiceCallPanel(
          key: ValueKey(s.callId),
          voice: s.voice,
          avatarId: peer?.avatarId ?? 'a01',
          title: name,
          onHangUp: ctrl.hangUp,
          onPeerLeft: () => ctrl.hangUp(),
        ),
      _ => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          LumiAvatar(avatarId: peer?.avatarId ?? 'a01', size: 150, ring: true),
          const SizedBox(height: 18),
          Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(
            switch (s.phase) {
              CallPhase.incoming => l.incomingCallFrom(name),
              CallPhase.ended => switch (s.endReason) {
                  'DECLINED' => l.callDeclined,
                  'NO_ANSWER' => l.callNoAnswer,
                  'ERROR' => s.error != null ? l.errorText(s.error!) : l.callEnded,
                  _ => l.callEnded,
                },
              _ => l.calling,
            },
            style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
          ),
          const SizedBox(height: 48),
          if (s.phase == CallPhase.incoming)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              RoundCallButton(icon: Icons.call_end_rounded, label: l.decline, active: true, danger: true, onTap: ctrl.decline),
              const SizedBox(width: 64),
              RoundCallButton(icon: Icons.call_rounded, label: l.accept, active: true, success: true, onTap: ctrl.accept),
            ])
          else if (s.phase == CallPhase.outgoing || s.phase == CallPhase.idle)
            RoundCallButton(icon: Icons.call_end_rounded, label: l.hangUp, active: true, danger: true, onTap: () => ctrl.hangUp(reason: 'CANCELLED')),
        ]),
    };

    return PopScope(
      canPop: s.phase == CallPhase.ended || s.phase == CallPhase.idle,
      child: Scaffold(
        body: GlowBackground(
          intensity: 1,
          child: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textFaint),
                  const SizedBox(width: 6),
                  Text(s.phase == CallPhase.incoming ? l.incomingCall : l.callVoice, style: const TextStyle(color: AppColors.textFaint)),
                ]),
              ),
              Expanded(child: body),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ),
    );
  }
}
