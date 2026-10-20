import 'dart:convert';

enum GameKind {
  truthDare('TRUTH_DARE'),
  knowMe('KNOW_ME'),
  caro('CARO'),
  draw('DRAW');

  const GameKind(this.wire);
  final String wire;
  static GameKind? fromWire(String? w) => GameKind.values.where((k) => k.wire == w).firstOrNull;
}

class GamePlayer {
  const GamePlayer({required this.id, required this.nickname, required this.avatarId});
  final String id;
  final String nickname;
  final String avatarId;
  factory GamePlayer.fromJson(Map<String, dynamic> j) =>
      GamePlayer(id: j['id'] as String, nickname: (j['nickname'] as String?) ?? 'Lumi', avatarId: (j['avatarId'] as String?) ?? 'a01');
}

class GameResult {
  const GameResult({required this.kind, this.winnerId, this.scores = const {}, this.compatibility, this.reason = 'finished', this.players = const []});
  final GameKind kind;
  final String? winnerId;
  final Map<String, int> scores;
  final int? compatibility;
  final String reason;
  final List<String> players;

  factory GameResult.fromJson(Map<String, dynamic> j) => GameResult(
        kind: GameKind.fromWire(j['kind'] as String?) ?? GameKind.caro,
        winnerId: j['winnerId'] as String?,
        scores: {for (final e in ((j['scores'] as Map?) ?? {}).entries) e.key as String: (e.value as num).toInt()},
        compatibility: (j['compatibility'] as num?)?.toInt(),
        reason: (j['reason'] as String?) ?? 'finished',
        players: [for (final p in (j['players'] as List?) ?? const []) p as String],
      );

  /// SYSTEM chat notes for finished games are `GAME:{json}`.
  static GameResult? fromSystemBody(String body) {
    if (!body.startsWith('GAME:')) return null;
    try {
      return GameResult.fromJson(jsonDecode(body.substring(5)) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

class GameView {
  const GameView({
    required this.id,
    required this.kind,
    required this.conversationId,
    required this.players,
    required this.you,
    required this.status,
    required this.version,
    required this.turn,
    required this.data,
    this.result,
    this.rematch = const [],
    this.nextGameId,
    this.clockOffsetMs = 0,
    this.peerOnline = true,
  });

  final String id;
  final GameKind kind;
  final String conversationId;
  final List<GamePlayer> players;
  final String you;
  final String status;
  final int version;
  final String? turn;
  final Map<String, dynamic> data;
  final GameResult? result;
  final List<String> rematch;
  final String? nextGameId;

  /// serverTime - localTime, for countdowns.
  final int clockOffsetMs;
  final bool peerOnline;

  bool get ended => status == 'ended';
  bool get myTurn => turn == you;
  GamePlayer get me => players.firstWhere((p) => p.id == you, orElse: () => players.first);
  GamePlayer get peer => players.firstWhere((p) => p.id != you, orElse: () => players.last);
  DateTime serverNow() => DateTime.now().add(Duration(milliseconds: clockOffsetMs));

  factory GameView.fromJson(Map<String, dynamic> j) => GameView(
        id: j['id'] as String,
        kind: GameKind.fromWire(j['kind'] as String?) ?? GameKind.caro,
        conversationId: j['conversationId'] as String,
        players: [for (final p in j['players'] as List) GamePlayer.fromJson(Map<String, dynamic>.from(p as Map))],
        you: j['you'] as String,
        status: j['status'] as String,
        version: (j['version'] as num).toInt(),
        turn: j['turn'] as String?,
        data: Map<String, dynamic>.from(j['data'] as Map),
        result: j['result'] is Map ? GameResult.fromJson(Map<String, dynamic>.from(j['result'] as Map)) : null,
        rematch: [for (final r in (j['rematch'] as List?) ?? const []) r as String],
        nextGameId: j['nextGameId'] as String?,
        clockOffsetMs: j['serverTime'] is num ? (j['serverTime'] as num).toInt() - DateTime.now().millisecondsSinceEpoch : 0,
      );

  GameView copyWith({Map<String, dynamic>? data, bool? peerOnline}) => GameView(
        id: id, kind: kind, conversationId: conversationId, players: players, you: you, status: status, version: version,
        turn: turn, data: data ?? this.data, result: result, rematch: rematch, nextGameId: nextGameId,
        clockOffsetMs: clockOffsetMs, peerOnline: peerOnline ?? this.peerOnline,
      );
}

class GameInvite {
  const GameInvite({required this.inviteId, required this.kind, required this.conversationId, required this.from, required this.expiresAt});
  final String inviteId;
  final GameKind kind;
  final String conversationId;
  final GamePlayer from;
  final DateTime expiresAt;

  factory GameInvite.fromJson(Map<String, dynamic> j) => GameInvite(
        inviteId: j['inviteId'] as String,
        kind: GameKind.fromWire(j['kind'] as String?) ?? GameKind.caro,
        conversationId: j['conversationId'] as String,
        from: GamePlayer.fromJson(Map<String, dynamic>.from(j['from'] as Map)),
        expiresAt: DateTime.fromMillisecondsSinceEpoch((j['expiresAt'] as num).toInt()),
      );
}

/// Drawing stroke, points normalized 0..1 as a flat [x0,y0,x1,y1,…] list.
class DrawStroke {
  const DrawStroke(this.color, this.width, this.points);
  final int color;
  final double width;
  final List<double> points;

  factory DrawStroke.fromJson(Map<String, dynamic> j) => DrawStroke(
        int.parse(((j['c'] as String?) ?? '#ffffff').substring(1), radix: 16) | 0xFF000000,
        (j['w'] as num?)?.toDouble() ?? 4,
        [for (final v in j['p'] as List) (v as num).toDouble()],
      );
  Map<String, dynamic> toJson() => {
        'c': '#${(color & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        'w': width,
        'p': [for (final v in points) double.parse(v.toStringAsFixed(4))],
      };
}
