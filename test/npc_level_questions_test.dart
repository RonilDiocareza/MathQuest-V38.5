import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/game/npc_question.dart';
import 'package:flutter_mathquest/services/user_progress_service.dart';
import 'package:flutter_mathquest/worksheet_lesson_data.dart';

String _fractionAnswer(int numerator, int denominator) {
  var a = numerator.abs();
  var b = denominator.abs();
  while (b != 0) {
    final remainder = a % b;
    a = b;
    b = remainder;
  }
  final divisor = a == 0 ? 1 : a;
  final sign = numerator * denominator < 0 ? '-' : '';
  final top = numerator.abs() ~/ divisor;
  final bottom = denominator.abs() ~/ divisor;
  return bottom == 1 ? '$sign$top' : '$sign$top/$bottom';
}

int _cents(String decimal) {
  final parts = decimal.split('.');
  return int.parse(parts[0]) * 100 + int.parse(parts[1]);
}

String _decimalAnswer(int cents) =>
    '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

int _evaluateIntegerExpression(String expression) {
  final tokens = RegExp(r'-?\d+|[()+−×]')
      .allMatches(expression)
      .map((match) => match.group(0)!)
      .toList(growable: false);
  var index = 0;

  int parseExpression() {
    int value;
    if (tokens[index] == '(') {
      index++;
      value = parseExpression();
      expect(tokens[index++], ')');
    } else {
      value = int.parse(tokens[index++]);
    }

    while (index < tokens.length && tokens[index] != ')') {
      final operation = tokens[index++];
      final operand = int.parse(tokens[index++]);
      value = switch (operation) {
        '+' => value + operand,
        '−' => value - operand,
        _ => value * operand,
      };
    }
    return value;
  }

  final result = parseExpression();
  expect(index, tokens.length);
  return result;
}

void _expectGeneratedAnswerIsCorrect(NpcQuestion question) {
  final answer = question.choices[question.correctAnswerIndex];
  switch (question.moduleId) {
    case 'fraction-add-subtract':
      final match = RegExp(
        r'^Calculate (\d+)/(\d+) ([+−]) (\d+)/(\d+)(?: \+ (\d+)/(\d+))?\.$',
      ).firstMatch(question.prompt);
      if (match == null) return;
      final firstNumerator = int.parse(match.group(1)!);
      final firstDenominator = int.parse(match.group(2)!);
      final secondNumerator = int.parse(match.group(4)!);
      final secondDenominator = int.parse(match.group(5)!);
      var numerator = match.group(3) == '−'
          ? firstNumerator * secondDenominator -
              secondNumerator * firstDenominator
          : firstNumerator * secondDenominator +
              secondNumerator * firstDenominator;
      var denominator = firstDenominator * secondDenominator;
      if (match.group(6) != null) {
        numerator = numerator * int.parse(match.group(7)!) +
            int.parse(match.group(6)!) * denominator;
        denominator *= int.parse(match.group(7)!);
      }
      expect(
        answer,
        _fractionAnswer(numerator, denominator),
        reason: question.prompt,
      );
    case 'fraction-multiply-divide':
      final match = RegExp(
        r'^Calculate (\d+)/(\d+) ([×÷]) (\d+)/(\d+)(?: ([×÷]) (\d+)/(\d+))?\.$',
      ).firstMatch(question.prompt);
      if (match == null) return;
      var numerator = int.parse(match.group(1)!);
      var denominator = int.parse(match.group(2)!);
      for (final (operationGroup, numeratorGroup, denominatorGroup) in [
        (3, 4, 5),
        (6, 7, 8),
      ]) {
        final operation = match.group(operationGroup);
        if (operation == null) break;
        final nextNumerator = int.parse(match.group(numeratorGroup)!);
        final nextDenominator = int.parse(match.group(denominatorGroup)!);
        if (operation == '×') {
          numerator *= nextNumerator;
          denominator *= nextDenominator;
        } else {
          numerator *= nextDenominator;
          denominator *= nextNumerator;
        }
      }
      expect(answer, _fractionAnswer(numerator, denominator),
          reason: question.prompt);
    case 'decimal-operations':
      final match = RegExp(
        r'^Calculate (\d+\.\d{2}) ([+−×÷]) (\d+\.\d{2})\.$',
      ).firstMatch(question.prompt);
      final multiMatch = RegExp(
        r'^Calculate (\d+\.\d{2}) ([+−×÷]) (\d+\.\d{2})(?: ([+−]) (\d+\.\d{2}))?\.$',
      ).firstMatch(question.prompt);
      final decimalMatch = multiMatch ?? match;
      if (decimalMatch == null) return;
      var result = _cents(decimalMatch.group(1)!);
      for (final (operationGroup, valueGroup) in [(2, 3), (4, 5)]) {
        final operation = decimalMatch.group(operationGroup);
        if (operation == null) break;
        final value = _cents(decimalMatch.group(valueGroup)!);
        result = switch (operation) {
          '+' => result + value,
          '−' => result - value,
          '×' => result * value ~/ 100,
          _ => result * 100 ~/ value,
        };
      }
      expect(answer, _decimalAnswer(result), reason: question.prompt);
    case 'solid-figures':
      const facts = <String, String>{
        'cube faces': '6',
        'cube edges': '12',
        'cube vertices': '8',
        'triangular prism faces': '5',
        'triangular prism edges': '9',
        'triangular prism vertices': '6',
        'square pyramid faces': '5',
        'square pyramid vertices': '5',
        'cylinder circular bases': '2',
        'cone vertices': '1',
      };
      final match = RegExp(r'^How many (.+) does a (.+) have\?$')
          .firstMatch(question.prompt);
      if (match != null) {
        expect(answer, facts['${match.group(2)} ${match.group(1)}']);
        return;
      }
      final combinedFaces = RegExp(
        r'^A (.+) has (\d+) faces and a (.+) has (\d+) faces\.',
      ).firstMatch(question.prompt);
      if (combinedFaces != null) {
        expect(
          answer,
          '${int.parse(combinedFaces.group(2)!) + int.parse(combinedFaces.group(4)!)}',
          reason: question.prompt,
        );
        return;
      }
      final joined = RegExp(
        r'^A (.+) and a (.+) are joined at one vertex\.',
      ).firstMatch(question.prompt);
      if (joined != null) {
        const vertices = {
          'cube': 8,
          'triangular prism': 6,
          'square pyramid': 5,
          'tetrahedron': 4,
          'octahedron': 6,
          'pentagonal prism': 10,
        };
        expect(
          answer,
          '${vertices[joined.group(1)]! + vertices[joined.group(2)]! - 1}',
          reason: question.prompt,
        );
        return;
      }
      final euler = RegExp(
        r'^A (.+) has (\d+) faces and (\d+) edges\. Using V − E \+ F = 2, how many vertices',
      ).firstMatch(question.prompt);
      if (euler != null) {
        expect(
          answer,
          '${int.parse(euler.group(3)!) - int.parse(euler.group(2)!) + 2}',
          reason: question.prompt,
        );
        return;
      }
      final edges = RegExp(
        r'^A (.+) has (\d+) faces and (\d+) vertices\. Using V − E \+ F = 2, how many edges',
      ).firstMatch(question.prompt);
      if (edges != null) {
        expect(
          answer,
          '${int.parse(edges.group(2)!) + int.parse(edges.group(3)!) - 2}',
          reason: question.prompt,
        );
        return;
      }
      final faces = RegExp(
        r'^A (.+) has (\d+) edges and (\d+) vertices\. Using V − E \+ F = 2, how many faces',
      ).firstMatch(question.prompt);
      if (faces != null) {
        expect(
          answer,
          '${int.parse(faces.group(2)!) - int.parse(faces.group(3)!) + 2}',
          reason: question.prompt,
        );
      }
    case 'speed-distance-time':
      final distanceQuestion = RegExp(
        r'^A vehicle travels at (\d+) km/h for (\d+) hours\.',
      ).firstMatch(question.prompt);
      final speedQuestion = RegExp(
        r'^A vehicle travels (\d+) km in (\d+) hours\.',
      ).firstMatch(question.prompt);
      final timeQuestion = RegExp(
        r'^A vehicle travels (\d+) km at (\d+) km/h\.',
      ).firstMatch(question.prompt);
      if (distanceQuestion != null) {
        expect(
          answer,
          '${int.parse(distanceQuestion.group(1)!) * int.parse(distanceQuestion.group(2)!)} km',
          reason: question.prompt,
        );
      } else if (speedQuestion != null) {
        expect(
          answer,
          '${int.parse(speedQuestion.group(1)!) ~/ int.parse(speedQuestion.group(2)!)} km/h',
          reason: question.prompt,
        );
      } else if (timeQuestion != null) {
        expect(
          answer,
          '${int.parse(timeQuestion.group(1)!) ~/ int.parse(timeQuestion.group(2)!)} hours',
          reason: question.prompt,
        );
      } else {
        final twoLeg = RegExp(
          r'^A vehicle travels at (\d+) km/h for (\d+) hours, then at (\d+) km/h for (\d+) hours\.',
        ).firstMatch(question.prompt);
        if (twoLeg != null) {
          final distance =
              int.parse(twoLeg.group(1)!) * int.parse(twoLeg.group(2)!) +
                  int.parse(twoLeg.group(3)!) * int.parse(twoLeg.group(4)!);
          expect(answer, '$distance km', reason: question.prompt);
        }
      }
    case 'area-surface-area':
      final rectangle = RegExp(
        r'^A rectangle is (\d+) units long and (\d+) units wide\.',
      ).firstMatch(question.prompt);
      final cube = RegExp(
        r'^What is the surface area of a cube with side length (\d+) units\?',
      ).firstMatch(question.prompt);
      final prism = RegExp(
        r'^What is the surface area of a rectangular prism with length (\d+), width (\d+), and height (\d+) units\?',
      ).firstMatch(question.prompt);
      if (rectangle != null) {
        expect(
          answer,
          '${int.parse(rectangle.group(1)!) * int.parse(rectangle.group(2)!)} square units',
          reason: question.prompt,
        );
      } else if (cube != null) {
        final side = int.parse(cube.group(1)!);
        expect(answer, '${6 * side * side} square units',
            reason: question.prompt);
      } else if (prism != null) {
        final length = int.parse(prism.group(1)!);
        final width = int.parse(prism.group(2)!);
        final height = int.parse(prism.group(3)!);
        final area = 2 * (length * width + length * height + width * height);
        expect(answer, '$area square units', reason: question.prompt);
      } else {
        final cutout = RegExp(
          r'^A (\d+) by (\d+) rectangle has a (\d+) by (\d+) rectangular corner removed\.',
        ).firstMatch(question.prompt);
        if (cutout != null) {
          final area =
              int.parse(cutout.group(1)!) * int.parse(cutout.group(2)!) -
                  int.parse(cutout.group(3)!) * int.parse(cutout.group(4)!);
          expect(answer, '$area square units', reason: question.prompt);
        }
      }
    case 'listing-outcomes':
      final match = RegExp(
        r'^How many different outcomes are possible when tossing (\d+) coins\?$',
      ).firstMatch(question.prompt);
      if (match != null) {
        expect(answer, '${1 << int.parse(match.group(1)!)}');
      } else {
        final choices = RegExp(
          r'^There are (\d+) choices for one item and (\d+) choices for another(?: and (\d+) choices for a third item)?\.',
        ).firstMatch(question.prompt);
        if (choices != null) {
          final outcomeCount = int.parse(choices.group(1)!) *
              int.parse(choices.group(2)!) *
              (int.tryParse(choices.group(3) ?? '') ?? 1);
          expect(answer, '$outcomeCount', reason: question.prompt);
        }
      }
    case 'integer-operations':
      final match = RegExp(
        r'^Calculate (\(-?\d+\)|-?\d+) ([+−×÷]) (\(-?\d+\)|-?\d+)\.$',
      ).firstMatch(question.prompt);
      final expressionMatch =
          RegExp(r'^Calculate (.+)\.$').firstMatch(question.prompt);
      if (match != null) {
        int operand(String value) =>
            int.parse(value.replaceAll('(', '').replaceAll(')', ''));
        final first = operand(match.group(1)!);
        final second = operand(match.group(3)!);
        final result = switch (match.group(2)) {
          '+' => first + second,
          '−' => first - second,
          '×' => first * second,
          _ => first ~/ second,
        };
        expect(answer, '$result', reason: question.prompt);
      } else if (expressionMatch != null) {
        expect(
          answer,
          '${_evaluateIntegerExpression(expressionMatch.group(1)!)}',
          reason: question.prompt,
        );
      }
  }
}

void main() {
  test('every level receives lesson-aligned questions with valid choices', () {
    for (var questionNumber = 1;
        questionNumber <= NpcQuestion.all.length;
        questionNumber++) {
      for (var level = 1; level <= 60; level++) {
        final question = NpcQuestion.forLevel(questionNumber, level);
        final moduleIndex = gameModeModuleIndexForLevel(level);
        final moduleId = worksheetModuleIds[moduleIndex];
        final moduleLessons = worksheetLessons
            .where((lesson) => lesson.moduleId == moduleId)
            .toList(growable: false);
        expect(moduleLessons, isNotEmpty);
        expect(question.moduleId, moduleId);
        expect(question.module, worksheetModuleNames[moduleIndex]);
        expect(question.semester, worksheetModuleSemesters[moduleIndex]);
        expect(question.topic, worksheetModuleNames[moduleIndex]);
        if (!question.isExtra) {
          expect(
            moduleLessons.any((lesson) =>
                lesson.title == question.lesson &&
                lesson.question == question.prompt),
            isTrue,
          );
        }
        expect(question.choices, hasLength(3));
        expect(
          question.correctAnswerIndex,
          inInclusiveRange(0, question.choices.length - 1),
        );
        expect(
          question.choices.toSet(),
          hasLength(3),
          reason: question.lesson,
        );
      }
    }
  });

  test('Game Mode topics follow the requested 60-level module sequence', () {
    expect(gameModeModuleStartLevels, [1, 9, 14, 21, 26, 31, 36, 41]);
    expect(gameModeModuleEndLevels, [8, 13, 20, 25, 30, 35, 40, 60]);
    expect(gameModeTopicRanges, hasLength(8));
    for (final (level, expectedModule) in <(int, int)>[
      (1, 0),
      (8, 0),
      (9, 1),
      (13, 1),
      (14, 2),
      (20, 2),
      (21, 3),
      (25, 3),
      (26, 4),
      (30, 4),
      (31, 5),
      (35, 5),
      (36, 6),
      (40, 6),
      (41, 7),
      (60, 7),
    ]) {
      expect(gameModeModuleIndexForLevel(level), expectedModule);
    }

    for (var level = 1; level <= 60; level++) {
      final moduleIndex = gameModeModuleIndexForLevel(level);
      for (var questionNumber = 1;
          questionNumber <= NpcQuestion.all.length;
          questionNumber++) {
        final question = NpcQuestion.forLevel(questionNumber, level);
        expect(question.moduleId, worksheetModuleIds[moduleIndex]);
      }
    }
  });

  test('question seed selects a stable lesson and preserves its answer key',
      () {
    for (var questionNumber = 1;
        questionNumber <= NpcQuestion.all.length;
        questionNumber++) {
      final first = NpcQuestion.forLevel(
        questionNumber,
        1,
        questionSeed: 0,
      );
      final second = NpcQuestion.forLevel(
        questionNumber,
        1,
        questionSeed: 1,
      );

      final repeated = NpcQuestion.forLevel(
        questionNumber,
        1,
        questionSeed: 0,
      );
      expect(repeated.id, first.id);
      expect(repeated.prompt, first.prompt);
      expect(second.id, isNot(first.id));
      expect(first.choices[first.correctAnswerIndex], isNotEmpty);
      expect(second.choices[second.correctAnswerIndex], isNotEmpty);
      expect(first.choices.toSet(), hasLength(3));
      expect(second.choices.toSet(), hasLength(3));
    }
  });

  test('practice batches use each module and avoid repeated prompts', () {
    for (var moduleIndex = 0;
        moduleIndex < worksheetModuleIds.length;
        moduleIndex++) {
      final questions = NpcQuestion.practiceQuestionsForModule(
        moduleIndex,
        random: Random(900 + moduleIndex),
      );

      expect(questions, hasLength(10));
      expect(
        questions.map((question) => question.prompt).toSet(),
        hasLength(10),
      );
      for (final question in questions) {
        expect(question.moduleId, worksheetModuleIds[moduleIndex]);
        expect(question.choices, hasLength(3));
        expect(question.choices.toSet(), hasLength(3));
        expect(
          question.correctAnswerIndex,
          inInclusiveRange(0, question.choices.length - 1),
        );
        _expectGeneratedAnswerIsCorrect(question);
      }
    }
  });

  test('six randomized NPC placements have unique stable topic questions', () {
    for (var level = 1; level <= 60; level++) {
      final seed = 812 + level;
      final firstAttempt = NpcQuestion.createNpcPlacements(
        playerSpawn: Vector2.zero(),
        canOccupy: (center, radius) => true,
        level: level,
        random: Random(seed),
      );
      final repeatedAttempt = NpcQuestion.createNpcPlacements(
        playerSpawn: Vector2.zero(),
        canOccupy: (center, radius) => true,
        level: level,
        random: Random(seed),
      );
      final otherAttempt = NpcQuestion.createNpcPlacements(
        playerSpawn: Vector2.zero(),
        canOccupy: (center, radius) => true,
        level: level,
        random: Random(seed + 101),
      );
      final questions = firstAttempt
          .map(NpcQuestion.forPlacement)
          .whereType<NpcQuestion>()
          .toList(growable: false);
      final expectedModule =
          worksheetModuleIds[gameModeModuleIndexForLevel(level)];

      expect(questions, hasLength(6), reason: 'Level $level');
      expect(
        questions.map((question) => question.prompt).toSet(),
        hasLength(6),
        reason: 'Level $level',
      );
      expect(
        questions.map((question) => question.moduleId).toSet(),
        {expectedModule},
        reason: 'Level $level',
      );
      for (var index = 0; index < firstAttempt.length; index++) {
        final first = NpcQuestion.forPlacement(firstAttempt[index]);
        final repeated = NpcQuestion.forPlacement(repeatedAttempt[index]);
        expect(repeated?.id, first?.id,
            reason: 'Level $level, NPC ${index + 1}');
        expect(repeated?.prompt, first?.prompt,
            reason: 'Level $level, NPC ${index + 1}');
        expect(
          repeated!.choices[repeated.correctAnswerIndex],
          first!.choices[first.correctAnswerIndex],
        );
      }
      expect(
        firstAttempt.map((placement) => placement.questionId).toSet(),
        isNot(equals(
          otherAttempt.map((placement) => placement.questionId).toSet(),
        )),
        reason: 'Level $level should vary between attempts',
      );
    }
  });

  test('generated module variants have mathematically correct answers', () {
    const firstLevels = [1, 9, 14, 21, 26, 31, 36, 41];
    for (var moduleIndex = 0; moduleIndex < firstLevels.length; moduleIndex++) {
      final questions = NpcQuestion.extraQuestionsForLevel(
        1,
        firstLevels[moduleIndex],
        random: Random(500 + moduleIndex),
      );
      expect(questions, hasLength(10));
      for (final question in questions) {
        expect(question.moduleId, worksheetModuleIds[moduleIndex]);
        _expectGeneratedAnswerIsCorrect(question);
      }
    }
  });

  test('advanced generated questions have mathematically correct answers', () {
    for (var level = 1; level <= 60; level++) {
      for (final question in NpcQuestion.extraQuestionsForLevel(1, level)) {
        expect(
          question.difficulty,
          NpcQuestion.difficultyForLevel(level),
          reason: question.prompt,
        );
        expect(
          question.choices.toSet(),
          hasLength(3),
          reason: question.prompt,
        );
        _expectGeneratedAnswerIsCorrect(question);
      }
    }
  });

  test('all worksheet lessons have distinct, keyed question choices', () {
    expect(worksheetLessons, hasLength(67));
    for (final worksheet in worksheetLessons) {
      expect(worksheet.choices, hasLength(3), reason: worksheet.title);
      expect(
        worksheet.choices.toSet(),
        hasLength(3),
        reason: worksheet.title,
      );
      expect(
        worksheet.choices[worksheet.correctAnswerIndex],
        worksheet.correctAnswer,
        reason: worksheet.title,
      );
    }
  });

  test('representative worksheet answers follow the stated calculations', () {
    const expectedAnswers = <int, String>{
      1: '1/2',
      2: '0',
      3: '3 3/4',
      4: '2 3/4',
      5: '1',
      6: '1/2',
      7: '1/2',
      8: '7/8',
      9: '5/8',
      10: '3',
      11: '3',
      12: '1',
      13: '2',
      19: '0.60',
      20: '3.60',
      21: '8',
      22: '30',
      23: '45.6',
      24: '9',
      25: '25.00',
      26: '0.36',
      36: '190 km',
      37: '195 km',
      38: '22 square units',
      41: '52 square units',
      42: '36 square units',
      43: '96 square units',
      44: '56 square units',
      45: '62.8 square units',
      46: '75.36 square units',
      47: '50.24 square units',
      48: '4',
      52: '8',
      53: '-10',
      54: '2',
      55: '2',
      56: '2',
      57: '-2',
      58: '20',
      59: '-22',
      60: '2',
      61: '168',
      62: '195',
      63: '-224',
      64: '255',
      65: '18',
      66: '-19',
      67: '20',
    };

    for (final entry in expectedAnswers.entries) {
      expect(
        worksheetLessons[entry.key - 1].correctAnswer,
        entry.value,
        reason: worksheetLessons[entry.key - 1].title,
      );
    }
  });

  test('saved Level Question answer preserves the generated expression', () {
    const savedAnswer = LevelQuestionAnswer(
      firstOperand: 12,
      secondOperand: 12,
      operation: '+',
      correctAnswer: 24,
    );

    final restored = LevelQuestionAnswer.fromData(savedAnswer.toData());

    expect(restored.firstOperand, 12);
    expect(restored.secondOperand, 12);
    expect(restored.operation, '+');
    expect(restored.correctAnswer, 24);
    expect(
      () => LevelQuestionAnswer.fromData({
        ...savedAnswer.toData(),
        'correctAnswer': 25,
      }),
      throwsFormatException,
    );
  });

  test('NPC completion is isolated to its Game Mode level', () {
    final progress = UserProgress(
      completedLevels: const [],
      completedNpcQuestions: const [1, 2, 3, 4, 5, 6],
      completedNpcQuestionsByLevel: const {
        2: [1, 2],
        3: [1, 2, 3, 4, 5, 6],
      },
      unlockedLevels: 1,
      questAttempts: 0,
      maxUnlockedSubLevel: const {1: 1, 2: 1, 3: 1},
    );

    expect(progress.areNpcQuestionsCompletedForLevel(1), isTrue);
    expect(progress.currentNpcQuestionNumberForLevel(2), 3);
    expect(progress.areNpcQuestionsCompletedForLevel(3), isTrue);
    expect(progress.currentNpcQuestionNumberForLevel(4), 1);
    expect(progress.areNpcQuestionsCompletedForLevel(4), isFalse);
  });

  test('Game Mode topics unlock after the previous topic is complete', () {
    final firstTopicComplete = UserProgress(
      completedLevels: const [],
      completedNpcQuestions: const [],
      unlockedLevels: 1,
      questAttempts: 0,
      maxUnlockedSubLevel: const {},
      gameModeFinalScores: const {
        1: 10,
        2: 10,
        3: 10,
        4: 10,
        5: 10,
        6: 10,
        7: 10,
        8: 10,
      },
    );
    expect(firstTopicComplete.isGameModeTopicUnlocked(1), isTrue);
    expect(firstTopicComplete.isGameModeTopicUnlocked(8), isTrue);
    expect(firstTopicComplete.isGameModeTopicUnlocked(9), isTrue);
    expect(firstTopicComplete.isGameModeTopicUnlocked(14), isFalse);

    final allTransitionsComplete = UserProgress(
      completedLevels: const [],
      completedNpcQuestions: const [],
      unlockedLevels: 1,
      questAttempts: 0,
      maxUnlockedSubLevel: const {},
      gameModeFinalScores: {
        for (var level = 1; level <= 40; level++) level: 0,
      },
    );
    for (final level in [9, 14, 21, 26, 31, 36, 41, 60]) {
      expect(
        allTransitionsComplete.isGameModeTopicUnlocked(level),
        isTrue,
        reason: 'Level $level should unlock after its prior topic is complete',
      );
    }
    expect(
      allTransitionsComplete.nextRequiredGameModeLevelForTopic(41),
      null,
    );

    final problemLevelsOnly = UserProgress(
      completedLevels: List.generate(40, (index) => index + 1),
      completedNpcQuestions: const [],
      unlockedLevels: 40,
      questAttempts: 0,
      maxUnlockedSubLevel: const {},
    );
    expect(problemLevelsOnly.isGameModeTopicUnlocked(41), isFalse);
    expect(problemLevelsOnly.nextRequiredGameModeLevelForTopic(41), 1);
  });

  test('badge progress counts completed NPC answers and rounds', () {
    final progress = UserProgress(
      completedLevels: const [1, 2],
      completedNpcQuestions: const [1, 2, 3, 4, 5, 6],
      completedNpcQuestionsByLevel: const {
        2: [1, 2, 3],
        3: [1, 2, 3, 4, 5, 6],
      },
      unlockedLevels: 2,
      questAttempts: 4,
      maxUnlockedSubLevel: const {1: 1, 2: 1, 3: 1},
    );

    expect(progress.completedNpcQuestionCount, 15);
    expect(progress.completedNpcRoundCount, 2);
  });

  test('badge progress avoids double-counting legacy NPC level one data', () {
    final progress = UserProgress(
      completedLevels: const [],
      completedNpcQuestions: const [1, 2, 3, 4, 5, 6],
      completedNpcQuestionsByLevel: const {
        1: [1, 2, 3, 4, 5, 6],
      },
      unlockedLevels: 1,
      questAttempts: 0,
      maxUnlockedSubLevel: const {1: 1, 2: 1, 3: 1},
    );

    expect(progress.completedNpcQuestionCount, 6);
    expect(progress.completedNpcRoundCount, 1);
  });
}
