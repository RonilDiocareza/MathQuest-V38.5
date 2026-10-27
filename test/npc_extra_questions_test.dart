import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/game/math_world_game.dart';
import 'package:flutter_mathquest/game/npc_question.dart';
import 'package:flutter_mathquest/worksheet_lesson_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('each NPC gets ten unique extra questions from its level module', () {
    for (var level = 1; level <= 60; level++) {
      final moduleIndex = gameModeModuleIndexForLevel(level);
      for (var npcNumber = 1;
          npcNumber <= NpcQuestion.all.length;
          npcNumber++) {
        final extras = NpcQuestion.extraQuestionsForLevel(npcNumber, level);

        expect(extras, hasLength(10), reason: 'Level $level, NPC $npcNumber');
        expect(
          extras.map((question) => question.id).toSet(),
          hasLength(10),
          reason: 'Level $level, NPC $npcNumber',
        );
        expect(
          extras.map((question) => question.prompt).toSet(),
          hasLength(10),
          reason: 'Level $level, NPC $npcNumber',
        );
        for (final question in extras) {
          expect(question.isExtra, isTrue);
          expect(question.questionNumber, npcNumber);
          expect(question.moduleId, worksheetModuleIds[moduleIndex]);
          expect(question.topic, worksheetModuleNames[moduleIndex]);
          expect(question.choices, hasLength(3));
          expect(question.choices.toSet(), hasLength(3));
          expect(
            question.choices[question.correctAnswerIndex],
            isNotEmpty,
          );
        }
      }
    }
  });

  test('question cycles show originals then extras once before resetting', () {
    final original = NpcQuestion.forLevel(1, 1, questionSeed: 1);
    final extras = NpcQuestion.extraQuestionsForLevel(1, 1);
    final pool = [original, ...extras];
    final cycle = NpcQuestionCycle();

    expect(cycle.nextForNpc(pool).isExtra, isFalse);
    for (var index = 0; index < extras.length; index++) {
      expect(cycle.nextForNpc(pool).id, extras[index].id);
      expect(cycle.shownQuestionIdsForNpc(1), hasLength(index + 2));
    }
    expect(cycle.nextForNpc(pool).id, original.id);
    expect(cycle.shownQuestionIdsForNpc(1), {original.id});
  });

  test('each NPC keeps an independent question history', () {
    final firstNpcPool = [
      NpcQuestion.forLevel(1, 1),
      ...NpcQuestion.extraQuestionsForLevel(1, 1),
    ];
    final secondNpcPool = [
      NpcQuestion.forLevel(2, 1),
      ...NpcQuestion.extraQuestionsForLevel(2, 1),
    ];
    final cycle = NpcQuestionCycle();

    expect(cycle.nextForNpc(firstNpcPool).questionNumber, 1);
    expect(cycle.shownQuestionIdsForNpc(2), isEmpty);
    expect(cycle.nextForNpc(secondNpcPool).questionNumber, 2);
    expect(cycle.shownQuestionIdsForNpc(1), hasLength(1));
    expect(cycle.shownQuestionIdsForNpc(2), hasLength(1));
  });

  test('restored history resumes at the next unused question', () {
    final original = NpcQuestion.forLevel(1, 1);
    final extras = NpcQuestion.extraQuestionsForLevel(1, 1);
    final pool = [original, ...extras];
    final cycle = NpcQuestionCycle();
    cycle
      ..nextForNpc(pool)
      ..nextForNpc(pool);

    final restoredCycle = NpcQuestionCycle()
      ..restoreShownQuestionIds(
        1,
        [...cycle.shownQuestionIdsForNpc(1), 'stale-question'],
        validQuestionIds: pool.map((question) => question.id).toSet(),
      );

    expect(restoredCycle.nextForNpc(pool).id, extras[1].id);
    expect(restoredCycle.shownQuestionIdsForNpc(1), hasLength(3));
  });

  test('correct-answer history persists and excludes normalized prompts',
      () async {
    const previouslyCorrect = NpcQuestion(
      id: 'answered',
      questionNumber: 1,
      topic: 'Adding and Subtracting Fractions',
      prompt: 'Calculate 2 + 3.',
      choices: ['5', '4', '6'],
      correctAnswerIndex: 0,
    );
    final firstGame = MathWorldGame(correctAnswer: 0, problem: 'test');
    await firstGame.recordCorrectlyAnsweredQuestion(previouslyCorrect);

    final resumedGame = MathWorldGame(
      correctAnswer: 0,
      problem: 'test',
      level: 21,
    );
    await resumedGame.loadCorrectQuestionHistory();
    final candidate = resumedGame.questionForNpc(
      const NpcQuestion(
        id: 'same-math-different-format',
        questionNumber: 1,
        topic: 'Solid and Plane Figures',
        prompt: 'calculate 2+3!',
        choices: ['5', '4', '6'],
        correctAnswerIndex: 0,
      ),
    );

    expect(
      NpcQuestion.normalizedPrompt(candidate.prompt),
      isNot(NpcQuestion.normalizedPrompt(previouslyCorrect.prompt)),
    );
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getStringList(
        'mathquest.game-mode-correct-question-history.v1.guest',
      ),
      contains(NpcQuestion.normalizedPrompt(previouslyCorrect.prompt)),
    );
  });

  test('normalized prompts unify equivalent mathematical typography', () {
    expect(
      NpcQuestion.normalizedPrompt('Calculate 2 × 3.'),
      NpcQuestion.normalizedPrompt('calculate 2⋅3!'),
    );
    expect(
      NpcQuestion.normalizedPrompt('Calculate 1/2 + 1/4.'),
      NpcQuestion.normalizedPrompt('calculate ½ + ¼!'),
    );
    expect(
      NpcQuestion.normalizedPrompt('Calculate 1⁄2 − 1⁄4.'),
      NpcQuestion.normalizedPrompt('calculate 1/2 - 1/4!'),
    );
  });

  test('difficulty rises through every 20-level stage', () {
    for (final stageStart in [1, 21, 41]) {
      for (var stageLevel = 1; stageLevel <= 20; stageLevel++) {
        final level = stageStart + stageLevel - 1;
        final question = NpcQuestion.forLevel(1, level);

        expect(question.difficulty, stageLevel, reason: 'Level $level');
        expect(
          question.moduleId,
          worksheetModuleIds[gameModeModuleIndexForLevel(level)],
        );
      }
    }
  });

  test('higher levels add multi-step work within the assigned topic', () {
    expect(
      NpcQuestion.forLevel(1, 23).prompt,
      contains('altogether'),
    );
    expect(
      NpcQuestion.forLevel(1, 24).prompt,
      contains('V − E + F = 2'),
    );
    expect(
      NpcQuestion.forLevel(1, 25).prompt,
      contains('joined at one vertex'),
    );
    expect(
      NpcQuestion.extraQuestionsForLevel(1, 30)
          .any((question) => question.prompt.contains('then')),
      isTrue,
    );
    expect(
      NpcQuestion.extraQuestionsForLevel(1, 35)
          .every((question) => question.prompt.contains('corner removed')),
      isTrue,
    );
    expect(
      NpcQuestion.extraQuestionsForLevel(1, 40).every(
        (question) => question.prompt.contains('third item'),
      ),
      isTrue,
    );
  });

  test('an NPC keeps its active question until explicitly advanced', () {
    final game = MathWorldGame(
      correctAnswer: 0,
      problem: 'test',
      level: 1,
    );
    final original = NpcQuestion.forLevel(1, 1);
    final currentQuestion = game.questionForNpc(original);

    expect(game.questionForNpc(original).id, currentQuestion.id);

    final nextQuestion = game.nextNpcQuestionAfterIncorrect(1);
    expect(nextQuestion.id, isNot(currentQuestion.id));
    expect(game.questionForNpc(original).id, nextQuestion.id);
  });

  test('an incorrectly answered question remains eligible after a full cycle',
      () {
    final game = MathWorldGame(correctAnswer: 0, problem: 'test');
    final original = NpcQuestion.forLevel(1, 1, questionSeed: 0);
    final firstQuestion = game.questionForNpc(original);

    for (var attempt = 0; attempt < 10; attempt++) {
      game.nextNpcQuestionAfterIncorrect(1);
    }

    expect(
      game.nextNpcQuestionAfterIncorrect(1).prompt,
      firstQuestion.prompt,
    );
  });
}
