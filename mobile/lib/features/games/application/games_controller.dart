import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/realtime/socket_service.dart';
import '../domain/game_models.dart';

/// Outgoing invite waiting for an answer.
class PendingInvite {
  const PendingInvite(this.inviteId, this.kind, this.expiresAt, {this.declined = false});
  final String inviteId;
  final GameKind kind;
  final DateTime expiresAt;
  final bool declined;
}

class GamesState {
  const GamesState({this.game, this.incoming = const [], this.outgoing, this.rematchAsked = false});
  final GameView? game;
  final List<GameInvite> incoming;
  final PendingInvite? outgoing;
  final bool rematchAsked;

  GamesState copyWith({Object? game = _keep, List<GameInvite>? incoming, Object? outgoing = _keep, bool? rematchAsked}) => GamesState(
        game: identical(game, _keep) ? this.game : game as GameView?,
        incoming: incoming ?? this.incoming,
        outgoing: identical(outgoing, _keep) ? this.outgoing : outgoing as PendingInvite?,
        rematchAsked: rematchAsked ?? this.rematchAsked,
      );
}

const _keep = Object();

final gamesControllerProvider = NotifierProvider<GamesController, GamesState>(GamesController.new);

/// Single source of truth for the (at most one) game the user is in, plus invites.
/// All rules live on the server; this only mirrors state and sends intents.
class GamesController extends Notifier<GamesState> {
  SocketService get _socket => ref.read(socketServiceProvider);

  @override
  GamesState build() {
    final s = ref.watch(socketServiceProvider);
    final subs = <StreamSubscription<Object?>>[
      s.on('game:invite').listen((d) => _addIncoming(GameInvite.fromJson(d))),
      s.on('game:invite_expired').listen((d) => _dropInvite(d['inviteId'] as String?)),
      s.on('game:declined').listen((d) {
        final o = state.outgoing;
        if (o != null && o.inviteId == d['inviteId']) state = state.copyWith(outgoing: PendingInvite(o.inviteId, o.kind, o.expiresAt, declined: true));
      }),
      s.on('game:started').listen((d) => _setGame(GameView.fromJson(d), started: true)),
      s.on('game:state').listen((d) => _setGame(GameView.fromJson(d))),
      s.on('game:ended').listen((d) => _setGame(GameView.fromJson(d))),
      s.on('game:rematch').listen((d) {
        if (state.game?.id == d['gameId']) state = state.copyWith(rematchAsked: true);
      }),
      s.on('game:peer').listen((d) {
        final g = state.game;
        if (g != null && g.id == d['gameId']) state = state.copyWith(game: g.copyWith(peerOnline: d['online'] == true));
      }),
      s.on('game:stroke').listen(_onStroke),
    ];
    void onStatus() {
      if (s.status.value == SocketStatus.connected) unawaited(sync());
    }

    s.status.addListener(onStatus);
    ref.onDispose(() {
      for (final x in subs) {
        x.cancel();
      }
      s.status.removeListener(onStatus);
    });
    return const GamesState();
  }

  void _setGame(GameView g, {bool started = false}) {
    final cur = state.game;
    if (cur != null && cur.id == g.id && g.version < cur.version) return;
    state = state.copyWith(
      game: g,
      outgoing: started ? null : state.outgoing,
      rematchAsked: cur?.id == g.id ? state.rematchAsked && g.rematch.isNotEmpty : false,
      incoming: started ? const [] : state.incoming,
    );
  }

  void _onStroke(Map<String, dynamic> d) {
    final g = state.game;
    if (g == null || g.id != d['gameId']) return;
    final strokes = List<dynamic>.of((g.data['strokes'] as List?) ?? const []);
    if (d['clear'] == true) {
      strokes.clear();
    } else if (d['stroke'] is Map) {
      strokes.add(d['stroke']);
    }
    state = state.copyWith(game: g.copyWith(data: {...g.data, 'strokes': strokes}));
  }

  void _addIncoming(GameInvite i) {
    state = state.copyWith(incoming: [...state.incoming.where((x) => x.inviteId != i.inviteId), i]);
  }

  void _dropInvite(String? id) {
    final o = state.outgoing;
    state = state.copyWith(
      incoming: state.incoming.where((x) => x.inviteId != id).toList(),
      outgoing: o != null && o.inviteId == id ? null : o,
    );
  }

  Future<void> sync() async {
    try {
      final r = await _socket.request<Map<String, dynamic>>('game:get', {});
      final g = r['game'];
      if (g is Map) _setGame(GameView.fromJson(Map<String, dynamic>.from(g)));
    } catch (_) {/* offline: keep last state */}
  }

  Future<void> invite(String conversationId, GameKind kind) async {
    final r = await _socket.request<Map<String, dynamic>>('game:invite', {'conversationId': conversationId, 'kind': kind.wire});
    state = state.copyWith(
      outgoing: PendingInvite(r['inviteId'] as String, kind, DateTime.fromMillisecondsSinceEpoch((r['expiresAt'] as num).toInt())),
    );
  }

  Future<void> cancelInvite() async {
    final o = state.outgoing;
    state = state.copyWith(outgoing: null);
    if (o != null && !o.declined) {
      try {
        await _socket.request<Object?>('game:cancel', {'inviteId': o.inviteId});
      } catch (_) {}
    }
  }

  Future<void> respond(GameInvite i, bool accept) async {
    _dropInvite(i.inviteId);
    final r = await _socket.request<Map<String, dynamic>>('game:respond', {'inviteId': i.inviteId, 'accept': accept});
    if (accept && r['id'] != null) _setGame(GameView.fromJson(r));
  }

  Future<void> act(Map<String, dynamic> action) async {
    final g = state.game;
    if (g == null) return;
    final r = await _socket.request<Map<String, dynamic>>('game:action', {'gameId': g.id, 'action': action});
    if (r['id'] != null) _setGame(GameView.fromJson(r));
  }

  /// Drawer: optimistic local stroke + fire to server (relayed to the guesser).
  void sendStroke(DrawStroke s) {
    final g = state.game;
    if (g == null) return;
    final json = s.toJson();
    state = state.copyWith(game: g.copyWith(data: {...g.data, 'strokes': [...((g.data['strokes'] as List?) ?? const []), json]}));
    _socket.send('game:action', {'gameId': g.id, 'action': {'type': 'stroke', 'stroke': json}});
  }

  Future<void> leave() async {
    final g = state.game;
    if (g == null) return;
    if (!g.ended) {
      try {
        await _socket.request<Object?>('game:leave', {'gameId': g.id});
      } catch (_) {}
    }
  }

  Future<void> rematch() async {
    final g = state.game;
    if (g == null) return;
    final r = await _socket.request<Map<String, dynamic>>('game:rematch', {'gameId': g.id});
    final v = GameView.fromJson(r);
    _setGame(v, started: v.id != g.id);
  }

  /// Leaving the game screen after the end.
  void close() {
    if (state.game?.ended ?? false) state = state.copyWith(game: null, rematchAsked: false);
  }
}
