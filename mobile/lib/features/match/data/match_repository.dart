import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/realtime/socket_service.dart';
import '../domain/match_models.dart';

final matchRepositoryProvider = Provider(
  (ref) => MatchRepository(ref.watch(socketServiceProvider), ref.watch(apiClientProvider)),
);

class MatchStats {
  const MatchStats(this.online, this.voiceEnabled);
  final int online;
  final bool voiceEnabled;
}

class MatchRepository {
  MatchRepository(this._socket, this._api);
  final SocketService _socket;
  final ApiClient _api;

  SocketService get socket => _socket;

  /// Returns a session immediately if someone was waiting, otherwise null (wait for `match:found`).
  Future<MatchSessionInfo?> join(MatchMode mode, String genderPref) async {
    final data = Map<String, dynamic>.from(await _socket.request<Map>('match:join', {'mode': mode.api, 'gender': genderPref}));
    if (data['status'] == 'matched') return MatchSessionInfo.fromJson(Map<String, dynamic>.from(data['session'] as Map));
    return null;
  }

  Future<void> leave() => _socket.request('match:leave');
  Future<Map> like(String sessionId) => _socket.request<Map>('match:like', {'sessionId': sessionId});
  Future<void> skip(String sessionId) => _socket.request('match:skip', {'sessionId': sessionId});
  Future<Map> send(String sessionId, String text) => _socket.request<Map>('soul:message', {'sessionId': sessionId, 'text': text});
  void typing(String sessionId) => _socket.send('soul:typing', {'sessionId': sessionId});

  Future<void> blockPartner(String sessionId) => _api.post('/match/sessions/$sessionId/block');
  Future<void> reportPartner(String sessionId, String reason, String? details) => _api.post(
        '/match/sessions/$sessionId/report',
        data: {'reason': reason, if (details != null && details.isNotEmpty) 'details': details},
      );

  Future<MatchStats> stats() async {
    final j = await _api.get<Map>('/match/stats');
    return MatchStats((j['online'] as num).toInt(), j['voiceEnabled'] == true);
  }
}
