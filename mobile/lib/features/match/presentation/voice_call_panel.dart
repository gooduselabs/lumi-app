import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/lumi_avatar.dart';
import '../domain/match_models.dart';

/// Audio-only 1-1 call over LiveKit (WebRTC). Token/room come from the match session.
class VoiceCallPanel extends StatefulWidget {
  const VoiceCallPanel({super.key, required this.session});
  final MatchSessionInfo session;

  @override
  State<VoiceCallPanel> createState() => _VoiceCallPanelState();
}

class _VoiceCallPanelState extends State<VoiceCallPanel> with SingleTickerProviderStateMixin {
  Room? _room;
  bool _connected = false;
  bool _muted = false;
  String? _error;
  Timer? _poll;
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    final v = widget.session.voice;
    if (v == null) {
      setState(() => _error = 'VOICE_UNAVAILABLE');
      return;
    }
    try {
      final room = Room(roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true));
      _room = room;
      await room.connect(v.url, v.token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      if (!mounted) return;
      setState(() => _connected = true);
      _poll = Timer.periodic(const Duration(milliseconds: 300), (_) => mounted ? setState(() {}) : null);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _toggleMute() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    await lp.setMicrophoneEnabled(_muted);
    setState(() => _muted = !_muted);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _pulse.dispose();
    final r = _room;
    if (r != null) {
      unawaited(r.disconnect().then((_) => r.dispose()));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final remote = _room?.remoteParticipants.values.firstOrNull;
    final speaking = remote?.isSpeaking ?? false;
    final status = _error != null
        ? (_error == 'VOICE_UNAVAILABLE' ? l.voiceUnavailable : l.micPermission)
        : !_connected || remote == null
            ? l.voiceConnecting
            : speaking
                ? l.speaking
                : l.voiceConnected;

    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) => Container(
          padding: EdgeInsets.all(speaking ? 10 + 8 * _pulse.value : 10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [AppColors.cyan.withValues(alpha: speaking ? 0.5 : 0.15), Colors.transparent]),
          ),
          child: child,
        ),
        child: LumiAvatar(avatarId: widget.session.partner.avatarId, size: 150, ring: true),
      ),
      const SizedBox(height: 24),
      Text(status, style: TextStyle(color: _error != null ? AppColors.danger : AppColors.textMuted, fontSize: 15)),
      const SizedBox(height: 32),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _RoundButton(
          icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: _muted ? l.unmute : l.mute,
          active: !_muted,
          onTap: _connected ? _toggleMute : null,
        ),
      ]),
    ]);
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.active, this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: active ? AppColors.coolGradient : null,
            color: active ? null : AppColors.surfaceHigh,
          ),
          child: Icon(icon, size: 30),
        ),
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
    ]);
  }
}
