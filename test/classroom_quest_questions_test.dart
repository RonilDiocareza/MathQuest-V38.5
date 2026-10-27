import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/classroom_quest_questions.dart';
import 'package:flutter_mathquest/services/user_progress_service.dart';
import 'package:flutter_mathquest/worksheet_lesson_data.dart';

UserProgress progressWithModulesThrough(int module) {
  const requiredCompletions = {
    2: [8],
    3: [15],
    4: [20],
    5: [25],
    6: [30],
    7: [35],
    8: [41, 42],
  };
  final completed = <int>[];
  for (var index = 2; index <= module; index++) {
    completed.addAll(requiredCompletions[index] ?? const []);
  }
  return UserProgress(
    completedLevels: completed,
    completedNpcQuestions: const [],
    unlockedLevels: 1,
    questAttempts: 0,
    maxUnlockedSubLevel: const {},
  );
}

void main() {
  test('uses the Asia/Manila calendar day across UTC midnight boundaries', () {
    expect(
      UserProgressService.classroomQuestDayKey(
        DateTime.utc(2026, 10, 27, 15, 59, 59),
      ),
      '2026-10-27',
    );
    expect(
      UserProgressService.classroomQuestDayKey(
        DateTime.utc(2026, 10, 27, 16),
      ),
      '2026-10-28',
    );
    expect(
      UserProgressService.classroomQuestDayKey(
        DateTime.utc(2026, 12, 31, 16),
      ),
      '2027-01-01',
    );
  });

  test('selects three distinct questions only from unlocked modules', () {
    for (var unlockedModules = 1; unlockedModules <= 8; unlockedModules++) {
      final selected = selectClassroomQuestQuestions(
        progressWithModulesThrough(unlockedModules),
        random: Random(unlockedModules),
      );

      expect(selected, hasLength(3));
      expect(selected.map((question) => question.id).toSet(), hasLength(3));
      expect(
        selected.every((question) => question.moduleNumber <= unlockedModules),
        isTrue,
      );
      for (final question in selected) {
        final lesson = worksheetLessons[question.worksheetNumber - 1];
        expect(question.prompt, lesson.question);
        expect(question.answer, lesson.correctAnswer);
      }
    }
  });

  test('Classroom Quest unlock parsing ignores unrelated malformed answers',
      () {
    expect(
      () => LevelQuestionAnswer.fromData('legacy-invalid-answer'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'Invalid saved level question.',
        ),
      ),
    );
    final progress = UserProgress.forClassroomQuest({
      'progress': {
        'completedLevels': [8, 15],
        'levelQuestionAnswers': {'1': 'legacy-invalid-answer'},
      },
    });

    final selected = selectClassroomQuestQuestions(
      progress,
      random: Random(18),
    );

    expect(selected, hasLength(3));
    expect(selected.every((question) => question.moduleNumber <= 3), isTrue);
  });

  test('restores a saved completed question set only from unlocked modules',
      () {
    final progress = progressWithModulesThrough(1);
    final questions = classroomQuestQuestionsForIds(
      progress,
      ['worksheet-3', 'worksheet-1', 'worksheet-2'],
    );

    expect(questions, hasLength(3));
    expect(
      questions!.map((question) => question.id).toList(),
      ['worksheet-3', 'worksheet-1', 'worksheet-2'],
    );
    expect(
      classroomQuestQuestionsForIds(
        progress,
        ['worksheet-1', 'worksheet-2', 'worksheet-9'],
      ),
      isNull,
    );
    expect(
      classroomQuestQuestionsForIds(
        progress,
        ['worksheet-1', 'worksheet-1', 'worksheet-2'],
      ),
      isNull,
    );
  });

  test('avoids repeating the previous daily question set when possible', () {
    final progress = progressWithModulesThrough(1);
    final previous = selectClassroomQuestQuestions(
      progress,
      random: Random(4),
    );
    final next = selectClassroomQuestQuestions(
      progress,
      random: Random(4),
      previousQuestionIds: previous.map((question) => question.id).toList(),
    );

    expect(
      next.map((question) => question.id).toSet(),
      isNot(equals(previous.map((question) => question.id).toSet())),
    );
  });
}
