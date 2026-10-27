import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_mathquest/services/auth_service.dart';
import 'package:flutter_mathquest/screens/home_screen.dart';
import 'package:flutter_mathquest/widgets/first_time_tutorial_overlay.dart';

void main() {
  testWidgets('temporary tutorial status failure defers and retries on resume',
      (tester) async {
    var statusChecks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          tutorialStatusCheck: () async {
            statusChecks++;
            return statusChecks == 1 ? null : true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(statusChecks, 1);
    expect(find.text('Could not check the tutorial status.'), findsNothing);
    expect(find.text('Welcome to MathQuest!'), findsNothing);
    expect(find.text('Module'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(statusChecks, 2);
    expect(find.text('Could not check the tutorial status.'), findsNothing);
    expect(find.text('Welcome to MathQuest!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permission-denied tutorial status is not treated as offline',
      (tester) async {
    var statusChecks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          tutorialStatusCheck: () async {
            statusChecks++;
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
              message: 'simulated authorization failure',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(statusChecks, 1);
    expect(
      find.text('Could not check the tutorial status.'),
      findsOneWidget,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(statusChecks, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirmed session invalidation stops deferred tutorial retries',
      (tester) async {
    var statusChecks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          tutorialStatusCheck: () async {
            statusChecks++;
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(statusChecks, 1);

    AuthService.invalidateCurrentVerifiedSession();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(statusChecks, 1);
    expect(find.text('Could not check the tutorial status.'), findsNothing);
  });

  testWidgets('shows guide title, current step, and step counter',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            FirstTimeTutorialOverlay(
              title: "Adventurer's Guide",
              steps: const [
                FirstTimeTutorialStep(
                  title: 'Welcome',
                  message: 'Explore the dashboard.',
                ),
                FirstTimeTutorialStep(
                  title: 'Leaderboard',
                  message: 'Compare your scores.',
                ),
              ],
              onComplete: () async {},
            ),
          ],
        ),
      ),
    ));

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tutorial-dialogue')),
        matching: find.text("Adventurer's Guide"),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text("Adventurer's Guide"), findsOneWidget);
    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed completion save stays on final step and can retry',
      (tester) async {
    var saveAttempts = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            FirstTimeTutorialOverlay(
              title: "Adventurer's Guide",
              steps: const [
                FirstTimeTutorialStep(
                  title: 'Welcome',
                  message: 'Explore the dashboard.',
                ),
                FirstTimeTutorialStep(
                  title: 'Leaderboard',
                  message: 'Compare your scores.',
                ),
              ],
              onComplete: () async {
                saveAttempts++;
                if (saveAttempts == 1) {
                  throw StateError('simulated Firestore write failure');
                }
              },
            ),
          ],
        ),
      ),
    ));

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(saveAttempts, 1);
    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(
      find.text('Could not save your progress. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry Save'), findsOneWidget);

    await tester.tap(find.text('Retry Save'));
    await tester.pumpAndSettle();

    expect(saveAttempts, 2);
    expect(find.text("Adventurer's Guide"), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tutorial dialogue fits phone and desktop viewport sizes',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final size in [const Size(320, 568), const Size(1510, 768)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              FirstTimeTutorialOverlay(
                title: "Adventurer's Guide",
                steps: const [
                  FirstTimeTutorialStep(
                    title: 'Leaderboard',
                    message:
                        'The leaderboard compares players’ scores and shows your current rank.',
                  ),
                ],
                onComplete: () async {},
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final dialogue = tester.getRect(find.byKey(const ValueKey(
        'tutorial-dialogue',
      )));
      expect(dialogue.left, greaterThanOrEqualTo(0));
      expect(dialogue.right, lessThanOrEqualTo(size.width));
      expect(dialogue.top, greaterThanOrEqualTo(0));
      expect(dialogue.bottom, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('help button remains tappable above the tutorial overlay',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 852);

    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-help-button')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tutorial-dialogue')),
        matching: find.text("Adventurer's Guide"),
      ),
      findsOneWidget,
    );
    expect(find.text('Welcome to MathQuest!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
