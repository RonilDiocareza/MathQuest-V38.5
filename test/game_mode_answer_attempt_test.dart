import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/services/user_progress_service.dart';

void main() {
  group('GameModeAnswerAttemptIds', () {
    test('reuses an ID for retries and allocates a new ID for another answer',
        () {
      var nextId = 0;
      final attemptIds = GameModeAnswerAttemptIds(
        createId: () => 'attempt-${++nextId}',
      );

      final firstAnswerId = attemptIds.forAnswer('5/8', false);

      expect(attemptIds.forAnswer('5/8', false), firstAnswerId);
      expect(attemptIds.forAnswer('1/2', false), 'attempt-2');
      expect(attemptIds.forAnswer('5/8', false), firstAnswerId);
      expect(attemptIds.forAnswer('3/8', true), 'attempt-3');
    });
  });

  group('ProblemLevelAnswerAttemptIds', () {
    test('reuses an ID only for retries of the same question and answer', () {
      var nextId = 0;
      final attemptIds = ProblemLevelAnswerAttemptIds(
        createId: () => 'attempt-${++nextId}',
      );

      String forAnswer(String question, int answer) => attemptIds.forAnswer(
            level: 5,
            question: question,
            selectedAnswer: answer,
            correctAnswer: 44,
          );

      final firstAttemptId = forAnswer('15 + 29 = ?', 44);
      expect(forAnswer('15 + 29 = ?', 44), firstAttemptId);
      expect(forAnswer('16 + 28 = ?', 44), 'attempt-2');
      expect(forAnswer('15 + 29 = ?', 43), 'attempt-3');
      expect(forAnswer('15 + 29 = ?', 44), firstAttemptId);
    });
  });

  group('GameModeAnswerAttempt.fromDocument', () {
    test('parses a correct answer record with its score and timestamp', () {
      final attemptedAt = DateTime.utc(2026, 10, 19);

      final attempt = GameModeAnswerAttempt.fromDocument('attempt-1', {
        'level': 4,
        'questionNumber': 2,
        'question': 'What is 3 + 4?',
        'selectedAnswer': '7',
        'correctAnswer': '7',
        'isCorrect': true,
        'scoreEarned': 10,
        'scoreAfter': 20,
        'attemptedAt': attemptedAt,
      });

      expect(attempt, isNotNull);
      expect(attempt!.id, 'attempt-1');
      expect(attempt.level, 4);
      expect(attempt.questionNumber, 2);
      expect(attempt.selectedAnswer, '7');
      expect(attempt.isCorrect, isTrue);
      expect(attempt.scoreEarned, 10);
      expect(attempt.scoreAfter, 20);
      expect(attempt.attemptedAt, attemptedAt);
    });

    test('parses incorrect answers without awarding points', () {
      final attempt = GameModeAnswerAttempt.fromDocument('attempt-2', {
        'level': 4,
        'questionNumber': 3,
        'question': 'What is 3 + 4?',
        'selectedAnswer': '8',
        'correctAnswer': '7',
        'isCorrect': false,
        'scoreEarned': 0,
        'scoreAfter': 20,
      });

      expect(attempt, isNotNull);
      expect(attempt!.isCorrect, isFalse);
      expect(attempt.scoreEarned, 0);
    });

    test('rejects inconsistent score data', () {
      final attempt = GameModeAnswerAttempt.fromDocument('attempt-3', {
        'level': 4,
        'questionNumber': 3,
        'question': 'What is 3 + 4?',
        'selectedAnswer': '8',
        'correctAnswer': '7',
        'isCorrect': false,
        'scoreEarned': 10,
        'scoreAfter': 20,
      });

      expect(attempt, isNull);
    });
  });
}
