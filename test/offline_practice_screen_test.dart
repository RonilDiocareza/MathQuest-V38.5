import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/game/npc_question.dart';
import 'package:flutter_mathquest/screens/home_screen.dart';
import 'package:flutter_mathquest/screens/offline_practice_screen.dart';
import 'package:flutter_mathquest/services/auth_service.dart';
import 'package:flutter_mathquest/services/user_progress_service.dart';
import 'package:flutter_mathquest/worksheet_lesson_data.dart';

UserProgress _progress(Set<int> completedLevels) => UserProgress(
      completedLevels: completedLevels.toList(),
      completedNpcQuestions: const [],
      unlockedLevels: 1,
      questAttempts: 0,
      maxUnlockedSubLevel: const {},
    );

WorksheetModuleAccess _access({
  bool sessionVerified = true,
  Set<int> completedLevels = const {},
  bool progressAvailable = true,
}) =>
    WorksheetModuleAccess(
      sessionVerified: sessionVerified,
      progress: progressAvailable ? _progress(completedLevels) : null,
      usingCachedProgress: true,
    );

void main() {
  testWidgets('Home Dashboard exposes Practice Mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(tutorialStatusCheck: () async => false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Practice Mode'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-menu-Practice Mode')),
      findsOneWidget,
    );
  });

  testWidgets('Home opens Practice Mode in a blurred modal panel',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(tutorialStatusCheck: () async => false),
      ),
    );
    await tester.pumpAndSettle();

    final practiceEntry =
        find.byKey(const ValueKey('home-menu-Practice Mode'));
    await tester.ensureVisible(practiceEntry);
    await tester.tap(practiceEntry);
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OfflinePracticeScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('practice-modal-backdrop')),
      findsOneWidget,
    );
    expect(find.text('Practice Mode'), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('practice-back-button')));
    await tester.pumpAndSettle();

    expect(find.byType(OfflinePracticeScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('practice-modal-backdrop')),
      findsNothing,
    );
    expect(find.text('Practice Mode'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('verified student can complete a local practice session',
      (tester) async {
    final generatedQuestions = NpcQuestion.practiceQuestionsForModule(
      0,
      random: Random(51),
    );
    var accessLoads = 0;
    bool? initialRefreshFromServer;
    await tester.pumpWidget(
      MaterialApp(
        home: OfflinePracticeScreen(
          loadModuleAccess: ({required refreshFromServer}) async {
            accessLoads++;
            initialRefreshFromServer = refreshFromServer;
            return _access(completedLevels: {8});
          },
          random: Random(51),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Practice Mode'), findsOneWidget);
    expect(find.text(worksheetModuleNames.first), findsOneWidget);
    expect(accessLoads, 1);
    expect(initialRefreshFromServer, isFalse);
    await tester.tap(find.byKey(const ValueKey('practice-topic-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Practice'));
    await tester.pumpAndSettle();

    expect(find.text('Question 1 of 10'), findsOneWidget);
    for (var index = 0; index < generatedQuestions.length; index++) {
      final question = generatedQuestions[index];
      final selectedChoice = index == 0
          ? (question.correctAnswerIndex + 1) % question.choices.length
          : question.correctAnswerIndex;
      await tester.tap(
        find.byKey(ValueKey('practice-choice-$selectedChoice')),
      );
      await tester.pump();
      await tester.tap(find.text('Check Answer'));
      await tester.pumpAndSettle();
      expect(
        find.text(index == 0
            ? 'Not quite. The correct answer is '
                '${question.choices[question.correctAnswerIndex]}.'
            : 'Correct!'),
        findsOneWidget,
      );
      final continueLabel = index < generatedQuestions.length - 1
          ? 'Next Question'
          : 'View Results';
      await tester.scrollUntilVisible(
        find.text(continueLabel),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      if (index < generatedQuestions.length - 1) {
        await tester.tap(find.text(continueLabel));
        await tester.pumpAndSettle();
      } else {
        await tester.tap(find.text(continueLabel));
        await tester.pumpAndSettle();
      }
    }

    expect(find.text('PRACTICE RESULTS ONLY'), findsOneWidget);
    expect(find.text('Total practice questions'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('Correct answers'), findsOneWidget);
    expect(find.text('Incorrect answers'), findsOneWidget);
    expect(find.text('Practice accuracy'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('90%'), findsOneWidget);
    expect(accessLoads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unverified sessions cannot enter practice', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OfflinePracticeScreen(
          loadModuleAccess: ({required refreshFromServer}) async =>
              _access(sessionVerified: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start Practice'), findsNothing);
    expect(
      find.text('Verify your student session online to use Practice Mode.'),
      findsOneWidget,
    );
  });

  testWidgets('only verified unlocked topics are selectable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OfflinePracticeScreen(
          loadModuleAccess: ({required refreshFromServer}) async =>
              _access(completedLevels: {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final lockedTopic = tester.widget<ListTile>(
      find.byKey(const ValueKey('practice-topic-2')),
    );
    expect(lockedTopic.enabled, isFalse);
    expect(find.text('Complete Stage 1 - 8'), findsOneWidget);
    final startButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Start Practice'),
    );
    expect(startButton.onPressed, isNull);
    expect(
      find.byKey(const ValueKey('practice-topic-1')),
      findsOneWidget,
    );
  });

  testWidgets('Module 1 is usable with verified session and no cached progress',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OfflinePracticeScreen(
          loadModuleAccess: ({required refreshFromServer}) async =>
              _access(progressAvailable: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final moduleOne = tester.widget<ListTile>(
      find.byKey(const ValueKey('practice-topic-1')),
    );
    final moduleTwo = tester.widget<ListTile>(
      find.byKey(const ValueKey('practice-topic-2')),
    );
    expect(moduleOne.enabled, isTrue);
    expect(moduleTwo.enabled, isFalse);
    expect(find.text('Complete Stage 1 - 8'), findsOneWidget);
  });

  testWidgets('app resume revalidates access without resetting practice',
      (tester) async {
    var accessLoads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OfflinePracticeScreen(
          loadModuleAccess: ({required refreshFromServer}) async {
            accessLoads++;
            return _access();
          },
          random: Random(4),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('practice-topic-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Practice'));
    await tester.pumpAndSettle();
    final firstQuestion = NpcQuestion.practiceQuestionsForModule(
      0,
      random: Random(4),
    ).first;
    await tester.tap(
      find.byKey(
        ValueKey('practice-choice-${firstQuestion.correctAnswerIndex}'),
      ),
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(accessLoads, 2);
    expect(find.text('Question 1 of 10'), findsOneWidget);
    expect(find.text('Check Answer'), findsOneWidget);
    expect(find.text('Correct!'), findsNothing);
    expect(
      tester
          .widget<ListTile>(
            find.byKey(
              ValueKey('practice-choice-${firstQuestion.correctAnswerIndex}'),
            ),
          )
          .selected,
      isTrue,
    );
  });

  testWidgets('confirmed session invalidation clears practice access',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OfflinePracticeScreen(
          loadModuleAccess: ({required refreshFromServer}) async => _access(),
          random: Random(3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('practice-topic-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Practice'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 10'), findsOneWidget);

    AuthService.invalidateCurrentVerifiedSession();
    await tester.pumpAndSettle();

    expect(find.text('Question 1 of 10'), findsNothing);
    expect(
      find.textContaining('Your verified session is no longer valid.'),
      findsOneWidget,
    );
  });
}
