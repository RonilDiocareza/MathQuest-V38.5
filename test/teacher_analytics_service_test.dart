import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/services/teacher_analytics_service.dart';

void main() {
  test('parses the saved user progress document by its Firestore UID', () {
    final student = StudentAnalytics.fromUserDocument('student-1', {
      'name': 'Student One',
      'status': 'approved',
      'gameScore': 180,
      'progress': {
        'completedLevels': [1, 4, 4, 61, 'bad'],
        'completedNpcQuestions': [1, 2, 2, 7],
        'completedNpcQuestionsByLevel': {
          '1': [1, 2],
          '4': [1, 3, 3],
          'bad': [1, 2],
        },
        'questAttempts': 3,
        'classroomQuestCompletionTimes': {'classroom_quest': 95},
        'classroomQuestResults': {
          'classroom_quest': {
            'score': 30,
            'correctAnswers': 3,
            'totalQuestions': 3,
            'completionTimeSeconds': 90,
          },
        },
        'gameModeFinalScores': {'1': 50, '2': 80, 'invalid': 20},
      },
    });

    expect(student.uid, 'student-1');
    expect(student.name, 'Student One');
    expect(student.status, 'approved');
    expect(student.hasProgressRecord, isTrue);
    expect(student.score, 180);
    expect(student.completedLevelNumbers, [1, 4]);
    expect(student.levelsCompleted, 2);
    expect(student.levelProgress, '3.3');
    expect(student.questAttempts, 3);
    expect(student.classroomQuestScore, 30);
    expect(student.classroomQuestCorrectAnswers, 3);
    expect(student.classroomQuestTotalQuestions, 3);
    expect(student.classroomQuestCompletionTimeSeconds, 90);
    expect(student.gameModeFinalScores, {1: 50});
    expect(student.completedNpcQuestionCount, 2);
  });

  test('includes registered students who have no progress record', () {
    final student = StudentAnalytics.fromUserDocument('pending-student', {
      'name': 'New Student',
      'status': 'pending',
    });

    expect(student.uid, 'pending-student');
    expect(student.status, 'pending');
    expect(student.hasProgressRecord, isFalse);
    expect(student.score, isNull);
    expect(student.completedLevelNumbers, isEmpty);
    expect(student.questAttempts, 0);
  });

  test('uses saved score components and does not invent a missing score', () {
    final scoredStudent = StudentAnalytics.fromUserDocument('student-2', {
      'name': 'Student Two',
      'scoreBaseline': 20,
      'scoreEarned': 35,
    });
    final unscoredStudent = StudentAnalytics.fromUserDocument('student-3', {
      'name': 'Student Three',
      'progress': {
        'completedLevels': [1, 2]
      },
    });

    expect(scoredStudent.score, 55);
    expect(unscoredStudent.score, isNull);
    expect(unscoredStudent.levelsCompleted, 2);
  });

  test('ignores malformed progress values without throwing', () {
    final student = StudentAnalytics.fromUserDocument('student-4', {
      'name': 'Student Four',
      'progress': {
        'completedLevels': 'invalid',
        'classroomQuestResults': {'classroom_quest': 'invalid'},
        'classroomQuestCompletionTimes': {'classroom_quest': 'invalid'},
        'gameModeFinalScores': {'1': 'invalid'},
        'completedNpcQuestionsByLevel': {'1': 'invalid'},
      },
    });

    expect(student.hasProgressRecord, isTrue);
    expect(student.completedLevelNumbers, isEmpty);
    expect(student.classroomQuestScore, isNull);
    expect(student.classroomQuestCompletionTimeSeconds, isNull);
    expect(student.gameModeFinalScores, isEmpty);
    expect(student.completedNpcQuestionCount, 0);
  });

  test('ranks students by levels, activity, then stable name and UID', () {
    final students = [
      StudentAnalytics.fromUserDocument('z-progress', {
        'name': 'Zed',
        'status': 'approved',
        'progress': {
          'completedLevels': [1, 2],
        },
      }),
      StudentAnalytics.fromUserDocument('a-active', {
        'name': 'Amy',
        'status': 'approved',
        'progress': {
          'completedLevels': [1],
          'completedNpcQuestions': [1, 2, 3],
        },
      }),
      StudentAnalytics.fromUserDocument('b-active', {
        'name': 'Bea',
        'status': 'approved',
        'progress': {
          'completedLevels': [1],
          'questAttempts': 2,
        },
      }),
      StudentAnalytics.fromUserDocument('new-student', {
        'name': 'New Student',
        'status': 'approved',
      }),
      StudentAnalytics.fromUserDocument('a-same-name', {
        'name': 'Amy',
        'status': 'approved',
      }),
      StudentAnalytics.fromUserDocument('z-same-name', {
        'name': 'Amy',
        'status': 'approved',
      }),
    ];

    final ranked = TeacherAnalyticsService.rankStudents(students);

    expect(
      ranked.map((student) => student.uid),
      [
        'z-progress',
        'a-active',
        'b-active',
        'a-same-name',
        'z-same-name',
        'new-student',
      ],
    );
    expect(ranked.last.levelsCompleted, 0);
    expect(ranked.last.activityCount, 0);
  });
}
