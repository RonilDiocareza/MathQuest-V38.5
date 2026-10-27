import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/game/npc_question.dart';
import 'package:flutter_mathquest/game/npc_question_dialog.dart';

void main() {
  testWidgets('NPC question dialog fits a small landscape screen',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(568, 320);

    const question = NpcQuestion(
      id: 'small_screen_test',
      topic: 'Variables & Operations',
      prompt: 'In 3x + 5, what is the coefficient of x?',
      choices: ['3', '5', '8'],
      correctAnswerIndex: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => const NpcQuestionDialog(question: question),
                ),
                child: const Text('Open question'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open question'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Question 1'), findsOneWidget);
    final dialog = tester.getRect(find.byType(Dialog));
    expect(dialog.left, greaterThanOrEqualTo(0));
    expect(dialog.top, greaterThanOrEqualTo(0));
    expect(dialog.right, lessThanOrEqualTo(568));
    expect(dialog.bottom, lessThanOrEqualTo(320));

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('NPC question dialog closes from the upper-right X button',
      (tester) async {
    const question = NpcQuestion(
      id: 'close_button_test',
      topic: 'Variables & Operations',
      prompt: 'In 3x + 5, what is the coefficient of x?',
      choices: ['3', '5', '8'],
      correctAnswerIndex: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => const NpcQuestionDialog(question: question),
                ),
                child: const Text('Open question'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open question'));
    await tester.pumpAndSettle();

    expect(find.text('Not now'), findsNothing);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('answer save retry reuses the selected answer before closing',
      (tester) async {
    const question = NpcQuestion(
      id: 'saved_answer_test',
      questionNumber: 2,
      topic: 'Variables & Operations',
      prompt: 'In 3x + 5, what is the coefficient of x?',
      choices: ['3', '5', '8'],
      correctAnswerIndex: 0,
    );
    final savedChoices = <String>[];
    var saveCalls = 0;
    Future<bool?>? answerResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  answerResult = showDialog<bool>(
                    context: context,
                    builder: (_) => NpcQuestionDialog(
                      question: question,
                      onAnswerSelected: (selectedAnswer, isCorrect) async {
                        savedChoices.add('$selectedAnswer:$isCorrect');
                        saveCalls++;
                        if (saveCalls == 1) {
                          throw StateError('Temporary write failure');
                        }
                      },
                    ),
                  );
                },
                child: const Text('Open question'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open question'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Retry Save'), findsOneWidget);
    expect(savedChoices, ['5:false']);

    await tester.tap(find.text('Retry Save'));
    await tester.pumpAndSettle();

    expect(await answerResult, isFalse);
    expect(savedChoices, ['5:false', '5:false']);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
