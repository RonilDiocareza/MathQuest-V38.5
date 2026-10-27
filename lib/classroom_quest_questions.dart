import 'dart:math';

import 'services/user_progress_service.dart';
import 'worksheet_lesson_data.dart';

class ClassroomQuestQuestion {
  const ClassroomQuestQuestion({
    required this.worksheetNumber,
    required this.moduleNumber,
    required this.prompt,
    required this.answer,
  });

  final int worksheetNumber;
  final int moduleNumber;
  final String prompt;
  final String answer;

  String get id => 'worksheet-$worksheetNumber';
}

List<ClassroomQuestQuestion>? classroomQuestQuestionsForIds(
  UserProgress progress,
  List<String> questionIds,
) {
  if (questionIds.length != 3 || questionIds.toSet().length != 3) return null;

  final lessonsById = {
    for (final lesson in worksheetLessons) 'worksheet-${lesson.number}': lesson,
  };
  final questions = <ClassroomQuestQuestion>[];
  for (final id in questionIds) {
    final lesson = lessonsById[id];
    if (lesson == null) return null;
    final moduleNumber = worksheetModuleIndex(lesson.number) + 1;
    if (!progress.isWorksheetModuleUnlocked(moduleNumber)) return null;
    questions.add(
      ClassroomQuestQuestion(
        worksheetNumber: lesson.number,
        moduleNumber: moduleNumber,
        prompt: lesson.question,
        answer: lesson.correctAnswer,
      ),
    );
  }
  return questions;
}

List<ClassroomQuestQuestion> selectClassroomQuestQuestions(
  UserProgress progress, {
  Random? random,
  List<String> previousQuestionIds = const [],
}) {
  final chooser = random ?? Random.secure();
  final eligible = worksheetLessons.where((lesson) {
    final moduleNumber = worksheetModuleIndex(lesson.number) + 1;
    return progress.isWorksheetModuleUnlocked(moduleNumber);
  }).toList(growable: true)
    ..shuffle(chooser);
  if (eligible.length < 3) {
    throw StateError(
      'At least three validated questions are required for Classroom Quest.',
    );
  }

  var selected = eligible.take(3).toList(growable: true);
  final previous = previousQuestionIds.toSet();
  final sameAsPrevious = previous.length == 3 &&
      selected
          .every((lesson) => previous.contains('worksheet-${lesson.number}'));
  if (sameAsPrevious && eligible.length > 3) {
    final alternatives = eligible.skip(3).where(
          (lesson) => !previous.contains('worksheet-${lesson.number}'),
        );
    if (alternatives.isNotEmpty) selected[2] = alternatives.first;
  }
  selected.shuffle(chooser);

  return selected
      .map(
        (lesson) => ClassroomQuestQuestion(
          worksheetNumber: lesson.number,
          moduleNumber: worksheetModuleIndex(lesson.number) + 1,
          prompt: lesson.question,
          answer: lesson.correctAnswer,
        ),
      )
      .toList(growable: false);
}
