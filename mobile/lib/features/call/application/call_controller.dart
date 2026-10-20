import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../auth/domain/user.dart';
import '../../chat/data/chat_repository.dart';
import '../../match/domain/match_models.dart';
import '../data/call_repository.dart';

enum CallPhase { idle, outgoing, incoming, active, ended }

class CallState {
  const CallState({this.phase = CallPhase.idle, this.callId, this.conversationId, this.peer, this.voice, this.endReason, this.error});
  final CallPhase phase;
  final String? callId;
  final String? conversationId;
  final PublicUser? peer;
  final VoiceInfo? voice;
  /// ENDED | DECLINED | CANCELLED | NO_ANSWER
  final String? endReason;
  final Object? error;

  CallState copyWith({CallPhase? phase, String? callId, VoiceInfo? voice, String? endReason, Object? error, PublicUser? peer}) => CallState(
        phase: phase ?? this.phase,
        callId: callId ?? this.callId,
        conversationId: conversationId,
        peer: peer ?? this.peer,
        voice: voice ?? this.voice,
        endReason: endReason ?? this.endReason,
        error: error ?? this.error,
      );
}

const kRingTimeout = Duration(seconds: 45);

/// App-wide 1-1 friend call state (signalling over socket, media over LiveKit).
final callControllerProvider = NotifierProvider<CallController, CallState>(CallController.new);

class CallController extends Notifier<CallState> {
  Timer? _ring;
  CallRepository get _repo => ref.read(callRepositoryProvider);

  @override
  CallState build() {
    final s = ref.watch(socketServiceProvider);
    final subs = [
      s.on('call:incoming').listen(_onIncoming),
      s.on('call:accepted').listen(_onAccepted),
      s.on('call:ended').listen(_onEnded),
    ];
    ref.onDispose(() {
      for (final x in subs) {
        x.cancel();
      }
      _ring?.cancel();
    });
    return const CallState();
  }

  bool get busy => state.phase == CallPhase.outgoing || state.phase == CallPhase.incoming || state.phase == CallPhase.active;

  Future<void> startCall(String conversationId) async {
    if (busy) return;
    state = CallState(phase: CallPhase.outgoing, conversationId: conversationId);
    try {
      final peer = (await ref.read(chatRepositoryProvider).conversation(conversationId)).peer;
      state = state.copyWith(peer: peer);
      final r = await _repo.start(conversationId);
      state = state.copyWith(callId: r.callId, voice: r.voice);
      _ring?.cancel();
      _ring = Timer(kRingTimeout, () {
        if (state.phase == CallPhase.outgoing) {
          unawaited(hangUp(reason: 'NO_ANSWER'));
        }
      });
    } on ApiException catch (e) {
      state = state.copyWith(phase: CallPhase.ended, error: e, endReason: 'ERROR');
    }
  }

  Future<void> accept() async {
    final id = state.callId;
    if (id == null || state.phase != CallPhase.incoming) return;
    _ring?.cancel();
    try {
      final voice = await _repo.accept(id);
      state = state.copyWith(phase: CallPhase.active, voice: voice);
    } on ApiException catch (e) {
      state = state.copyWith(phase: CallPhase.ended, error: e, endReason: 'ENDED');
    }
  }

  Future<void> decline() async {
    final id = state.callId;
    _ring?.cancel();
    state = state.copyWith(phase: CallPhase.ended, endReason: 'DECLINED');
    if (id != null) await _repo.decline(id).catchError((_) {});
  }

  Future<void> hangUp({String reason = 'ENDED'}) async {
    final id = state.callId;
    _ring?.cancel();
    if (state.phase != CallPhase.ended) state = state.copyWith(phase: CallPhase.ended, endReason: reason);
    if (id != null) await _repo.end(id).catchError((_) {});
  }

  void reset() {
    _ring?.cancel();
    state = const CallState();
  }

  void _onIncoming(Map<String, dynamic> d) {
    if (busy) return; // server already guards; ignore while in a call
    final from = PublicUser.fromJson(Map<String, dynamic>.from(d['from'] as Map));
    state = CallState(phase: CallPhase.incoming, callId: d['callId'] as String, conversationId: d['conversationId'] as String?, peer: from);
    _ring?.cancel();
    _ring = Timer(kRingTimeout, () {
      if (state.phase == CallPhase.incoming) state = state.copyWith(phase: CallPhase.ended, endReason: 'NO_ANSWER');
    });
  }

  void _onAccepted(Map<String, dynamic> d) {
    if (d['callId'] != state.callId || state.phase != CallPhase.outgoing) return;
    _ring?.cancel();
    state = state.copyWith(phase: CallPhase.active);
  }

  void _onEnded(Map<String, dynamic> d) {
    if (d['callId'] != state.callId || state.phase == CallPhase.ended) return;
    _ring?.cancel();
    state = state.copyWith(phase: CallPhase.ended, endReason: d['reason'] as String? ?? 'ENDED');
  }
}
