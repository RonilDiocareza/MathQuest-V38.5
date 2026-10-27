import 'dart:async';
import 'dart:ui' as ui;

import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_progress_service.dart';
import '../services/leaderboard_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/math_background.dart';
import '../worksheet_lesson_data.dart';
import 'number_pickup_game_screen.dart';

class MathProblemScreen extends StatefulWidget {
  final int level;

  const MathProblemScreen({super.key, required this.level});

  @override
  State<MathProblemScreen> createState() => _MathProblemScreenState();
}

class _MathProblemScreenState extends State<MathProblemScreen> {
  late int currentLevel;
  late String problem;
  late int firstOperand;
  late int secondOperand;
  late String operation;
  late int correctAnswer;

  final TextEditingController answerController = TextEditingController();

  String feedback = '';
  bool isCorrect = false;
  bool isWaitingNextQuestion = false;
  bool _isSubmitting = true;
  bool _isGameModeUnlocked = false;
  bool _isGameModeLaunching = false;
  bool _isSavingLeaderboardPoints = false;
  final Random _random = Random();
  late final ProblemLevelAnswerAttemptIds _answerAttemptIds;

  @override
  void initState() {
    super.initState();
    currentLevel = widget.level;
    _answerAttemptIds = ProblemLevelAnswerAttemptIds(
      createId: UserProgressService.newProblemLevelAnswerAttemptId,
    );
    generateProblem();
    _loadQuestionState();
  }

  Future<void> _loadQuestionState() async {
    try {
      final progress = await UserProgressService.getCurrentUserProgress();
      if (!mounted) return;
      final savedAnswer = progress.levelQuestionAnswers[currentLevel];
      setState(() {
        _isGameModeUnlocked = savedAnswer != null;
        if (savedAnswer != null) {
          firstOperand = savedAnswer.firstOperand;
          secondOperand = savedAnswer.secondOperand;
          operation = savedAnswer.operation;
          correctAnswer = savedAnswer.correctAnswer;
          problem = '$firstOperand $operation $secondOperand = ?';
          isCorrect = true;
          isWaitingNextQuestion = true;
          feedback = 'Correct!';
        }
        _isSubmitting = false;
      });
      if (savedAnswer != null) {
        try {
          final hasPendingAward =
              await LeaderboardService.hasPendingLevelQuestionPoints(
            currentLevel,
          );
          if (hasPendingAward && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Your saved answer still has a leaderboard score to save.',
                ),
                action: SnackBarAction(
                  label: 'Retry',
                  onPressed: () =>
                      unawaited(_saveLeaderboardPoints(currentLevel)),
                ),
              ),
            );
          }
        } catch (error, stackTrace) {
          debugPrint('Unable to check pending leaderboard score: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to load Level Question completion: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load this question. Please try again.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    answerController.dispose();
    super.dispose();
  }

  void generateProblem() {
    int maxNum = currentLevel * 5;
    final firstNumber = 1 + (currentLevel - 1) * 2;

    int num1 = firstNumber + _random.nextInt(maxNum);

    int num2 = firstNumber + _random.nextInt(maxNum);

    bool isAddition = currentLevel <= 5 || _random.nextBool();

    if (isAddition) {
      firstOperand = num1;
      secondOperand = num2;
      operation = '+';
      problem = '$num1 + $num2 = ?';
      correctAnswer = num1 + num2;
    } else {
      if (num1 < num2) {
        final temp = num1;
        num1 = num2;
        num2 = temp;
      }
      firstOperand = num1;
      secondOperand = num2;
      operation = '-';
      problem = '$num1 - $num2 = ?';
      correctAnswer = num1 - num2;
    }
  }

  Future<void> checkAnswer() async {
    if (_isSubmitting) {
      debugPrint(
        'MathProblemScreen.checkAnswer: ignored duplicate submission '
        'while a submission is in progress.',
      );
      return;
    }

    debugPrint(
      'MathProblemScreen.checkAnswer: starting answer validation '
      'for level $currentLevel.',
    );
    setState(() {
      _isSubmitting = true;
    });

    final userAnswer = int.tryParse(answerController.text);

    if (userAnswer == null) {
      debugPrint(
        'MathProblemScreen.checkAnswer: answer evaluation failed; '
        'input is not a valid integer.',
      );
      setState(() {
        feedback = 'Enter number!';
        isCorrect = false;
        _isSubmitting = false;
      });
      return;
    }

    try {
      await UserProgressService.recordProblemLevelAnswer(
        attemptId: _answerAttemptIds.forAnswer(
          level: currentLevel,
          question: problem,
          selectedAnswer: userAnswer,
          correctAnswer: correctAnswer,
        ),
        level: currentLevel,
        question: problem,
        selectedAnswer: userAnswer,
        correctAnswer: correctAnswer,
      );
    } catch (error, stackTrace) {
      final firebaseDetails = error is FirebaseException
          ? ', firebaseCode=${error.code}, firebaseMessage=${error.message}'
          : '';
      debugPrint(
        'MathProblemScreen.checkAnswer: Problem Level answer attempt save '
        'failed; exceptionType=${error.runtimeType}$firebaseDetails, '
        'message=$error.',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final errorMessage = await _answerSaveErrorMessage(error);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
        ),
      );
      return;
    }

    if (userAnswer == correctAnswer) {
      debugPrint(
        'MathProblemScreen.checkAnswer: answer evaluated as correct; '
        'starting Level Question progress save.',
      );
      final answer = LevelQuestionAnswer(
        firstOperand: firstOperand,
        secondOperand: secondOperand,
        operation: operation,
        correctAnswer: correctAnswer,
      );
      final LevelQuestionCompletion completion;
      try {
        debugPrint(
          'MathProblemScreen.checkAnswer: awaiting '
          'UserProgressService.completeLevelQuestion for level '
          '$currentLevel.',
        );
        completion = await UserProgressService.completeLevelQuestion(
          currentLevel,
          answer,
        );
        debugPrint(
          'MathProblemScreen.checkAnswer: progress save returned '
          'successfully; alreadyCompleted=${completion.wasAlreadyCompleted}.',
        );
      } catch (error, stackTrace) {
        final firebaseDetails = error is FirebaseException
            ? ', firebaseCode=${error.code}, firebaseMessage=${error.message}'
            : '';
        debugPrint(
          'MathProblemScreen.checkAnswer: Level Question progress save '
          'failed; exceptionType=${error.runtimeType}$firebaseDetails, '
          'message=$error.',
        );
        debugPrintStack(stackTrace: stackTrace);
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        final errorMessage = await _answerSaveErrorMessage(error);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
          ),
        );
        return;
      }

      if (mounted) {
        setState(() {
          firstOperand = completion.answer.firstOperand;
          secondOperand = completion.answer.secondOperand;
          operation = completion.answer.operation;
          correctAnswer = completion.answer.correctAnswer;
          problem = '$firstOperand $operation $secondOperand = ?';
          feedback = 'Correct!';
          isCorrect = true;
          isWaitingNextQuestion = true;
          _isGameModeUnlocked = true;
          _isSubmitting = false;
        });
      }
      if (!completion.wasAlreadyCompleted) {
        await _saveLeaderboardPoints(currentLevel);
      }
    } else {
      debugPrint(
        'MathProblemScreen.checkAnswer: answer evaluated as incorrect; '
        'answer attempt saved; preserving retry behavior without completion.',
      );
      setState(() {
        feedback = 'Wrong!';
        isCorrect = false;
        _isSubmitting = false;
      });
    }
  }

  Future<String> _answerSaveErrorMessage(Object error) async {
    if (error is! FirebaseException) {
      return 'Could not save your answer. Please try again.';
    }

    if (error.code == 'permission-denied') {
      return AuthService.savePermissionDeniedMessage('answer');
    }

    return switch (error.code) {
      'unauthenticated' =>
        'Your session has expired. Please sign in again to save your answer.',
      'unavailable' =>
        'Answer saving is temporarily unavailable. Please try again.',
      _ => 'Could not save your answer (${error.code}). Please try again.',
    };
  }

  Future<void> _saveLeaderboardPoints(int level) async {
    if (_isSavingLeaderboardPoints) return;
    _isSavingLeaderboardPoints = true;
    try {
      await LeaderboardService.awardLevelQuestionPoints(level);
    } catch (error, stackTrace) {
      final firebaseDetails =
          error is FirebaseException ? ' (${error.plugin}/${error.code})' : '';
      debugPrint(
        'Unable to save leaderboard points$firebaseDetails: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      final errorMessage = await _leaderboardSaveErrorMessage(error);
      if (!mounted) return;
      final canRetry = error is! FirebaseException ||
          !{'permission-denied', 'unauthenticated'}.contains(error.code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          action: canRetry
              ? SnackBarAction(
                  label: 'Retry',
                  onPressed: () => unawaited(_saveLeaderboardPoints(level)),
                )
              : null,
        ),
      );
    } finally {
      _isSavingLeaderboardPoints = false;
    }
  }

  Future<String> _leaderboardSaveErrorMessage(Object error) async {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return AuthService.savePermissionDeniedMessage('leaderboard score');
      }
      return switch (error.code) {
        'unauthenticated' =>
          'Your session expired. Sign in again before retrying your score.',
        'unavailable' ||
        'deadline-exceeded' ||
        'aborted' ||
        'resource-exhausted' =>
          'Your score is still waiting to save. Check your connection and retry.',
        _ => 'Could not save your leaderboard score (${error.code}).',
      };
    }
    return 'Could not save your leaderboard score. Please retry.';
  }

  Future<void> _launchGameMode() async {
    if (_isGameModeLaunching) return;
    _isGameModeLaunching = true;
    try {
      final progress = await UserProgressService.getCurrentUserProgress(
        forceRefresh: true,
      );
      final requiredLevel =
          progress.nextRequiredGameModeLevelForTopic(currentLevel);
      if (requiredLevel != null) {
        final moduleIndex = gameModeModuleIndexForLevel(currentLevel);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Complete Game Mode Stage $requiredLevel to unlock '
                '${worksheetModuleNames[moduleIndex]}.',
              ),
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      final didQuit = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => NumberPickupGameScreen(
            level: currentLevel,
            problem: problem,
            correctAnswer: correctAnswer,
          ),
        ),
      );
      if (mounted && didQuit == true) {
        Navigator.pop(context);
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to verify Game Mode topic access: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Could not verify Game Mode access. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) _isGameModeLaunching = false;
    }
  }

  //  BACK BUTTON FUNCTION
  void goBack() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Stage?'),
        content: const Text('Are you sure you want to go back?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // go back screen
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: MathBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 30),
                  Text(
                    'Stage $currentLevel',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildMathOperandRow('', firstOperand),
                            _buildMathOperandRow(operation, secondOperand),
                            Container(
                              width: 132,
                              height: 2,
                              color: const Color(0xFFFF9800),
                            ),
                            SizedBox(
                              width: 132,
                              child: Text(
                                isWaitingNextQuestion ? '$correctAnswer' : '?',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          hint: 'Answer',
                          controller: answerController,
                          enabled: !_isSubmitting && !isWaitingNextQuestion,
                          textColor: Colors.black,
                          hintColor: Colors.black,
                        ),
                        const SizedBox(height: 15),
                        CustomButton(
                          text: 'Submit',
                          textColor:
                              const ui.Color.fromARGB(255, 255, 255, 255),
                          onPressed: (_isSubmitting || isWaitingNextQuestion)
                              ? null
                              : checkAnswer,
                        ),
                        if (feedback.isNotEmpty) ...[
                          const SizedBox(height: 15),
                          Text(
                            feedback,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: feedback == 'Wrong!'
                                  ? Colors.black
                                  : isCorrect
                                      ? Colors.green
                                      : Colors.red,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 35),
                  const Text(
                    'and Play the Game!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '🎮 Move around the map and collect the correct number to answer the problem!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 15),
                  CustomButton(
                    text: 'Play Game Mode',
                    textColor: Colors.white,
                    onPressed: _isGameModeUnlocked && !_isGameModeLaunching
                        ? _launchGameMode
                        : null,
                  ),
                  if (!_isGameModeUnlocked) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Complete this Problem Stage to unlock Game Mode.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  CustomButton(
                    text: 'Back',
                    textColor: const ui.Color.fromARGB(255, 255, 255, 255),
                    onPressed: goBack,
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );

            return Stack(
              children: [
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: constraints.maxWidth.clamp(0, 440),
                      child: Center(child: content),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMathOperandRow(String operator, int operand) {
    return SizedBox(
      width: 132,
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              operator,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '$operand',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
