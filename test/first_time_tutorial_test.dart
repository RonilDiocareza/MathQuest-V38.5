import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/widgets/first_time_tutorial_overlay.dart';

void main() {
  testWidgets('tutorial advances and saves on the final action',
      (WidgetTester tester) async {
    final targetKey = GlobalKey();
    var homeActionTriggered = false;
    var completed = false;
    final steps = [
      const FirstTimeTutorialStep(
        title: 'Welcome',
        message: 'Meet your guide.',
      ),
      FirstTimeTutorialStep(
        title: 'Levels',
        message: 'Choose a level to play.',
        targetKey: targetKey,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Center(
                child: ElevatedButton(
                  onPressed: () => homeActionTriggered = true,
                  child: const Text('Home action'),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  key: targetKey,
                  width: 120,
                  height: 50,
                  color: Colors.blue,
                ),
              ),
              Positioned.fill(
                child: FirstTimeTutorialOverlay(
                  steps: steps,
                  onComplete: () async => completed = true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.image(const AssetImage('assets/images/npcs/guide1.png')),
        findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Levels'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(find.text('Welcome'), findsNothing);
    expect(find.text('Home action'), findsOneWidget);
    await tester.tap(find.text('Home action'));
    expect(homeActionTriggered, isTrue);
  });

  testWidgets('tutorial guide can move clear of a highlighted control',
      (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    final targetKey = GlobalKey();
    final steps = [
      FirstTimeTutorialStep(
        title: 'Badges',
        message: 'See your badges.',
        targetKey: targetKey,
        guideAtTop: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: SizedBox(
                  key: targetKey,
                  width: 120,
                  height: 60,
                ),
              ),
              FirstTimeTutorialOverlay(
                steps: steps,
                onComplete: () async {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.image(const AssetImage('assets/images/npcs/guide1.png')),
      findsOneWidget,
    );
    expect(find.image(const AssetImage('assets/images/npcs/npc6.png')),
        findsNothing);
    final guideRect = tester.getRect(
      find.image(const AssetImage('assets/images/npcs/guide1.png')),
    );
    expect(
      guideRect.overlaps(tester.getRect(find.byKey(targetKey))),
      isFalse,
    );
    expect(find.text('See your badges.'), findsOneWidget);
    final messageRect = tester.getRect(find.text('See your badges.'));
    expect(messageRect.top, greaterThanOrEqualTo(guideRect.bottom));
    expect(guideRect.width, greaterThanOrEqualTo(100));
    expect(guideRect.height, guideRect.width);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom-positioned guide has a landscape dialogue above it',
      (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    final targetKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: SizedBox(
                  key: targetKey,
                  width: 120,
                  height: 60,
                ),
              ),
              FirstTimeTutorialOverlay(
                steps: [
                  FirstTimeTutorialStep(
                    title: 'Classroom Quests',
                    message: 'View quests assigned to your classroom.',
                    targetKey: targetKey,
                  ),
                ],
                onComplete: () async {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final guideRect = tester.getRect(
      find.image(const AssetImage('assets/images/npcs/guide1.png')),
    );
    final messageRect =
        tester.getRect(find.text('View quests assigned to your classroom.'));
    final targetRect = tester.getRect(find.byKey(targetKey));
    expect(messageRect.bottom, lessThanOrEqualTo(guideRect.top));
    expect(guideRect.overlaps(targetRect), isFalse);
    expect(messageRect.overlaps(targetRect), isFalse);
    expect(messageRect.width, greaterThan(messageRect.height));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Game Mode intro is text-only and passes through gameplay input',
      (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(812, 375);
    var gameplayInputTriggered = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 8,
                bottom: 8,
                child: ElevatedButton(
                  onPressed: () => gameplayInputTriggered = true,
                  child: const Text('Move'),
                ),
              ),
              Positioned.fill(
                child: FirstTimeTutorialOverlay(
                  gameModeLayout: true,
                  steps: const [
                    FirstTimeTutorialStep(
                      title: 'Example: solve the question',
                      message:
                          'Read the question carefully, identify the operation, '
                          'calculate the answer, and check your work.',
                    ),
                  ],
                  onComplete: () async {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tutorial-guide')), findsNothing);
    expect(find.image(const AssetImage('assets/images/npcs/guide1.png')),
        findsNothing);
    expect(find.image(const AssetImage('assets/images/npcs/guide2.png')),
        findsNothing);

    final panelFinder = find.byKey(const ValueKey('tutorial-dialogue'));
    final panelRect = tester.getRect(panelFinder);
    final panelDecoration =
        tester.widget<Container>(panelFinder).decoration as BoxDecoration;
    expect(panelRect.bottom, lessThanOrEqualTo(375));
    expect(panelRect.top, greaterThan(0));
    expect(panelRect.center.dx, closeTo(406, 1));
    expect(
        panelRect.left, greaterThan(tester.getRect(find.text('Move')).right));
    expect(panelDecoration.color, const Color(0xCC000000));

    await tester.tap(find.text('Move'));
    expect(gameplayInputTriggered, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Game Mode dialogue fits long text without overflowing', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    const shortMessage = 'Read the question and solve it.';
    const longMessage =
        'Read the question carefully, identify the operation, calculate the '
        'answer, and check your work before selecting your response. '
        'Use the same method you would use on your worksheet, simplify when '
        'needed, and make sure the final result matches the available answer. '
        'Every correct answer helps you progress through this challenge.';

    for (final size in [const Size(320, 568), const Size(812, 375)]) {
      tester.view.physicalSize = size;
      double? shortPanelHeight;

      for (final message in [shortMessage, longMessage]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FirstTimeTutorialOverlay(
                gameModeLayout: true,
                steps: [
                  FirstTimeTutorialStep(
                    title: 'Welcome to Game Mode',
                    message: message,
                  ),
                ],
                onComplete: () async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final panelRect =
            tester.getRect(find.byKey(const ValueKey('tutorial-dialogue')));
        final messageFinder = find.byKey(const ValueKey('tutorial-message'));
        final messageRect = tester.getRect(messageFinder);
        final buttonRect = tester.getRect(find.text('Finish'));

        expect(tester.widget<Text>(messageFinder).data, message);
        expect(panelRect.contains(messageRect.topLeft), isTrue);
        expect(panelRect.contains(buttonRect.topLeft), isTrue);
        expect(panelRect.contains(buttonRect.bottomRight), isTrue);
        final messageScroll =
            find.byKey(const ValueKey('tutorial-message-scroll'));
        if (messageScroll.evaluate().isEmpty) {
          expect(panelRect.contains(messageRect.bottomRight), isTrue);
        } else {
          final scrollRect = tester.getRect(messageScroll);
          expect(panelRect.contains(scrollRect.topLeft), isTrue);
          expect(panelRect.contains(scrollRect.bottomRight), isTrue);
        }

        if (message == shortMessage) {
          shortPanelHeight = panelRect.height;
        } else {
          expect(panelRect.height, greaterThan(shortPanelHeight!));
        }

        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('Game Mode dialogue types, reveals, and restarts per step', (
    WidgetTester tester,
  ) async {
    var completed = false;
    var transitionCount = 0;
    final transition = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FirstTimeTutorialOverlay(
            gameModeLayout: true,
            typewriterText: true,
            steps: const [
              FirstTimeTutorialStep(title: 'First', message: 'Hello guide.'),
              FirstTimeTutorialStep(title: 'Second', message: 'Next line.'),
            ],
            onStepChanged: (_) async {
              transitionCount++;
              await transition.future;
            },
            onComplete: () async => completed = true,
          ),
        ),
      ),
    );
    await tester.pump();

    final messageFinder = find.byKey(const ValueKey('tutorial-message'));
    expect(tester.widget<Text>(messageFinder).data, isEmpty);

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(tester.widget<Text>(messageFinder).data, 'Hello guide.');
    expect(find.text('1/2'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(transitionCount, 1);
    transition.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text('Second'), findsOneWidget);
    expect(tester.widget<Text>(messageFinder).data, isEmpty);

    await tester.pump(const Duration(milliseconds: 24));
    expect(tester.widget<Text>(messageFinder).data, 'N');
    await tester.tap(find.text('Finish'));
    await tester.pump();
    expect(tester.widget<Text>(messageFinder).data, 'Next line.');

    await tester.tap(find.text('Finish'));
    await tester.pump();
    expect(completed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing Game Mode tutorial cancels active typing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FirstTimeTutorialOverlay(
            gameModeLayout: true,
            typewriterText: true,
            steps: const [
              FirstTimeTutorialStep(
                title: 'Welcome',
                message: 'This typing animation should stop on close.',
              ),
            ],
            onComplete: () async {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 48));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
  });

  testWidgets('tutorial layout fits small and landscape screens',
      (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final size in [const Size(320, 568), const Size(812, 375)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstTimeTutorialOverlay(
              steps: const [
                FirstTimeTutorialStep(
                  title: 'Welcome',
                  message: 'Explore the game with NPC6.',
                ),
              ],
              onComplete: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final nextButton = tester.getRect(find.text('Finish'));
      expect(nextButton.left, greaterThanOrEqualTo(0));
      expect(nextButton.right, lessThanOrEqualTo(size.width));
      expect(nextButton.bottom, lessThanOrEqualTo(size.height));
    }
  });
}
