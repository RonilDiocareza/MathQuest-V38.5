import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/game.dart';
import 'package:flutter_mathquest/main.dart';
import 'package:flutter_mathquest/game/math_world_game.dart';
import 'package:flutter_mathquest/game/npc_question.dart';
import 'package:flutter_mathquest/game/player.dart';
import 'package:flutter_mathquest/game/question_npc.dart' as npc_component;
import 'package:flutter_mathquest/services/user_progress_service.dart';
import 'package:flutter_mathquest/screens/home_screen.dart';
import 'package:flutter_mathquest/screens/login_screen.dart';
import 'package:flutter_mathquest/screens/register_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Login panel is centered on a roomy screen',
      (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 852);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    final panel = tester.getRect(find.byKey(const ValueKey('login-panel')));
    expect(panel.center.dx, closeTo(215, 1));
    expect(panel.center.dy, closeTo(426, 8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home menu scrolls on small portrait phones',
      (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final size in [const Size(320, 568), const Size(393, 852)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Leaderboard'));
      await tester.pumpAndSettle();

      final leaderboardText = tester.getRect(find.text('Leaderboard'));
      expect(leaderboardText.top, greaterThanOrEqualTo(0));
      expect(leaderboardText.bottom, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Home menu cards have matching size and centered alignment',
      (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1510, 768);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    final cards = [
      'Module',
      'Stages',
      'Classroom Quests',
      'My Progress',
      'Badges',
      'Leaderboard',
    ].map((label) {
      return tester.getRect(find.byKey(ValueKey('home-menu-$label')));
    }).toList();

    expect(find.text('x² − y²'), findsNothing);
    for (final card in cards.skip(1)) {
      expect(card.width, closeTo(cards.first.width, 0.01));
      expect(card.height, closeTo(cards.first.height, 0.01));
      expect(card.center.dx, closeTo(cards.first.center.dx, 0.01));
    }
    expect(cards.first.center.dx, closeTo(755, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Help popup auto-hides after 20 seconds and icon opens help',
      (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final size in [const Size(320, 568), const Size(1510, 768)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(key: ValueKey(size))),
      );
      await tester.pumpAndSettle();

      final iconFinder = find.byIcon(Icons.question_mark_rounded);
      final iconBefore = tester.getRect(iconFinder);
      final popupFinder = find.text("Adventurer's Guide");
      expect(popupFinder, findsOneWidget);
      var popupAnimation = find.ancestor(
        of: popupFinder,
        matching: find.byType(AnimatedOpacity),
      );
      expect(tester.widget<AnimatedOpacity>(popupAnimation.first).opacity, 1);
      final popup = tester.getRect(popupFinder);
      expect(popup.right, lessThan(iconBefore.left));
      expect(popup.left, greaterThanOrEqualTo(0));
      expect(popup.right, lessThanOrEqualTo(size.width));
      expect(popup.top, greaterThanOrEqualTo(0));
      expect(popup.bottom, lessThanOrEqualTo(size.height));

      await tester.pump(const Duration(seconds: 20));
      await tester.pump(const Duration(milliseconds: 200));
      popupAnimation = find.ancestor(
        of: popupFinder,
        matching: find.byType(AnimatedOpacity),
      );
      expect(tester.widget<AnimatedOpacity>(popupAnimation.first).opacity, 0);
      expect(tester.getRect(iconFinder), iconBefore);

      await tester.tap(iconFinder);
      await tester.pumpAndSettle();
      expect(find.text('Welcome to MathQuest!'), findsOneWidget);
      popupAnimation = find.ancestor(
        of: popupFinder,
        matching: find.byType(AnimatedOpacity),
      );
      expect(tester.widget<AnimatedOpacity>(popupAnimation.first).opacity, 0);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Help popup timer restarts when returning to Home',
      (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 852);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-menu-Module')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    final popupFinder = find.text("Adventurer's Guide");
    final popupAnimation = find.ancestor(
      of: popupFinder,
      matching: find.byType(AnimatedOpacity),
    );
    expect(tester.widget<AnimatedOpacity>(popupAnimation.first).opacity, 1);

    await tester.pump(const Duration(seconds: 19));
    expect(tester.widget<AnimatedOpacity>(popupAnimation.first).opacity, 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<AnimatedOpacity>(popupAnimation.first).opacity, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home menu opens a screen without a route animation delay',
      (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 852);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('home-menu-Module')));
    await tester.pump();

    expect(find.text('Modules'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Register character selection fits a small phone',
      (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);

    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Choose Your Character'), findsOneWidget);
    expect(find.text('Boy'), findsOneWidget);
    expect(find.text('Girl'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Girl'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Girl'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Game Mode loads the map and Boy fallback without a profile',
      (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 360);
    SharedPreferences.setMockInitialValues({});

    final game = MathWorldGame(correctAnswer: 1, problem: '1 + 0 = ?');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameWidget(
            game: game,
            loadingBuilder: (_) => const Text('Loading Game...'),
            errorBuilder: (_, error) => Text('Game load error: $error'),
          ),
        ),
      ),
    );

    for (var attempt = 0; attempt < 200 && !game.isGameLoaded; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
    }

    expect(game.isGameLoaded, isTrue);
    expect(game.startPosition.x, closeTo(570, 0.1));
    expect(game.startPosition.y, closeTo(620, 0.1));
    expect(game.player.position, game.startPosition);
    final playerFeet = game.startPosition + Vector2(0, 21);
    expect(
      game.canPlayerMoveTo(
        playerFeet,
        MathWorldGame.playerFeetCollisionRadius,
      ),
      isTrue,
    );
    for (final offset in [
      Vector2(16, 0),
      Vector2(-16, 0),
      Vector2(0, 16),
      Vector2(0, -16),
    ]) {
      expect(
        game.canPlayerMoveTo(
          playerFeet + offset,
          MathWorldGame.playerFeetCollisionRadius,
        ),
        isTrue,
      );
    }
    game.startMoveRight();
    game.update(0.25);
    game.stopMove();
    expect(game.player.position.x, greaterThan(game.startPosition.x));
    final npc4 = game.npcPlacements
        .firstWhere((placement) => placement.questionNumber == 4);
    final npc4CollisionCenter =
        npc4.position - Vector2(0, npc4.collisionRadius);
    expect(
      npc4CollisionCenter.distanceTo(playerFeet),
      greaterThan(
          npc4.collisionRadius + MathWorldGame.playerFeetCollisionRadius + 60),
    );
    expect(
      game.camera.viewfinder.zoom,
      closeTo(
        math.max(
              game.size.x / game.mapWidth,
              game.size.y / game.mapHeight,
            ) *
            2.0,
        0.001,
      ),
    );
    final visibleMap = game.camera.visibleWorldRect;
    expect(
      visibleMap.left,
      greaterThanOrEqualTo(-0.1),
    );
    expect(
      visibleMap.top,
      greaterThanOrEqualTo(-0.1),
    );
    expect(visibleMap.right, lessThanOrEqualTo(game.mapWidth + 0.1));
    expect(visibleMap.bottom, lessThanOrEqualTo(game.mapHeight + 0.1));
    expect(
      game.canPlayerMoveTo(
        Vector2(0, game.mapHeight / 2),
        MathWorldGame.playerFeetCollisionRadius,
        checkNpcCollisions: false,
      ),
      isFalse,
    );
    expect(
      game.camera.visibleWorldRect.contains(
        Offset(game.player.position.x, game.player.position.y),
      ),
      isTrue,
    );
    game.player.position.x += 30;
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      game.camera.visibleWorldRect.center.dx,
      closeTo(game.player.position.x, 0.1),
    );
    expect(game.player.characterId, 'boy');
    expect(game.player.spriteAssetPath, Player.boySpriteAssetPath);
    final girlPlayer = Character(characterId: 'girl')
      ..position = game.startPosition.clone();
    game.world.add(girlPlayer);
    for (var attempt = 0; attempt < 40 && !girlPlayer.isLoaded; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
    }
    expect(girlPlayer.isLoaded, isTrue);
    expect(girlPlayer.spriteAssetPath, Player.girlSpriteAssetPath);
    expect(girlPlayer.downAnimation, isNotNull);
    expect(girlPlayer.upAnimation, isNotNull);
    expect(girlPlayer.leftAnimation, isNotNull);
    expect(girlPlayer.rightAnimation, isNotNull);
    final girlSprite = await tester.runAsync(
      () => rootBundle.load(girlPlayer.spriteAssetPath),
    );
    expect(girlSprite!.lengthInBytes, greaterThan(0));
    final placements = game.npcPlacements;
    expect(placements, hasLength(6));
    expect(
      placements.map((placement) => placement.questionNumber).toList()..sort(),
      [1, 2, 3, 4, 5, 6],
    );
    for (final placement in placements) {
      final sprite = await tester.runAsync(
        () => rootBundle.load(placement.spriteAssetPath),
      );
      expect(sprite!.lengthInBytes, greaterThan(0));
    }
    final npcs = game.world.children.query<npc_component.QuestionNpc>();
    expect(npcs, hasLength(6));
    for (final npc in npcs) {
      expect(npc.sprite, isNotNull);
      expect(npc.size.y, npc_component.QuestionNpc.visibleHeight);
      expect(npc.sprite!.srcPosition.x, 0);
      expect(npc.sprite!.srcPosition.y, 12);
      expect(npc.sprite!.srcSize.x, 209);
      expect(npc.sprite!.srcSize.y, 313);
      expect(npc.priority, npc.position.y.round());
    }
    expect(game.player.priority, (game.player.position.y + 24).round());
    final npcPositions =
        npcs.map((npc) => npc.position.clone()).toList(growable: false);
    game.update(0.1);
    for (var index = 0; index < npcs.length; index++) {
      expect(npcs.elementAt(index).position, npcPositions[index]);
    }

    var openedQuestion = false;
    int? lockedAtQuestion;
    game.currentQuestionNumber = 2;
    game.onNpcQuestion = (_) => openedQuestion = true;
    game.onNpcQuestionLocked = (questionNumber) {
      lockedAtQuestion = questionNumber;
    };
    final secondNpc = npcs.firstWhere(
      (npc) => npc.question.questionNumber == 2,
    );
    game.currentQuestionNumber = 1;
    game.checkNpcCollisionsAt(
      secondNpc.position - Vector2(0, secondNpc.collisionRadius),
      Player.feetCollisionRadius,
    );
    expect(openedQuestion, isFalse);
    expect(lockedAtQuestion, 1);
    game.currentQuestionNumber = 2;
    game.interactWithNpc(NpcQuestion.all[4]);
    expect(openedQuestion, isFalse);
    expect(lockedAtQuestion, 2);
    game.update(1);
    game.interactWithNpc(NpcQuestion.all[1]);
    expect(openedQuestion, isTrue);
    game.closeNpcQuestion();

    game
      ..completedNpcQuestions.add(1)
      ..currentQuestionNumber = 2;
    openedQuestion = false;
    game.update(1);
    game.interactWithNpc(NpcQuestion.all.first);
    expect(openedQuestion, isFalse);
    expect(tester.takeException(), isNull);
  });

  test('NPC question progress unlocks only the next question', () {
    final progress = UserProgress(
      completedLevels: const [],
      completedNpcQuestions: const [],
      unlockedLevels: 1,
      questAttempts: 0,
      maxUnlockedSubLevel: const {1: 1, 2: 1, 3: 1},
    );
    expect(progress.currentNpcQuestionNumber, 1);
    expect(progress.areNpcQuestionsCompleted, isFalse);

    final afterFirstQuestion = UserProgress(
      completedLevels: const [],
      completedNpcQuestions: const [1],
      unlockedLevels: 1,
      questAttempts: 0,
      maxUnlockedSubLevel: const {1: 1, 2: 1, 3: 1},
    );
    expect(afterFirstQuestion.currentNpcQuestionNumber, 2);

    final afterAllQuestions = UserProgress(
      completedLevels: const [],
      completedNpcQuestions: const [1, 2, 3, 4, 5, 6],
      unlockedLevels: 1,
      questAttempts: 0,
      maxUnlockedSubLevel: const {1: 1, 2: 1, 3: 1},
    );
    expect(afterAllQuestions.currentNpcQuestionNumber, 6);
    expect(afterAllQuestions.areNpcQuestionsCompleted, isTrue);
  });
}
