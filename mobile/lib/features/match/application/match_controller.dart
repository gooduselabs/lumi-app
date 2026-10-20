import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/domain/user.dart';
import '../data/match_repository.dart';
import '../domain/match_models.dart';

final matchStatsProvider = FutureProvider.autoDispose<MatchStats>((ref) async {
  final timer = Timer(const Duration(seconds: 15), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(matchRepositoryProvider).stats();
});

final matchControllerProvider = NotifierProvider<MatchController, MatchState>(MatchController.new);

/// State machine for Soul/Voice Match: idle -> searching -> chatting -> (ended | mutual).
class MatchController extends Notifier<MatchState> {
  MatchRepository get _repo => ref.read(matchRepositoryProvider);
  final List<StreamSubscription> _subs = [];
  Timer? _typingTimer;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  MatchState build() {
    final s = _repo.socket;
    _subs
      ..add(s.on('match:found').listen(_onFound))
      ..add(s.on('soul:message').listen(_onMessage))
      ..add(s.on('soul:typing').listen(_onTyping))
      ..add(s.on('match:liked').listen((d) {
        if (_isCurrent(d)) state = state.copyWith(partnerLiked: true);
      }))
      ..add(s.on('match:mutual').listen(_onMutual))
      ..add(s.on('match:ended').listen(_onEnded));
    ref.onDispose(() {
      for (final x in _subs) {
        x.cancel();
      }
      _typingTimer?.cancel();
    });
    return const MatchState();
  }

  bool _isCurrent(Map<String, dynamic> d) => state.session != null && d['sessionId'] == state.session!.id;

  Future<void> start(MatchMode mode, {String genderPref = 'ANY', bool preferNearby = false}) async {
    state = MatchState(phase: MatchPhase.searching, mode: mode);
    try {
      final session = await _repo.join(mode, genderPref, preferNearby: preferNearby);
      if (session != null) _enterSession(session);
    } on ApiException catch (e) {
      if (e.code == 'ALREADY_IN_SESSION') return; // a match:found event will arrive / is active
      state = MatchState(phase: MatchPhase.idle, mode: mode, error: e);
    }
  }

  Future<void> cancel() async {
    if (state.phase == MatchPhase.searching) {
      try {
        await _repo.leave();
      } catch (_) {}
    }
    state = const MatchState();
  }

  void reset() => state = const MatchState();

  Future<void> send(String text) async {
    final s = state.session;
    final t = text.trim();
    if (s == null || t.isEmpty || state.phase != MatchPhase.chatting) return;
    final local = SoulMessage(id: 'local-${DateTime.now().microsecondsSinceEpoch}', text: t, mine: true, at: DateTime.now());
    state = state.copyWith(messages: [...state.messages, local]);
    try {
      await _repo.send(s.id, t);
    } on ApiException catch (e) {
      state = state.copyWith(error: e, messages: state.messages.where((m) => m.id != local.id).toList());
    }
  }

  void typing() {
    final s = state.session;
    if (s == null || state.phase != MatchPhase.chatting) return;
    final now = DateTime.now();
    if (now.difference(_lastTypingSent) < const Duration(seconds: 2)) return;
    _lastTypingSent = now;
    _repo.typing(s.id);
  }

  Future<void> like() async {
    final s = state.session;
    if (s == null || state.iLiked) return;
    state = state.copyWith(iLiked: true);
    try {
      await _repo.like(s.id);
    } on ApiException catch (e) {
      state = state.copyWith(iLiked: false, error: e);
    }
  }

  Future<void> skip() async {
    final s = state.session;
    if (s == null) return reset();
    state = state.copyWith(phase: MatchPhase.ended, endReason: EndReason.skippedByMe);
    try {
      await _repo.skip(s.id);
    } catch (_) {}
  }

  Future<void> blockPartner() async {
    final s = state.session;
    if (s == null) return;
    await _repo.blockPartner(s.id);
    state = state.copyWith(phase: MatchPhase.ended, endReason: EndReason.blocked);
  }

  Future<void> reportPartner(String reason, String? details) async {
    final s = state.session;
    if (s != null) await _repo.reportPartner(s.id, reason, details);
  }

  /// Called by the countdown when it reaches zero (server will confirm via match:ended).
  void localTimeout() {
    if (state.phase == MatchPhase.chatting) state = state.copyWith(phase: MatchPhase.ended, endReason: EndReason.timeout);
  }

  void clearError() => state = state.copyWith(clearError: true);

  // ---------- events ----------
  void _onFound(Map<String, dynamic> d) {
    if (state.phase != MatchPhase.searching) return;
    _enterSession(MatchSessionInfo.fromJson(d));
  }

  void _enterSession(MatchSessionInfo s) {
    if (state.session?.id == s.id && state.phase == MatchPhase.chatting) return;
    state = MatchState(phase: MatchPhase.chatting, mode: s.mode, session: s);
  }

  void _onMessage(Map<String, dynamic> d) {
    if (!_isCurrent(d)) return;
    final m = SoulMessage(id: d['id'] as String, text: d['text'] as String, mine: false, at: DateTime.now());
    _typingTimer?.cancel();
    state = state.copyWith(messages: [...state.messages, m], partnerTyping: false);
  }

  void _onTyping(Map<String, dynamic> d) {
    if (!_isCurrent(d)) return;
    state = state.copyWith(partnerTyping: true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () => state = state.copyWith(partnerTyping: false));
  }

  void _onMutual(Map<String, dynamic> d) {
    if (!_isCurrent(d)) return;
    state = state.copyWith(
      phase: MatchPhase.mutual,
      friend: PublicUser.fromJson(Map<String, dynamic>.from(d['friend'] as Map)),
      conversationId: d['conversationId'] as String,
    );
  }

  void _onEnded(Map<String, dynamic> d) {
    if (!_isCurrent(d) || state.phase == MatchPhase.mutual) return;
    final reason = switch (d['reason']) {
      'TIMEOUT' => EndReason.timeout,
      'SKIPPED' => d['byMe'] == true ? EndReason.skippedByMe : EndReason.skippedByPartner,
      'PARTNER_LEFT' => EndReason.partnerLeft,
      'BLOCKED' => d['byMe'] == true ? EndReason.blocked : EndReason.skippedByPartner,
      _ => EndReason.other,
    };
    if (state.phase == MatchPhase.ended && state.endReason == EndReason.blocked) return;
    state = state.copyWith(phase: MatchPhase.ended, endReason: reason, partnerTyping: false);
  }
}
