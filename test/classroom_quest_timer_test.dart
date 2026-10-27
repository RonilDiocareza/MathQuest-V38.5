import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/classroom_quest_questions.dart';
import 'package:flutter_mathquest/screens/classroom_quest_screen.dart';
import 'package:flutter_mathquest/services/user_progress_service.dart';
import 'package:flutter_mathquest/worksheet_lesson_data.dart';

void main() {
  final dailyState = ClassroomQuestDailyState(
    progress: UserProgress(
      completedLevels: const [],
      completedNpcQuestions: const [],
      unlockedLevels: 1,
      questAttempts: 0,
      maxUnlockedSubLevel: const {},
    ),
    dayKey: '2026-10-27',
    completed: false,
    previousQuestionIds: const [],
  );
  final fixedQuestions = [
    const ClassroomQuestQuestion(
      worksheetNumber: 1,
      moduleNumber: 1,
      prompt: 'Calculate 1/4 + 2/4.',
      answer: '3/4',
    ),
    const ClassroomQuestQuestion(
      worksheetNumber: 2,
      moduleNumber: 1,
      prompt: 'Calculate 3/5 - 1/5.',
      answer: '2/5',
    ),
    const ClassroomQuestQuestion(
      worksheetNumber: 3,
      moduleNumber: 1,
      prompt: 'Calculate 1/2 + 1/4.',
      answer: '3/4',
    ),
  ];

  Future<void> startQuest(WidgetTester tester) async {
    var attemptNumber = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ClassroomQuestScreen(
          saveAttempt: (_) async {},
          attemptIdGenerator: () => 'test-attempt-${attemptNumber++}',
          loadDailyState: () async => dailyState,
          selectQuestions: (_) => fixedQuestions,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('timeout on the first question restarts with a fresh timer',
      (tester) async {
    await startQuest(tester);

    await tester.pump(const Duration(seconds: 60));
    await tester.pump();

    expect(find.text('Level 1 of 3'), findsOneWidget);
    expect(find.text("Time's Up!"), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    await tester.pump();

    expect(find.text('Level 1 of 3'), findsOneWidget);
    expect(find.text('01:00'), findsOneWidget);
    expect(find.text("Time's Up!"), findsNothing);
  });

  testWidgets('keeps the quest interface read-only after daily completion',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClassroomQuestScreen(
          loadDailyState: () async => ClassroomQuestDailyState(
            progress: dailyState.progress,
            dayKey: dailyState.dayKey,
            completed: true,
            previousQuestionIds: const [],
            completedQuestionIds: const [
              'worksheet-1',
              'worksheet-2',
              'worksheet-3',
            ],
          ),
          selectQuestions: (_) => fixedQuestions,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Classroom Quest'), findsOneWidget);
    expect(find.text(worksheetLessons.first.question), findsOneWidget);
    expect(
      find.text(
        "You've already completed today's Classroom Quest. Come back tomorrow for a new challenge!",
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
      isFalse,
    );
    final submitButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Completed'),
    );
    expect(submitButton.onPressed, isNull);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('shows an answerable quest when the next day is available',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClassroomQuestScreen(
          loadDailyState: () async => ClassroomQuestDailyState(
            progress: dailyState.progress,
            dayKey: '2026-10-28',
            completed: false,
            previousQuestionIds: const [],
          ),
          selectQuestions: (_) => fixedQuestions,
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
      isTrue,
    );
    expect(find.text('Submit Answer'), findsOneWidget);
    expect(
      find.text(
        "You've already completed today's Classroom Quest. Come back tomorrow for a new challenge!",
      ),
      findsNothing,
    );
  });

  testWidgets('Retry reloads daily state after a recoverable load failure',
      (tester) async {
    var loadCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ClassroomQuestScreen(
          loadDailyState: () async {
            loadCount++;
            if (loadCount == 1) {
              throw StateError('temporary load failure');
            }
            return dailyState;
          },
          selectQuestions: (_) => fixedQuestions,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Could not load today\'s Classroom Quest. Please try again.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(loadCount, 2);
    expect(find.text('Level 1 of 3'), findsOneWidget);
    expect(
        find.text('Could not load today\'s Classroom Quest. Please try again.'),
        findsNothing);
  });

  testWidgets('timeout on a later question resets question and answer state',
      (tester) async {
    await startQuest(tester);

    await tester.enterText(find.byType(TextFormField), '3/4');
    await tester.tap(find.text('Submit Answer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Level 2 of 3'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '2/5');
    await tester.tap(find.text('Submit Answer'));
    await tester.pump();

    await tester.pump(const Duration(seconds: 60));
    await tester.pump();

    expect(find.text("Time's Up!"), findsOneWidget);
    expect(find.text('Level 1 of 3'), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    await tester.pump();

    expect(find.text('01:00'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      isEmpty,
    );
  });
}
