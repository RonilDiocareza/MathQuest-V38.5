import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/services/user_progress_service.dart';

void main() {
  test('parses a saved correct Classroom Quest answer', () {
    final attemptedAt = DateTime.utc(2026, 10, 18, 12);
    final attempt = ClassroomQuestAttempt.fromDocument('attempt-1', {
      'questId': 'classroom_quest',
      'type': 'answer',
      'questionNumber': 2,
      'answer': '2/5',
      'isCorrect': true,
      'score': 10,
      'attemptNumber': 1,
      'timeSpentSeconds': 12,
      'timedOut': false,
      'status': 'correct',
      'attemptedAt': Timestamp.fromDate(attemptedAt),
    });

    expect(attempt, isNotNull);
    expect(attempt!.id, 'attempt-1');
    expect(attempt.questionNumber, 2);
    expect(attempt.answer, '2/5');
    expect(attempt.isCorrect, isTrue);
    expect(attempt.score, 10);
    expect(attempt.attemptNumber, 1);
    expect(attempt.timeSpentSeconds, 12);
    expect(attempt.timedOut, isFalse);
    expect(attempt.status, 'correct');
    expect(attempt.attemptedAt?.toUtc(), attemptedAt);
  });

  test('parses timed-out attempts and rejects inconsistent records', () {
    final timedOut = ClassroomQuestAttempt.fromDocument('attempt-2', {
      'questId': 'classroom_quest',
      'type': 'answer',
      'questionNumber': 3,
      'answer': '',
      'isCorrect': false,
      'score': 0,
      'attemptNumber': 2,
      'timeSpentSeconds': 60,
      'timedOut': true,
      'status': 'timed_out',
    });
    final invalid = ClassroomQuestAttempt.fromDocument('attempt-3', {
      'questId': 'classroom_quest',
      'type': 'answer',
      'questionNumber': 1,
      'answer': 'wrong',
      'isCorrect': false,
      'score': 10,
      'attemptNumber': 1,
      'timeSpentSeconds': 60,
      'timedOut': false,
      'status': 'incorrect',
    });

    expect(timedOut, isNotNull);
    expect(timedOut!.timedOut, isTrue);
    expect(timedOut.score, 0);
    expect(invalid, isNull);
  });
}
