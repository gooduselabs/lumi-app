import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../auth/domain/user.dart';

final profileRepositoryProvider = Provider((ref) => ProfileRepository(ref.watch(apiClientProvider)));

class ProfileRepository {
  ProfileRepository(this._api);
  final ApiClient _api;

  Future<Me> onboard({
    required String nickname,
    required String gender,
    required DateTime birthday,
    required String avatarId,
    String? bio,
    required List<String> interests,
  }) async {
    final d = birthday;
    final iso = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return Me.fromJson(await _api.put('/me/onboarding', data: {
      'nickname': nickname,
      'gender': gender,
      'birthday': iso,
      'avatarId': avatarId,
      if (bio != null && bio.isNotEmpty) 'bio': bio,
      'interests': interests,
    }));
  }

  Future<Me> update(Map<String, dynamic> patch) async => Me.fromJson(await _api.patch('/me', data: patch));

  Future<PublicUser> user(String id) async => PublicUser.fromJson(await _api.get('/users/$id'));

  Future<List<PublicUser>> blocks() async =>
      (await _api.get<List>('/blocks')).map((e) => PublicUser.fromJson(Map<String, dynamic>.from(e as Map))).toList();

  Future<void> block(String userId) => _api.post('/blocks/$userId');
  Future<void> unblock(String userId) => _api.delete('/blocks/$userId');

  Future<void> report(String targetId, String reason, {String? details, String? context}) => _api.post('/reports', data: {
        'targetId': targetId,
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
        'context': ?context,
      });
}
