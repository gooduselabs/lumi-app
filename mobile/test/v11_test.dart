import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumi/core/config/env.dart';
import 'package:lumi/features/auth/domain/user.dart';
import 'package:lumi/features/chat/domain/chat_models.dart';
import 'package:lumi/features/nearby/application/nearby_controller.dart';
import 'package:lumi/features/nearby/presentation/filter_widgets.dart';
import 'package:lumi/l10n/app_localizations.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('vi')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
    );

void main() {
  test('Me parses age preference + location flags (defaults 18-99)', () {
    final me = Me.fromJson({'id': '1', 'email': 'a@b.c', 'onboarded': true});
    expect((me.agePrefMin, me.agePrefMax, me.hasLocation, me.locationHidden), (18, 99, false, false));
    final me2 = Me.fromJson({'id': '1', 'email': 'a@b.c', 'onboarded': true, 'agePrefMin': 22, 'agePrefMax': 30, 'hasLocation': true});
    expect((me2.agePrefMin, me2.agePrefMax, me2.hasLocation), (22, 30, true));
  });

  test('PublicUser carries only an approximate distance', () {
    final u = PublicUser.fromJson({'id': 'x', 'nickname': 'Mai', 'avatarId': 'a02', 'distanceKm': 3});
    expect(u.distanceKm, 3);
    expect(u.copyWith(online: true).distanceKm, 3);
  });

  test('ChatMessage parses media attachments with absolute signed urls', () {
    final m = ChatMessage.fromJson({
      'id': 'm1',
      'conversationId': 'c1',
      'senderId': 'u1',
      'type': 'VOICE',
      'body': '',
      'createdAt': '2026-10-20T04:00:00.000Z',
      'attachment': {
        'id': 'a1', 'kind': 'VOICE', 'mimeType': 'audio/mp4', 'sizeBytes': 2048, 'fileName': 'voice.m4a',
        'durationMs': 4200, 'url': '/attachments/a1?exp=1&sig=s',
      },
    });
    expect(m.isMedia, isTrue);
    expect(m.attachment!.durationMs, 4200);
    expect(m.attachment!.absoluteUrl, '${Env.apiBaseUrl}/attachments/a1?exp=1&sig=s');
    expect(m.attachment!.downloadUrl, endsWith('&download=1'));
    final text = ChatMessage.fromJson({'id': 'm2', 'conversationId': 'c1', 'senderId': 'u1', 'body': 'hi', 'createdAt': '2026-10-20T04:00:00.000Z'});
    expect(text.isMedia, isFalse);
    expect(text.attachment, isNull);
  });

  test('formatting helpers', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(2048), '2 KB');
    expect(formatBytes(3 * 1024 * 1024 + 300000), '3.3 MB');
    expect(formatDuration(const Duration(seconds: 65)), '1:05');
  });

  test('nearby filter value semantics', () {
    const a = NearbyFilter(radiusKm: 10);
    expect(a.copyWith(gender: 'FEMALE'), const NearbyFilter(radiusKm: 10, gender: 'FEMALE'));
    expect(a == a.copyWith(), isTrue);
    expect(kRadiusOptions, containsAllInOrder([5, 10, 25, 50, 100]));
  });

  testWidgets('AgeRangeField shows the range and reports changes on release', (tester) async {
    (int, int)? saved;
    await tester.pumpWidget(_wrap(AgeRangeField(min: 20, max: 30, onChangeEnd: (a, b) => saved = (a, b))));
    expect(find.text('20 – 30 tuổi'), findsOneWidget);
    final slider = find.byType(RangeSlider);
    final box = tester.getRect(slider);
    // Drag the right thumb fully to the right end.
    final rightThumbX = box.left + 24 + (box.width - 48) * ((30 - 18) / 81);
    await tester.dragFrom(Offset(rightThumbX, box.center.dy), Offset(box.width, 0));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.$1, 20);
    expect(saved!.$2, greaterThan(30));
  });

  testWidgets('GenderChips in English', (tester) async {
    String? v;
    await tester.pumpWidget(_wrap(GenderChips(value: 'ANY', onChanged: (x) => v = x), locale: const Locale('en')));
    await tester.tap(find.text('Female'));
    expect(v, 'FEMALE');
  });
}
