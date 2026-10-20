import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumi/core/theme/app_theme.dart';
import 'package:lumi/features/games/application/games_controller.dart';
import 'package:lumi/features/games/domain/game_models.dart';
import 'package:lumi/features/games/presentation/caro_view.dart';
import 'package:lumi/features/games/presentation/draw_view.dart';
import 'package:lumi/features/games/presentation/game_common.dart';
import 'package:lumi/features/games/presentation/game_result_note.dart';
import 'package:lumi/features/games/presentation/know_me_view.dart';
import 'package:lumi/features/games/presentation/truth_dare_view.dart';
import 'package:lumi/l10n/app_localizations.dart';
import 'package:lumi/l10n/app_localizations_vi.dart';

/// Records intents instead of talking to the socket.
class FakeGames extends GamesController {
  final actions = <Map<String, dynamic>>[];
  @override
  GamesState build() => const GamesState();
  @override
  Future<void> act(Map<String, dynamic> action) async => actions.add(action);
}

const me = 'me';
const peer = 'peer';
Map<String, dynamic> view(String kind, Map<String, dynamic> data, {String? turn = me, String status = 'active', Map<String, dynamic>? result}) => {
      'id': 'g1',
      'kind': kind,
      'conversationId': 'c1',
      'players': [
        {'id': me, 'nickname': 'An', 'avatarId': 'a01'},
        {'id': peer, 'nickname': 'Mai', 'avatarId': 'a04'},
      ],
      'you': me,
      'status': status,
      'version': 3,
      'turn': turn,
      'data': data,
      'result': result,
      'rematch': <String>[],
      'serverTime': DateTime.now().millisecondsSinceEpoch,
    };

Future<FakeGames> pump(WidgetTester t, Widget child, {Locale locale = const Locale('vi')}) async {
  final fake = FakeGames();
  t.view.physicalSize = const Size(1080, 2200);
  t.view.devicePixelRatio = 2.6;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [gamesControllerProvider.overrideWith(() => fake)],
    child: MaterialApp(
      theme: AppTheme.dark(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  ));
  await t.pump(const Duration(milliseconds: 600));
  return fake;
}

void main() {
  group('models', () {
    test('parses a game view and the GAME: system note', () {
      final g = GameView.fromJson(view('CARO', {'size': 15}));
      expect(g.kind, GameKind.caro);
      expect(g.myTurn, isTrue);
      expect(g.peer.nickname, 'Mai');
      final r = GameResult.fromSystemBody('GAME:{"kind":"KNOW_ME","winnerId":null,"scores":{"me":4,"peer":5},"compatibility":75,"reason":"finished","players":["me","peer"]}');
      expect(r!.kind, GameKind.knowMe);
      expect(r.compatibility, 75);
      expect(GameResult.fromSystemBody('MATCHED_SOUL'), isNull);
      expect(GameResult.fromSystemBody('GAME:{broken'), isNull);
    });

    test('stroke json round-trip keeps colour and normalized points', () {
      final s = DrawStroke.fromJson(const DrawStroke(0xFFFF5CA8, 6, [0.123456, 0.5, 1, 0]).toJson());
      expect(s.color, 0xFFFF5CA8);
      expect(s.points, [0.1235, 0.5, 1, 0]);
    });

    test('outcome texts and compatibility tiers', () {
      final l = AppLocalizationsVi();
      expect(outcomeText(l, const GameResult(kind: GameKind.caro, winnerId: me), meId: me, peerName: 'Mai'), l.gameYouWin);
      expect(outcomeText(l, const GameResult(kind: GameKind.caro, winnerId: peer), meId: me, peerName: 'Mai'), l.gamePeerWins('Mai'));
      expect(outcomeText(l, const GameResult(kind: GameKind.draw), meId: me, peerName: 'Mai'), l.gameTie);
      expect(outcomeText(l, const GameResult(kind: GameKind.caro, winnerId: me, reason: 'forfeit'), meId: me, peerName: 'Mai'), l.gameForfeit('Mai'));
      expect(compatTier(l, 90), l.kmTier1);
      expect(compatTier(l, 10), l.kmTier4);
    });
  });

  testWidgets('caro: taps send a place intent only on my turn and on empty cells', (t) async {
    final board = List.filled(225, '');
    board[112] = 'O';
    var fake = await pump(t, CaroView(g: GameView.fromJson(view('CARO', {'size': 15, 'board': board, 'x': me, 'last': 112, 'moves': 1, 'winLine': null}))));
    final box = t.getRect(find.byKey(const Key('caro-board')));
    final cell = box.width / 15;
    await t.tapAt(box.topLeft + Offset(cell * 0.5, cell * 0.5));
    await t.pump(const Duration(milliseconds: 400));
    await t.tapAt(box.topLeft + Offset(cell * 7.5, cell * 7.5)); // occupied
    await t.pump(const Duration(milliseconds: 400));
    expect(fake.actions, [
      {'type': 'place', 'cell': 0},
    ]);

    fake = await pump(t, CaroView(g: GameView.fromJson(view('CARO', {'size': 15, 'board': board, 'x': me, 'last': 112, 'moves': 1, 'winLine': null}, turn: peer))));
    await t.tapAt(box.topLeft + Offset(cell * 0.5, cell * 0.5));
    await t.pump(const Duration(milliseconds: 400));
    expect(fake.actions, isEmpty);
  });

  testWidgets('truth or dare: chooser buttons on my turn, prompt card after the spin', (t) async {
    final fake = await pump(t, TruthDareView(g: GameView.fromJson(view('TRUTH_DARE', {'round': 1, 'rounds': 10, 'phase': 'choose', 'choice': null, 'prompt': null, 'spin': 0, 'stats': {}}))));
    await t.tap(find.byKey(const Key('td-dare')));
    await t.pump();
    expect(fake.actions.single, {'type': 'pick', 'choice': 'dare'});

    await pump(t, TruthDareView(g: GameView.fromJson(view('TRUTH_DARE', {
      'round': 2, 'rounds': 10, 'phase': 'prompt', 'choice': 'truth', 'spin': 1, 'stats': {},
      'prompt': {'id': 't1', 'vi': 'Ấn tượng đầu tiên của bạn về mình là gì?', 'en': 'First impression?'},
    }, turn: peer))));
    await t.pump(const Duration(seconds: 2));
    expect(find.text('Ấn tượng đầu tiên của bạn về mình là gì?'), findsOneWidget);
    expect(find.byKey(const Key('td-done')), findsNothing); // not my turn
  });

  testWidgets('who knows who: needs both picks, then submits answer + guess', (t) async {
    final q = {
      'id': 'k1',
      'q': {'vi': 'Buổi hẹn lý tưởng?', 'en': 'Ideal date?'},
      'options': [
        {'vi': 'Cà phê', 'en': 'Coffee'},
        {'vi': 'Xem phim', 'en': 'Movie'},
      ],
    };
    final fake = await pump(t, KnowMeView(g: GameView.fromJson(view('KNOW_ME', {
      'index': 0, 'count': 6, 'phase': 'answer', 'question': q, 'answered': <String>[], 'mine': null, 'answers': null, 'correct': {}, 'compatibility': 0,
    }, turn: null))));
    await t.tap(find.byKey(const Key('km-submit')));
    await t.pump();
    expect(fake.actions, isEmpty);
    await t.tap(find.byKey(const Key('km-self-1')));
    await t.tap(find.byKey(const Key('km-guess-0')));
    await t.pump();
    await t.tap(find.byKey(const Key('km-submit')));
    await t.pump();
    expect(fake.actions.single, {'type': 'answer', 'q': 0, 'self': 1, 'guess': 0});
  });

  testWidgets('draw & guess: guesser sees only the hint and can submit a guess', (t) async {
    final fake = await pump(t, DrawView(g: GameView.fromJson(view('DRAW', {
      'round': 1, 'rounds': 4, 'drawer': peer, 'phase': 'drawing', 'seconds': 75,
      'endsAt': DateTime.now().add(const Duration(seconds: 60)).millisecondsSinceEpoch,
      'word': null, 'hint': {'vi': '___ ___', 'en': '___'}, 'strokes': [
        {'c': '#ff5ca8', 'w': 6, 'p': [0.1, 0.1, 0.5, 0.5]},
      ],
      'guesses': [
        {'by': me, 'text': 'con chó', 'correct': false},
      ],
      'solved': false, 'scores': {me: 0, peer: 0},
    }, turn: peer))));
    expect(find.textContaining('_ _ _'), findsOneWidget);
    expect(find.text('con chó'), findsOneWidget);
    await t.enterText(find.byKey(const Key('draw-guess')), 'con mèo');
    await t.testTextInput.receiveAction(TextInputAction.send);
    await t.pump();
    expect(fake.actions.single, {'type': 'guess', 'text': 'con mèo'});
  });

  testWidgets('game result note in chat shows the outcome', (t) async {
    await pump(
      t,
      GameResultNote(
        result: GameResult.fromSystemBody('GAME:{"kind":"CARO","winnerId":"me","scores":{"me":1,"peer":0},"reason":"finished","players":["me","peer"]}')!,
        meId: me,
        peerName: 'Mai',
      ),
    );
    expect(find.text('Cờ caro'), findsOneWidget);
    expect(find.text('Bạn thắng! 🎉'), findsOneWidget);
    expect(find.text('Điểm 1 – 0'), findsOneWidget);
  });
}
