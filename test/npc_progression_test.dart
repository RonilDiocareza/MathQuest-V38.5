import 'dart:async';
import 'dart:async' as async;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/game/math_world_game.dart';
import 'package:flutter_mathquest/game/npc_question.dart';
import 'package:flutter_mathquest/game/question_npc.dart';
import 'package:flutter_mathquest/screens/number_pickup_game_screen.dart';
import 'package:just_audio_platform_interface/method_channel_just_audio.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

class _TestAudioPlayerPlatform extends AudioPlayerPlatform {
  final _playbackEvents = StreamController<PlaybackEventMessage>.broadcast();

  _TestAudioPlayerPlatform(super.id);

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream =>
      _playbackEvents.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async =>
      LoadResponse(duration: const Duration(milliseconds: 40));

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    async.Timer(const Duration(milliseconds: 40), () {
      _playbackEvents.add(
        PlaybackEventMessage(
          processingState: ProcessingStateMessage.completed,
          updateTime: DateTime.now(),
          updatePosition: const Duration(milliseconds: 40),
          bufferedPosition: const Duration(milliseconds: 40),
          duration: const Duration(milliseconds: 40),
          icyMetadata: null,
          currentIndex: 0,
          androidAudioSessionId: null,
        ),
      );
    });
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async => PauseResponse();

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
    SetSkipSilenceRequest request,
  ) async =>
      SetSkipSilenceResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async =>
      SetShuffleModeResponse();

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
    SetShuffleOrderRequest request,
  ) async =>
      SetShuffleOrderResponse();

  @override
  Future<SeekResponse> seek(SeekRequest request) async => SeekResponse();

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    await _playbackEvents.close();
    return DisposeResponse();
  }
}

class _TestJustAudioPlatform extends JustAudioPlatform {
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async =>
      _TestAudioPlayerPlatform(request.id);

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async =>
      DisposePlayerResponse();

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async =>
      DisposeAllPlayersResponse();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    JustAudioPlatform.instance = _TestJustAudioPlatform();
  });

  tearDown(() {
    JustAudioPlatform.instance = MethodChannelJustAudio();
  });

  test('question arrow target skips completed NPC placements', () {
    final game = MathWorldGame(correctAnswer: 2, problem: '1 + 1 = ?')
      ..npcPlacements = NpcQuestion.createNpcPlacements(
        playerSpawn: Vector2.zero(),
        canOccupy: (center, radius) => true,
      )
      ..completedNpcQuestions.add(1);

    expect(game.nextUnansweredNpcPlacement?.questionNumber, 2);

    game.completedNpcQuestions.addAll([2, 3, 4, 5, 6]);
    expect(game.nextUnansweredNpcPlacement, isNull);
  });

  testWidgets('Game Mode requests landscape orientation before gameplay',
      (tester) async {
    final orientationRequests = <List<Object?>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          orientationRequests.add(
            (call.arguments as List<Object?>).toList(),
          );
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: NumberPickupGameScreen(
          level: 1,
          problem: '1 + 1 = ?',
          correctAnswer: 2,
        ),
      ),
    );

    expect(orientationRequests, [
      [
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ],
    ]);
  });

  testWidgets('three wrong NPC answers offer restart or quit', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 450);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NumberPickupGameScreen(
          level: 1,
          problem: '1 + 1 = ?',
          correctAnswer: 2,
          saveGameModeAnswer: ({
            required int level,
            required int questionNumber,
            required String question,
            required String selectedAnswer,
            required String correctAnswer,
            required bool isCorrect,
            required int scoreEarned,
            required int scoreAfter,
          }) async {},
        ),
      ),
    );

    for (var attempt = 0;
        attempt < 40 &&
            find.byType(GameWidget<MathWorldGame>).evaluate().isEmpty;
        attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final gameWidget = tester.widget<GameWidget<MathWorldGame>>(
      find.byType(GameWidget<MathWorldGame>),
    );
    final game = gameWidget.game!;
    for (var attempt = 0; attempt < 40 && !game.isGameLoaded; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
    }
    expect(game.isGameLoaded, isTrue);
    expect(find.byIcon(Icons.favorite), findsNWidgets(3));
    expect(find.byIcon(Icons.menu_book), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.textContaining('1 + 1'), findsNothing);
    expect(find.textContaining('Question'), findsNothing);

    final firstNpc = game.world.children
        .query<QuestionNpc>()
        .firstWhere((npc) => npc.question.questionNumber == 1);
    final wrongAnswer = firstNpc.question.choices[
        (firstNpc.question.correctAnswerIndex + 1) %
            firstNpc.question.choices.length];
    game.player.position
        .setValues(firstNpc.position.x, firstNpc.position.y - 21 - 30);
    firstNpc.update(0);
    await tester.pump();
    expect(find.text('Question 1'), findsNothing);

    game.player.position
        .setValues(firstNpc.position.x, firstNpc.position.y - 21);
    firstNpc.update(0);
    await tester.pump();

    expect(find.text('Question 1'), findsOneWidget);
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Question 1'), findsOneWidget);

    await tester.tap(find.text(wrongAnswer));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.byIcon(Icons.favorite), findsNWidgets(2));
    expect(game.currentQuestionNumber, 1);
    expect(game.completedNpcQuestions, isEmpty);
    expect(find.textContaining('Wrong answer'), findsOneWidget);

    for (var attempt = 2; attempt <= 3; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(find.text('Question 1'), findsOneWidget);
      await tester.tap(find.text(wrongAnswer));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }

    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Game Over').evaluate().isNotEmpty) break;
    }
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.text('Game Over'), findsOneWidget);
    expect(
      tester
          .widget<GameWidget<MathWorldGame>>(
            find.byType(GameWidget<MathWorldGame>),
          )
          .game,
      same(game),
    );

    await tester.tap(find.text('Restart'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      final restarted = tester.widget<GameWidget<MathWorldGame>>(
        find.byType(GameWidget<MathWorldGame>),
      );
      if (restarted.game!.isGameLoaded && !identical(restarted.game, game)) {
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
    }
    final restartedGame = tester
        .widget<GameWidget<MathWorldGame>>(
          find.byType(GameWidget<MathWorldGame>),
        )
        .game!;
    expect(identical(restartedGame, game), isFalse);
    expect(restartedGame.isGameLoaded, isTrue);
    expect(restartedGame.currentQuestionNumber, 1);
    expect(restartedGame.completedNpcQuestions, isEmpty);
    expect(find.byIcon(Icons.favorite), findsNWidgets(3));
    expect(find.text('Question 1'), findsNothing);
  });
}
