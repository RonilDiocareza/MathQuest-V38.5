import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/services/user_progress_service.dart';
import 'package:flutter_mathquest/widgets/game_mode_answer_history_entry.dart';

void main() {
  testWidgets('hides answer values and question text for correct attempts',
      (tester) async {
    final attempt = GameModeAnswerAttempt(
      id: 'correct-attempt',
      level: 12,
      questionNumber: 4,
      question: 'Secret question text',
      selectedAnswer: '42',
      correctAnswer: '42',
      isCorrect: true,
      scoreEarned: 10,
      scoreAfter: 40,
      attemptedAt: DateTime.utc(2026, 10, 25),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameModeAnswerHistoryEntry(attempt: attempt),
        ),
      ),
    );

    expect(find.textContaining('Stage 12 · Question 4 · Correct'), findsOne);
    expect(find.textContaining('Score earned: 10'), findsOne);
    expect(find.textContaining('Score after answer: 40'), findsOne);
    expect(find.textContaining('Secret question text'), findsNothing);
    expect(find.text('42'), findsNothing);
    expect(find.textContaining('Correct answer'), findsNothing);
    expect(find.textContaining('Selected:'), findsNothing);
  });

  testWidgets('hides answer values and question text for incorrect attempts',
      (tester) async {
    final attempt = GameModeAnswerAttempt(
      id: 'incorrect-attempt',
      level: 12,
      questionNumber: 5,
      question: 'Another secret question',
      selectedAnswer: '17',
      correctAnswer: '23',
      isCorrect: false,
      scoreEarned: 0,
      scoreAfter: 40,
      attemptedAt: DateTime.utc(2026, 10, 25),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameModeAnswerHistoryEntry(attempt: attempt),
        ),
      ),
    );

    expect(find.textContaining('Stage 12 · Question 5 · Incorrect'), findsOne);
    expect(find.textContaining('Score earned: 0'), findsOne);
    expect(find.textContaining('Score after answer: 40'), findsOne);
    expect(find.textContaining('Another secret question'), findsNothing);
    expect(find.text('17'), findsNothing);
    expect(find.text('23'), findsNothing);
    expect(find.textContaining('Correct answer'), findsNothing);
    expect(find.textContaining('Selected:'), findsNothing);
  });
}
