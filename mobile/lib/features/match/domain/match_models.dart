import '../../auth/domain/user.dart';

enum MatchMode { soul, voice }

extension MatchModeX on MatchMode {
  String get api => this == MatchMode.soul ? 'SOUL' : 'VOICE';
}

class AnonPartner {
  const AnonPartner({required this.avatarId, this.gender, this.age, this.interests = const [], this.common = const [], this.bio});
  final String avatarId;
  final String? gender;
  final int? age;
  final List<String> interests;
  final List<String> common;
  final String? bio;

  factory AnonPartner.fromJson(Map<String, dynamic> j) => AnonPartner(
        avatarId: (j['avatarId'] as String?) ?? 'a01',
        gender: j['gender'] as String?,
        age: (j['age'] as num?)?.toInt(),
        interests: (j['interests'] as List? ?? const []).cast<String>(),
        common: (j['commonInterests'] as List? ?? const []).cast<String>(),
        bio: j['bio'] as String?,
      );
}

class VoiceInfo {
  const VoiceInfo(this.url, this.room, this.token);
  final String url;
  final String room;
  final String token;
}

class MatchSessionInfo {
  const MatchSessionInfo({
    required this.id,
    required this.mode,
    required this.endsAt,
    required this.durationSec,
    required this.partner,
    required this.clockOffset,
    this.voice,
  });

  final String id;
  final MatchMode mode;
  final DateTime endsAt;
  final int durationSec;
  final AnonPartner partner;

  /// serverNow - deviceNow, so the countdown is correct even with a skewed device clock.
  final Duration clockOffset;
  final VoiceInfo? voice;

  Duration remaining() => endsAt.difference(DateTime.now().add(clockOffset));

  factory MatchSessionInfo.fromJson(Map<String, dynamic> j) {
    final serverNow = DateTime.parse(j['serverNow'] as String);
    final v = j['voice'] as Map?;
    return MatchSessionInfo(
      id: j['sessionId'] as String,
      mode: j['mode'] == 'VOICE' ? MatchMode.voice : MatchMode.soul,
      endsAt: DateTime.parse(j['endsAt'] as String),
      durationSec: (j['durationSec'] as num).toInt(),
      partner: AnonPartner.fromJson(Map<String, dynamic>.from(j['partner'] as Map)),
      clockOffset: serverNow.difference(DateTime.now()),
      voice: v == null ? null : VoiceInfo(v['url'] as String, v['room'] as String, v['token'] as String),
    );
  }
}

class SoulMessage {
  const SoulMessage({required this.id, required this.text, required this.mine, required this.at});
  final String id;
  final String text;
  final bool mine;
  final DateTime at;
}

enum MatchPhase { idle, searching, chatting, ended, mutual }

enum EndReason { timeout, skippedByMe, skippedByPartner, partnerLeft, blocked, other }

class MatchState {
  const MatchState({
    this.phase = MatchPhase.idle,
    this.mode = MatchMode.soul,
    this.session,
    this.messages = const [],
    this.partnerTyping = false,
    this.partnerLiked = false,
    this.iLiked = false,
    this.endReason,
    this.friend,
    this.conversationId,
    this.error,
  });

  final MatchPhase phase;
  final MatchMode mode;
  final MatchSessionInfo? session;
  final List<SoulMessage> messages;
  final bool partnerTyping;
  final bool partnerLiked;
  final bool iLiked;
  final EndReason? endReason;
  final PublicUser? friend;
  final String? conversationId;
  final Object? error;

  MatchState copyWith({
    MatchPhase? phase,
    MatchMode? mode,
    MatchSessionInfo? session,
    List<SoulMessage>? messages,
    bool? partnerTyping,
    bool? partnerLiked,
    bool? iLiked,
    EndReason? endReason,
    PublicUser? friend,
    String? conversationId,
    Object? error,
    bool clearError = false,
  }) =>
      MatchState(
        phase: phase ?? this.phase,
        mode: mode ?? this.mode,
        session: session ?? this.session,
        messages: messages ?? this.messages,
        partnerTyping: partnerTyping ?? this.partnerTyping,
        partnerLiked: partnerLiked ?? this.partnerLiked,
        iLiked: iLiked ?? this.iLiked,
        endReason: endReason ?? this.endReason,
        friend: friend ?? this.friend,
        conversationId: conversationId ?? this.conversationId,
        error: clearError ? null : (error ?? this.error),
      );
}
