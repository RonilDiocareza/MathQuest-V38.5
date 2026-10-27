import 'package:flame/components.dart';
import 'dart:math';
import '../worksheet_lesson_data.dart';

class QuestionNpcPlacement {
  static const double physicalCollisionRadius = 8;

  final int level;
  final int questionNumber;
  final String questionId;
  final String topic;
  final Vector2 position;
  final String spriteAssetPath;
  final double collisionRadius;
  final int questionSeed;

  const QuestionNpcPlacement({
    this.level = 1,
    this.questionNumber = 1,
    required this.questionId,
    required this.topic,
    required this.position,
    this.spriteAssetPath = 'assets/images/npcs/np1.png',
    this.collisionRadius = physicalCollisionRadius,
    this.questionSeed = 0,
  });
}

class NpcQuestion {
  final String id;
  final int questionNumber;
  final String semester;
  final String module;
  final String moduleId;
  final String lesson;
  final String topic;
  final String prompt;
  final List<String> choices;
  final int correctAnswerIndex;
  final bool isExtra;
  final int difficulty;

  const NpcQuestion({
    required this.id,
    this.questionNumber = 1,
    this.semester = '',
    this.module = '',
    this.moduleId = '',
    this.lesson = '',
    required this.topic,
    required this.prompt,
    required this.choices,
    required this.correctAnswerIndex,
    this.isExtra = false,
    this.difficulty = 1,
  });

  NpcQuestion withTopic(String topic) => NpcQuestion(
        id: id,
        questionNumber: questionNumber,
        semester: semester,
        module: module,
        moduleId: moduleId,
        lesson: lesson,
        topic: topic,
        prompt: prompt,
        choices: choices,
        correctAnswerIndex: correctAnswerIndex,
        isExtra: isExtra,
        difficulty: difficulty,
      );

  static String normalizedPrompt(String prompt) {
    var normalized = prompt.toLowerCase();
    const equivalentCharacters = {
      '−': '-',
      '–': '-',
      '﹣': '-',
      '－': '-',
      '＋': '+',
      '×': '*',
      '·': '*',
      '∙': '*',
      '⋅': '*',
      '÷': '/',
      '⁄': '/',
      '／': '/',
      '½': '1/2',
      '⅓': '1/3',
      '⅔': '2/3',
      '¼': '1/4',
      '¾': '3/4',
      '⅕': '1/5',
      '⅖': '2/5',
      '⅗': '3/5',
      '⅘': '4/5',
      '⅙': '1/6',
      '⅚': '5/6',
      '⅛': '1/8',
      '⅜': '3/8',
      '⅝': '5/8',
      '⅞': '7/8',
    };
    for (final entry in equivalentCharacters.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }
    return normalized
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'\.(?=$|[^0-9])'), '')
        .replaceAll(RegExp(r'[^a-z0-9/+\-*.=]'), '');
  }

  static int difficultyForLevel(int level) {
    if (level < 1 || level > 60) {
      throw RangeError.range(level, 1, 60, 'level');
    }
    return (level - 1) % 20 + 1;
  }

  static final List<NpcQuestion> all = List.generate(
    6,
    (index) => _questionForWorksheet(worksheetLessons[index], index + 1, 0),
    growable: false,
  );

  static String _fraction(int numerator, int denominator) {
    var a = numerator.abs();
    var b = denominator.abs();
    while (b != 0) {
      final remainder = a % b;
      a = b;
      b = remainder;
    }
    final divisor = a == 0 ? 1 : a;
    final sign = numerator * denominator < 0 ? '-' : '';
    final reducedNumerator = numerator.abs() ~/ divisor;
    final reducedDenominator = denominator.abs() ~/ divisor;
    return reducedDenominator == 1
        ? '$sign$reducedNumerator'
        : '$sign$reducedNumerator/$reducedDenominator';
  }

  static String _decimal(int cents) =>
      '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

  // Tiled-world coordinates for the four building entrances, central shrine,
  // and final NPC on the southern road near the map edge.
  static const List<(double, double)> _mapNpcPositions = [
    (535, 285),
    (1062, 340),
    (397, 553),
    (651, 584),
    (1120, 550),
    (468, 1016),
  ];

  static const List<String> _npcSpritePaths = [
    'assets/images/npcs/np1.png',
    'assets/images/npcs/npc2.png',
    'assets/images/npcs/npc3.png',
    'assets/images/npcs/npc4.png',
    'assets/images/npcs/npc5.png',
    'assets/images/npcs/npc6.png',
  ];

  static List<QuestionNpcPlacement> createNpcPlacements({
    required Vector2 playerSpawn,
    required bool Function(Vector2 center, double radius) canOccupy,
    int level = 1,
    Random? random,
  }) {
    final placements = <QuestionNpcPlacement>[];
    final questionRandom = random ?? Random();
    final questionNumbers = List.generate(all.length, (index) => index + 1)
      ..shuffle(questionRandom);
    final usedPrompts = <String>{};

    bool isClear(Vector2 feetPosition) {
      final radius = QuestionNpcPlacement.physicalCollisionRadius;
      final center = Vector2(feetPosition.x, feetPosition.y - radius);
      if (!canOccupy(center, radius)) return false;

      final playerFeet = Vector2(playerSpawn.x, playerSpawn.y + 21);
      if (center.distanceTo(playerFeet) < radius * 2 + 4) return false;

      return placements.every((placement) {
        final otherCenter = Vector2(
          placement.position.x,
          placement.position.y - placement.collisionRadius,
        );
        return center.distanceTo(otherCenter) >=
            radius + placement.collisionRadius + 4;
      });
    }

    for (var index = 0; index < _mapNpcPositions.length; index++) {
      final (x, y) = _mapNpcPositions[index];
      final position = Vector2(x, y);
      if (!isClear(position)) {
        throw StateError(
          'Question NPC ${index + 1} cannot be placed safely at its building door.',
        );
      }
      final questionNumber = questionNumbers[index];
      var selectedSeed = questionRandom.nextInt(1 << 31);
      NpcQuestion? selectedQuestion;
      for (var attempt = 0; attempt < 128; attempt++) {
        selectedSeed = questionRandom.nextInt(1 << 31);
        final candidate = forLevel(
          questionNumber,
          level,
          questionSeed: selectedSeed,
        );
        if (usedPrompts.add(candidate.prompt)) {
          selectedQuestion = candidate;
          break;
        }
      }
      if (selectedQuestion == null) {
        throw StateError(
          'The worksheet module for level $level cannot supply six unique NPC questions.',
        );
      }
      placements.add(
        _placementAt(index, position, level, questionNumber, selectedSeed),
      );
    }

    if (placements.length != all.length) {
      throw StateError(
        'Only ${placements.length} of ${all.length} NPCs have a safe map location.',
      );
    }

    return placements;
  }

  static QuestionNpcPlacement _placementAt(
    int index,
    Vector2 position,
    int level,
    int questionNumber,
    int questionSeed,
  ) {
    final question =
        forLevel(questionNumber, level, questionSeed: questionSeed);
    return QuestionNpcPlacement(
      level: level,
      questionNumber: questionNumber,
      questionId: question.id,
      topic: question.topic,
      position: position,
      spriteAssetPath: _npcSpritePaths[index],
      questionSeed: questionSeed,
    );
  }

  static NpcQuestion? forPlacement(QuestionNpcPlacement placement) {
    if (placement.questionNumber < 1 || placement.questionNumber > all.length) {
      return null;
    }
    final question = forLevel(
      placement.questionNumber,
      placement.level,
      questionSeed: placement.questionSeed,
    );
    if (question.id != placement.questionId) return null;
    return question.withTopic(placement.topic);
  }

  static NpcQuestion forLevel(
    int questionNumber,
    int level, {
    int? questionSeed,
  }) {
    if (questionNumber < 1 || questionNumber > all.length) {
      throw ArgumentError.value(questionNumber, 'questionNumber');
    }
    if (level < 1 || level > 60) {
      throw ArgumentError.value(level, 'level');
    }
    final moduleIndex = gameModeModuleIndexForLevel(level);
    final topicRange = gameModeTopicRanges[moduleIndex];
    final moduleId = topicRange.moduleId;
    final moduleLessons = worksheetLessons
        .where((lesson) => lesson.moduleId == moduleId)
        .toList(growable: false);
    final seed = questionSeed ?? level * 101 + questionNumber;
    final bankIndex = (seed & 0x7fffffff) % (moduleLessons.length + 10);
    final difficulty = difficultyForLevel(level);
    if (bankIndex < moduleLessons.length && difficulty == 1) {
      return _questionForWorksheet(
        moduleLessons[bankIndex],
        questionNumber,
        seed,
        difficulty: difficulty,
      );
    }
    return _extraQuestion(
      npcNumber: questionNumber,
      level: level,
      moduleIndex: moduleIndex,
      moduleId: moduleId,
      topic: worksheetModuleNames[moduleIndex],
      semester: worksheetModuleSemesters[moduleIndex],
      questionIndex: (bankIndex % 10) + 1,
      questionSeed: seed,
    );
  }

  static List<NpcQuestion> practiceQuestionsForModule(
    int moduleIndex, {
    int count = 10,
    Random? random,
  }) {
    if (moduleIndex < 0 || moduleIndex >= worksheetModuleIds.length) {
      throw RangeError.index(moduleIndex, worksheetModuleIds);
    }
    if (count < 1) {
      throw ArgumentError.value(count, 'count', 'Must be greater than zero.');
    }

    final topicRange = gameModeTopicRanges[moduleIndex];
    if (topicRange.moduleId != worksheetModuleIds[moduleIndex]) {
      throw StateError(
        'Question topic mapping does not match worksheet module '
        '${worksheetModuleIds[moduleIndex]}.',
      );
    }

    final questionRandom = random ?? Random();
    final questions = <NpcQuestion>[];
    final usedPrompts = <String>{};
    final attemptLimit = count * 128;
    for (var attempt = 0;
        attempt < attemptLimit && questions.length < count;
        attempt++) {
      final candidate = forLevel(
        1,
        topicRange.firstLevel,
        questionSeed: questionRandom.nextInt(1 << 31),
      );
      if (usedPrompts.add(candidate.prompt)) {
        questions.add(candidate);
      }
    }

    if (questions.length != count) {
      throw StateError(
        'Module "${worksheetModuleNames[moduleIndex]}" could not provide '
        '$count unique practice questions.',
      );
    }
    return List.unmodifiable(questions);
  }

  static List<NpcQuestion> extraQuestionsForLevel(
    int npcNumber,
    int level, {
    Random? random,
  }) {
    if (npcNumber < 1 || npcNumber > all.length) {
      throw ArgumentError.value(npcNumber, 'npcNumber');
    }
    if (level < 1 || level > 60) {
      throw ArgumentError.value(level, 'level');
    }

    final moduleIndex = gameModeModuleIndexForLevel(level);
    final moduleId = worksheetModuleIds[moduleIndex];
    final topic = worksheetModuleNames[moduleIndex];
    final semester = worksheetModuleSemesters[moduleIndex];
    final questionRandom = random ?? Random();
    final prompts = <String>{};
    final questions = <NpcQuestion>[];
    for (var index = 1; index <= 10; index++) {
      NpcQuestion? question;
      for (var attempt = 0; attempt < 128; attempt++) {
        final candidate = _extraQuestion(
          npcNumber: npcNumber,
          level: level,
          moduleIndex: moduleIndex,
          moduleId: moduleId,
          topic: topic,
          semester: semester,
          questionIndex: index,
          questionSeed: questionRandom.nextInt(1 << 31),
        );
        if (prompts.add(candidate.prompt)) {
          question = candidate;
          break;
        }
      }
      if (question == null) {
        throw StateError(
          'Module "$topic" cannot provide ten unique extra questions for NPC $npcNumber at level $level.',
        );
      }
      questions.add(question);
    }
    return List.unmodifiable(questions);
  }

  static NpcQuestion _extraQuestion({
    required int npcNumber,
    required int level,
    required int moduleIndex,
    required String moduleId,
    required String topic,
    required String semester,
    required int questionIndex,
    int? questionSeed,
  }) {
    final seed = questionSeed ?? npcNumber * 17 + questionIndex * 11;
    final variation = Random(seed);
    final difficulty = difficultyForLevel(level);
    late String prompt;
    late String answer;
    late List<String> distractors;

    switch (moduleIndex) {
      case 0:
        final denominator = 8 + questionIndex + difficulty * 2;
        final firstNumerator =
            denominator ~/ 2 + variation.nextInt(denominator ~/ 3);
        final secondNumerator = 1 + variation.nextInt(firstNumerator - 1);
        final subtract = questionIndex.isEven;
        final secondDenominator = difficulty >= 5
            ? denominator + 1 + variation.nextInt(4)
            : denominator;
        var resultNumerator = subtract
            ? firstNumerator * secondDenominator - secondNumerator * denominator
            : firstNumerator * secondDenominator +
                secondNumerator * denominator;
        var resultDenominator = denominator * secondDenominator;
        final operation = subtract ? '−' : '+';
        prompt = 'Calculate $firstNumerator/$denominator $operation '
            '$secondNumerator/$secondDenominator';
        if (difficulty >= 7) {
          final thirdDenominator = denominator + 2;
          final thirdNumerator = 1 + variation.nextInt(thirdDenominator - 1);
          resultNumerator = resultNumerator * thirdDenominator +
              thirdNumerator * resultDenominator;
          resultDenominator *= thirdDenominator;
          prompt += ' + $thirdNumerator/$thirdDenominator';
        }
        prompt += '.';
        answer = _fraction(resultNumerator, resultDenominator);
        distractors = [
          _fraction(resultNumerator + 1, resultDenominator),
          _fraction(resultNumerator + 2, resultDenominator),
        ];
      case 1:
        final operandCount = difficulty >= 12 ? 3 : 2;
        final operands = List.generate(
          operandCount,
          (_) => (
            1 + variation.nextInt(2 + difficulty ~/ 3),
            2 + variation.nextInt(3 + difficulty ~/ 2),
          ),
        );
        final operations = List.generate(
          operandCount - 1,
          (index) => (index + questionIndex).isEven ? '×' : '÷',
        );
        var numerator = operands.first.$1;
        var denominator = operands.first.$2;
        for (var index = 0; index < operations.length; index++) {
          final (nextNumerator, nextDenominator) = operands[index + 1];
          if (operations[index] == '×') {
            numerator *= nextNumerator;
            denominator *= nextDenominator;
          } else {
            numerator *= nextDenominator;
            denominator *= nextNumerator;
          }
        }
        prompt = 'Calculate ${operands.first.$1}/${operands.first.$2} '
            '${operations.first} ${operands[1].$1}/${operands[1].$2}';
        if (operandCount == 3) {
          prompt += ' ${operations[1]} ${operands[2].$1}/${operands[2].$2}';
        }
        prompt += '.';
        answer = _fraction(numerator, denominator);
        distractors = [
          _fraction(numerator + 1, denominator),
          _fraction(numerator + 2, denominator),
        ];
      case 2:
        final scale = 100 + (difficulty - 13) * 50;
        final firstCents = 500 + variation.nextInt(4500) * scale;
        final secondCents = min(
          (50 + variation.nextInt(800)) * scale,
          firstCents - 50,
        );
        late int resultCents;
        late String operation;
        switch (questionIndex % 4) {
          case 0:
            operation = '+';
            resultCents = firstCents + secondCents;
          case 1:
            operation = '−';
            resultCents = firstCents - secondCents;
          case 2:
            operation = '×';
            resultCents = firstCents * 50 ~/ 100;
          default:
            operation = '÷';
            resultCents = firstCents * 2;
        }
        final secondOperand = operation == '×'
            ? '0.50'
            : operation == '÷'
                ? '0.50'
                : _decimal(secondCents);
        prompt = 'Calculate ${_decimal(firstCents)} $operation $secondOperand';
        if (difficulty >= 18 && operation != '×' && operation != '÷') {
          final thirdCents = 1 + variation.nextInt(resultCents);
          final thirdOperation = questionIndex.isEven ? '+' : '−';
          resultCents += thirdOperation == '+' ? thirdCents : -thirdCents;
          prompt += ' $thirdOperation ${_decimal(thirdCents)}';
        }
        prompt += '.';
        answer = _decimal(resultCents);
        distractors = [
          _decimal(resultCents + 10),
          _decimal(resultCents + 20),
        ];
      case 3:
        const facts = <(String, String, String, int)>[
          ('cube', 'faces', '6', 6),
          ('cube', 'edges', '12', 12),
          ('cube', 'vertices', '8', 8),
          ('triangular prism', 'faces', '5', 5),
          ('triangular prism', 'edges', '9', 9),
          ('triangular prism', 'vertices', '6', 6),
          ('square pyramid', 'faces', '5', 5),
          ('square pyramid', 'vertices', '5', 5),
          ('cylinder', 'circular bases', '2', 2),
          ('cone', 'vertices', '1', 1),
        ];
        const solids = <(String, int, int, int)>[
          ('cube', 6, 12, 8),
          ('triangular prism', 5, 9, 6),
          ('square pyramid', 5, 8, 5),
          ('tetrahedron', 4, 6, 4),
          ('octahedron', 8, 12, 6),
          ('pentagonal prism', 7, 15, 10),
        ];
        if (difficulty <= 2) {
          final factIndex =
              (questionIndex - 1 + npcNumber + level) % facts.length;
          final (shape, property, value, count) = facts[factIndex];
          prompt = 'How many $property does a $shape have?';
          answer = value;
          distractors = ['${count + 1}', '${count + 2}'];
        } else if (difficulty == 3) {
          final firstIndex =
              (questionIndex + npcNumber + level) % solids.length;
          final first = solids[firstIndex];
          final second = solids[
              (firstIndex + 1 + (questionIndex - 1) ~/ solids.length) %
                  solids.length];
          final faces = first.$2 + second.$2;
          prompt = 'A ${first.$1} has ${first.$2} faces and a ${second.$1} '
              'has ${second.$2} faces. How many faces do they have altogether?';
          answer = '$faces';
          distractors = ['${faces + 1}', '${faces + 2}'];
        } else {
          if (difficulty >= 5) {
            final firstIndex = (questionIndex + npcNumber) % solids.length;
            final first = solids[firstIndex];
            final second = solids[
                (firstIndex + 1 + (questionIndex - 1) ~/ solids.length) %
                    solids.length];
            final vertices = first.$4 + second.$4 - 1;
            prompt = 'A ${first.$1} and a ${second.$1} are joined at one '
                'vertex. How many vertices do they have altogether?';
            answer = '$vertices';
            distractors = ['${vertices + 1}', '${vertices + 2}'];
          } else {
            final first =
                solids[(questionIndex - 1 + npcNumber + level) % solids.length];
            switch ((questionIndex - 1) ~/ solids.length) {
              case 0:
                final value = first.$4;
                prompt = 'A ${first.$1} has ${first.$2} faces and ${first.$3} '
                    'edges. Using V − E + F = 2, how many vertices does it have?';
                answer = '$value';
                distractors = ['${value + 1}', '${value + 2}'];
              case 1:
                final value = first.$3;
                prompt = 'A ${first.$1} has ${first.$2} faces and ${first.$4} '
                    'vertices. Using V − E + F = 2, how many edges does it have?';
                answer = '$value';
                distractors = ['${value + 1}', '${value + 2}'];
              default:
                final value = first.$2;
                prompt = 'A ${first.$1} has ${first.$3} edges and ${first.$4} '
                    'vertices. Using V − E + F = 2, how many faces does it have?';
                answer = '$value';
                distractors = ['${value + 1}', '${value + 2}'];
            }
          }
        }
      case 4:
        final speed = 20 + variation.nextInt(40 + difficulty * 4);
        final time = 2 + variation.nextInt(2 + difficulty ~/ 2);
        final distance = speed * time;
        if (difficulty >= 9) {
          final secondSpeed = speed + 5 + variation.nextInt(20);
          final secondTime = 1 + variation.nextInt(time);
          final totalDistance = distance + secondSpeed * secondTime;
          prompt = 'A vehicle travels at $speed km/h for $time hours, then '
              'at $secondSpeed km/h for $secondTime hours. What total '
              'distance does it travel?';
          answer = '$totalDistance km';
          distractors = [
            '${totalDistance + speed} km',
            '${totalDistance + secondSpeed} km',
          ];
        } else {
          switch (questionIndex % 3) {
            case 0:
              prompt = 'A vehicle travels at $speed km/h for $time hours. '
                  'How far does it travel?';
              answer = '$distance km';
              distractors = [
                '${distance + speed} km',
                '${distance + 2 * speed} km'
              ];
            case 1:
              prompt = 'A vehicle travels $distance km in $time hours. '
                  'What is its average speed?';
              answer = '$speed km/h';
              distractors = ['${speed + 5} km/h', '${speed + 10} km/h'];
            default:
              prompt = 'A vehicle travels $distance km at $speed km/h. '
                  'How long does the trip take?';
              answer = '$time hours';
              distractors = ['${time + 1} hours', '${time + 2} hours'];
          }
        }
      case 5:
        if (difficulty >= 14) {
          final length = 6 + variation.nextInt(8 + difficulty);
          final width = 4 + variation.nextInt(6 + difficulty ~/ 2);
          final cutoutLength = 1 + variation.nextInt(length ~/ 2);
          final cutoutWidth = 1 + variation.nextInt(width ~/ 2);
          final area = length * width - cutoutLength * cutoutWidth;
          prompt = 'A $length by $width rectangle has a $cutoutLength by '
              '$cutoutWidth rectangular corner removed. What is the '
              'remaining area?';
          answer = '$area square units';
          distractors = [
            '${length * width} square units',
            '${area - 1} square units',
          ];
        } else {
          final sizeScale = difficulty - 10;
          switch (questionIndex % 3) {
            case 0:
              final length = 4 + variation.nextInt(9 * sizeScale);
              final width = 3 + variation.nextInt(7 * sizeScale);
              final area = length * width;
              prompt =
                  'A rectangle is $length units long and $width units wide. '
                  'What is its area?';
              answer = '$area square units';
              distractors = [
                '${area + 1} square units',
                '${area + 2} square units',
              ];
            case 1:
              final side = 2 + variation.nextInt(8 * sizeScale);
              final area = 6 * side * side;
              prompt = 'What is the surface area of a cube with side length '
                  '$side units?';
              answer = '$area square units';
              distractors = [
                '${area + side} square units',
                '${area + 2 * side} square units',
              ];
            default:
              final length = 2 + variation.nextInt(5 * sizeScale);
              final width = 3 + variation.nextInt(4 * sizeScale);
              final height = 2 + variation.nextInt(3 * sizeScale);
              final area =
                  2 * (length * width + length * height + width * height);
              prompt = 'What is the surface area of a rectangular prism with '
                  'length $length, width $width, and height $height units?';
              answer = '$area square units';
              distractors = [
                '${area + 1} square units',
                '${area + 2} square units',
              ];
          }
        }
      case 6:
        final choiceRange = 2 + (difficulty - 15) * 2;
        final firstChoices = 2 + variation.nextInt(choiceRange);
        final secondChoices = 2 + variation.nextInt(choiceRange);
        final thirdChoices =
            difficulty >= 18 ? 2 + variation.nextInt(choiceRange) : 1;
        final outcomes = firstChoices * secondChoices * thirdChoices;
        prompt = 'There are $firstChoices choices for one item and '
            '$secondChoices choices for another'
            '${thirdChoices == 1 ? '' : ' and $thirdChoices choices for a third item'}. '
            'How many different outcomes are possible?';
        answer = '$outcomes';
        distractors = ['${outcomes + 1}', '${outcomes + 2}'];
      case 7:
        final operands = List.generate(
          2 +
              (difficulty >= 6 ? 1 : 0) +
              (difficulty >= 12 ? 1 : 0) +
              (difficulty >= 17 ? 1 : 0),
          (_) => 2 + variation.nextInt(8 + difficulty * 3),
        );
        final operations = List.generate(
          operands.length - 1,
          (index) =>
              const ['+', '−', '×'][(index + questionIndex + difficulty) % 3],
        );
        var result = -operands.first;
        var expression = '-${operands.first}';
        for (var index = 0; index < operations.length; index++) {
          final next = operands[index + 1];
          final operation = operations[index];
          result = switch (operation) {
            '+' => result + next,
            '−' => result - next,
            _ => result * next,
          };
          expression = '($expression $operation $next)';
        }
        prompt = 'Calculate $expression.';
        answer = '$result';
        distractors = ['${result + 1}', '${result - 1}'];
      default:
        throw RangeError.index(moduleIndex, worksheetModuleIds);
    }

    final choices = [answer, ...distractors]..shuffle(Random(seed));
    return NpcQuestion(
      id: 'npc_${npcNumber}_extra_${questionIndex}_${seed}_$moduleId',
      questionNumber: npcNumber,
      semester: semester,
      module: topic,
      moduleId: moduleId,
      lesson: '$topic practice $questionIndex',
      topic: topic,
      prompt: prompt,
      choices: choices,
      correctAnswerIndex: choices.indexOf(answer),
      isExtra: true,
      difficulty: difficulty,
    );
  }

  static NpcQuestion _questionForWorksheet(
      WorksheetLesson lesson, int questionNumber, int choiceSeed,
      {int difficulty = 1}) {
    final choices = [...lesson.choices]..shuffle(Random(choiceSeed));
    return NpcQuestion(
      id: 'npc_question_${questionNumber}_${lesson.number}_$choiceSeed',
      questionNumber: questionNumber,
      semester: lesson.semester,
      module: lesson.topic,
      moduleId: lesson.moduleId,
      lesson: lesson.title,
      topic: lesson.topic,
      prompt: lesson.question,
      choices: choices,
      correctAnswerIndex: choices.indexOf(lesson.correctAnswer),
      difficulty: difficulty,
    );
  }
}

class NpcQuestionCycle {
  final Map<int, Set<String>> _shownQuestionIdsByNpc = {};

  NpcQuestion nextForNpc(List<NpcQuestion> questions) {
    if (questions.isEmpty) {
      throw ArgumentError.value(questions, 'questions', 'Must not be empty.');
    }

    final npcNumber = questions.first.questionNumber;
    if (questions.any((question) => question.questionNumber != npcNumber)) {
      throw ArgumentError.value(
        questions,
        'questions',
        'A question cycle must belong to one NPC.',
      );
    }
    if (questions.map((question) => question.id).toSet().length !=
        questions.length) {
      throw ArgumentError.value(
        questions,
        'questions',
        'A question cycle cannot contain duplicate IDs.',
      );
    }

    final shown = _shownQuestionIdsByNpc.putIfAbsent(npcNumber, () => {});
    NpcQuestion? next;
    for (final question in questions) {
      if (!shown.contains(question.id)) {
        next = question;
        break;
      }
    }
    if (next == null) {
      shown.clear();
      next = questions.first;
    }
    shown.add(next.id);
    return next;
  }

  Set<String> shownQuestionIdsForNpc(int npcNumber) =>
      Set.unmodifiable(_shownQuestionIdsByNpc[npcNumber] ?? const <String>{});

  void restoreShownQuestionIds(
    int npcNumber,
    Iterable<String> questionIds, {
    required Set<String> validQuestionIds,
  }) {
    if (npcNumber < 1) {
      throw ArgumentError.value(npcNumber, 'npcNumber');
    }
    final shown = _shownQuestionIdsByNpc.putIfAbsent(npcNumber, () => {});
    shown
      ..clear()
      ..addAll(questionIds.where(validQuestionIds.contains));
  }
}
