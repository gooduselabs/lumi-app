import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/lumi_avatar.dart';
import '../domain/match_models.dart';

/// Audio-only 1-1 call over LiveKit (WebRTC). Used by Voice Match and friend calls.
/// [voice] is null when the server has no LiveKit configured.
class VoiceCallPanel extends StatefulWidget {
  const VoiceCallPanel({
    super.key,
    required this.voice,
    required this.avatarId,
    this.title,
    this.onPeerLeft,
    this.onHangUp,
    this.onConnectionChanged,
  });
  final VoiceInfo? voice;
  final String avatarId;
  final String? title;
  final VoidCallback? onPeerLeft;
  final VoidCallback? onHangUp;
  final ValueChanged<bool>? onConnectionChanged;

  @override
  State<VoiceCallPanel> createState() => _VoiceCallPanelState();
}

class _VoiceCallPanelState extends State<VoiceCallPanel> with SingleTickerProviderStateMixin {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool _connected = false;
  bool _muted = false;
  bool _speaker = true;
  bool _peerJoined = false;
  String? _error;
  Timer? _poll;
  DateTime? _since;
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    final v = widget.voice;
    if (v == null) {
      setState(() => _error = 'VOICE_UNAVAILABLE');
      return;
    }
    try {
      final room = Room(roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true));
      _room = room;
      _listener = room.createListener()
        ..on<ParticipantConnectedEvent>((_) => _onPeer(true))
        ..on<ParticipantDisconnectedEvent>((_) {
          _onPeer(false);
          widget.onPeerLeft?.call();
        })
        ..on<RoomDisconnectedEvent>((_) {
          if (mounted) setState(() => _connected = false);
          widget.onConnectionChanged?.call(false);
        });
      await room.connect(v.url, v.token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      if (!mounted) return;
      setState(() {
        _connected = true;
        _peerJoined = room.remoteParticipants.isNotEmpty;
        if (_peerJoined) _since = DateTime.now();
      });
      widget.onConnectionChanged?.call(true);
      _poll = Timer.periodic(const Duration(milliseconds: 300), (_) => mounted ? setState(() {}) : null);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _onPeer(bool joined) {
    if (!mounted) return;
    setState(() {
      _peerJoined = joined;
      _since = joined ? (_since ?? DateTime.now()) : _since;
    });
  }

  Future<void> _toggleMute() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    await lp.setMicrophoneEnabled(_muted);
    setState(() => _muted = !_muted);
  }

  Future<void> _toggleSpeaker() async {
    if (kIsWeb) return;
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(!_speaker);
      setState(() => _speaker = !_speaker);
    } catch (_) {}
  }

  @override
  void dispose() {
    _poll?.cancel();
    _pulse.dispose();
    _listener?.dispose();
    final r = _room;
    if (r != null) {
      unawaited(r.disconnect().then((_) => r.dispose()));
    }
    super.dispose();
  }

  String _elapsed() {
    final s = _since == null ? 0 : DateTime.now().difference(_since!).inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
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
        child: LumiAvatar(avatarId: widget.avatarId, size: 150, ring: true),
      ),
      if (widget.title != null) ...[
        const SizedBox(height: 18),
        Text(widget.title!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      ],
      const SizedBox(height: 12),
      Text(status, key: const Key('voiceStatus'), style: TextStyle(color: _error != null ? AppColors.danger : AppColors.textMuted, fontSize: 15)),
      if (_connected && _peerJoined) ...[
        const SizedBox(height: 4),
        Text(_elapsed(), style: const TextStyle(color: AppColors.cyan, fontSize: 16, fontFeatures: [FontFeature.tabularFigures()])),
      ],
      const SizedBox(height: 32),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        RoundCallButton(
          icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: _muted ? l.unmute : l.mute,
          active: !_muted,
          onTap: _connected ? _toggleMute : null,
        ),
        if (!kIsWeb) ...[
          const SizedBox(width: 28),
          RoundCallButton(
            icon: _speaker ? Icons.volume_up_rounded : Icons.hearing_rounded,
            label: l.speaker,
            active: _speaker,
            onTap: _connected ? _toggleSpeaker : null,
          ),
        ],
        if (widget.onHangUp != null) ...[
          const SizedBox(width: 28),
          RoundCallButton(icon: Icons.call_end_rounded, label: l.hangUp, active: true, danger: true, onTap: widget.onHangUp),
        ],
      ]),
    ]);
  }
}

class RoundCallButton extends StatelessWidget {
  const RoundCallButton({super.key, required this.icon, required this.label, required this.active, this.onTap, this.danger = false, this.success = false});
  final IconData icon;
  final String label;
  final bool active;
  final bool danger;
  final bool success;
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
            gradient: active && !danger && !success ? AppColors.coolGradient : null,
            color: danger ? AppColors.danger : success ? AppColors.mint : (active ? null : AppColors.surfaceHigh),
          ),
          child: Icon(icon, size: 30, color: Colors.white),
        ),
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
    ]);
  }
}
