import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../match/domain/match_models.dart';

final callRepositoryProvider = Provider((ref) => CallRepository(ref.watch(apiClientProvider)));

VoiceInfo? _voice(Object? v) {
  if (v is! Map) return null;
  return VoiceInfo(v['url'] as String, v['room'] as String, v['token'] as String);
}

class CallRepository {
  CallRepository(this._api);
  final ApiClient _api;

  Future<({String callId, VoiceInfo? voice})> start(String conversationId) async {
    final j = await _api.post<Map>('/calls', data: {'conversationId': conversationId});
    return (callId: j['callId'] as String, voice: _voice(j['voice']));
  }

  Future<VoiceInfo?> accept(String callId) async => _voice((await _api.post<Map>('/calls/$callId/accept'))['voice']);
  Future<void> decline(String callId) => _api.post('/calls/$callId/decline');
  Future<void> end(String callId) => _api.post('/calls/$callId/end');
}
