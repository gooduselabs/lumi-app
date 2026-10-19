import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumi/core/network/api_exception.dart';
import 'package:lumi/core/utils/time_format.dart';
import 'package:lumi/core/widgets/lumi_avatar.dart';
import 'package:lumi/features/match/domain/match_models.dart';
import 'package:lumi/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  test('age gate boundary', () {
    final now = DateTime(2026, 10, 19);
    expect(ageFrom(DateTime(2008, 10, 19), now), 18);
    expect(ageFrom(DateTime(2008, 10, 20), now), 17);
  });

  test('countdown format', () {
    expect(formatCountdown(const Duration(seconds: 179)), '02:59');
    expect(formatCountdown(const Duration(seconds: -3)), '00:00');
  });

  test('match session parses and computes remaining time with server clock offset', () {
    final serverNow = DateTime.now().toUtc().add(const Duration(minutes: 10)); // device clock 10 min behind
    final s = MatchSessionInfo.fromJson({
      'sessionId': 's1',
      'mode': 'SOUL',
      'endsAt': serverNow.add(const Duration(seconds: 180)).toIso8601String(),
      'serverNow': serverNow.toIso8601String(),
      'durationSec': 180,
      'partner': {'avatarId': 'a03', 'gender': 'FEMALE', 'age': 22, 'interests': ['music'], 'commonInterests': ['music']},
      'voice': null,
    });
    expect(s.partner.common, ['music']);
    expect(s.remaining().inSeconds, inInclusiveRange(178, 180));
  });

  test('ack errors map to ApiException', () {
    final e = ApiException.fromAck({'ok': false, 'code': 'SESSION_CLOSED', 'message': 'x'});
    expect(e.code, 'SESSION_CLOSED');
  });

  testWidgets('all 24 avatars render', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Wrap(children: [for (final id in LumiAvatar.ids) LumiAvatar(avatarId: id, size: 40, online: true)]),
    ));
    expect(find.byType(LumiAvatar), findsNWidgets(24));
  });
}
