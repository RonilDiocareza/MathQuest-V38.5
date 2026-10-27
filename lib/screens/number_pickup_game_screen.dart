import 'dart:async';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'package:just_audio/just_audio.dart';
import '../services/auth_service.dart';
import '../services/user_progress_service.dart';
import '../game/math_world_game.dart';
import '../game/npc_question.dart';
import '../game/npc_question_dialog.dart';
import '../game/hud.dart';
import '../widgets/first_time_tutorial_overlay.dart';
import '../widgets/game_joystick.dart';

typedef GameModeAnswerSaver = Future<void> Function({
  required int level,
  required int questionNumber,
  required String question,
  required String selectedAnswer,
  required String correctAnswer,
  required bool isCorrect,
  required int scoreEarned,
  required int scoreAfter,
});

class NumberPickupGameScreen extends StatefulWidget {
  final int level;
  final String problem;
  final int correctAnswer;
  final GameModeAnswerSaver? saveGameModeAnswer;

  const NumberPickupGameScreen({
    super.key,
    required this.level,
    required this.problem,
    required this.correctAnswer,
    this.saveGameModeAnswer,
  });

  @override
  State<NumberPickupGameScreen> createState() => _NumberPickupGameScreenState();
}

class _NumberPickupGameScreenState extends State<NumberPickupGameScreen> {
  late int currentLevel;
  late String currentProblem;
  late int currentCorrectAnswer;
  late MathWorldGame gameInstance;
  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _soundEffectPlayer = AudioPlayer();
  final AudioPlayer _gameOverSoundPlayer = AudioPlayer();
  Future<void> _soundEffectQueue = Future<void>.value();
  bool levelCompleted = false;
  int score = 0;
  int health = 3;
  bool _isResettingLevel = false;
  bool isMusicEnabled = true;
  bool _isExitDialogOpen = false;
  bool _isGameOverDialogOpen = false;
  bool _isLeaving = false;
  bool _isFinalizingLevel = false;
  bool _isHandlingNpcQuestion = false;
  bool _isRetryingNpcProgressSave = false;
  bool _completionPending = false;
  int? _pendingFinalScore;
  bool _correctNumberCollected = false;
  bool _isGameModeIntroInProgress = false;
  bool _hasPromptedGameModeIntro = false;
  bool _showGameModeIntroOverlay = false;
  late Future<void> _progressRestoration;
  late Future<void> _orientationChange;
  late Future<void> _musicInitialization;

  @override
  void initState() {
    super.initState();
    _orientationChange = _requestGameOrientation();
    _musicInitialization = _initializeMusic();
    currentLevel = widget.level;
    currentProblem = widget.problem;
    currentCorrectAnswer = widget.correctAnswer;
    gameInstance = _createGame();
    gameInstance.pauseWorld();
    _progressRestoration = _restoreCompletedGameModeScore();
    unawaited(_progressRestoration);
    unawaited(_checkFirstTimeGameModeIntro());
  }

  Future<void> _restoreCompletedGameModeScore() async {
    try {
      final progress = await UserProgressService.getCurrentUserProgress();
      if (!mounted) return;
      if (progress.completedLevels.contains(currentLevel)) {
        final finalScore = progress.gameModeFinalScores[currentLevel] ??
            await UserProgressService.getGameModeFinalScore(currentLevel) ??
            0;
        if (!mounted) return;
        setState(() {
          score = finalScore;
          levelCompleted = true;
        });
        try {
          await UserProgressService.clearPendingGameModeScore(currentLevel);
        } catch (error, stackTrace) {
          debugPrint('Unable to clear pending Game Mode score: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
        return;
      }
      final pendingFinalScore =
          await UserProgressService.getPendingGameModeScore(currentLevel);
      if (pendingFinalScore != null) {
        if (!mounted) return;
        setState(() => score = pendingFinalScore);
        gameInstance.pauseWorld();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Your completed Game Mode score is still waiting to save.',
            ),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () =>
                  unawaited(_retryPendingFinalScore(pendingFinalScore)),
            ),
          ),
        );
        return;
      }
      setState(() {
        score =
            progress.completedNpcQuestionsForLevel(currentLevel).length * 10;
      });
      gameInstance.resumeWorld();
    } catch (error, stackTrace) {
      debugPrint('Unable to restore completed Game Mode score: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) gameInstance.resumeWorld();
    }
  }

  Future<void> _retryPendingFinalScore(int pendingScore) async {
    if (_isFinalizingLevel || _isLeaving) return;
    _isFinalizingLevel = true;
    final navigator = Navigator.of(context);
    try {
      await UserProgressService.completeGameMode(currentLevel, pendingScore);
    } catch (error, stackTrace) {
      _isFinalizingLevel = false;
      final errorCode = error is FirebaseException ? error.code : null;
      debugPrint(
        'Pending Game Mode score retry failed'
        '${errorCode == null ? '' : ' ($errorCode)'}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorCode == null
                  ? 'Could not save the final score. Please try again.'
                  : 'Could not save the final score ($errorCode). Please try again.',
            ),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_retryPendingFinalScore(pendingScore)),
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => levelCompleted = true);
    _isLeaving = true;
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && navigator.canPop()) {
      navigator.pop(true);
    }
  }

  List<FirstTimeTutorialStep> get _gameModeTutorialSteps {
    final userName =
        AuthService.currentUser?.displayName?.trim().isNotEmpty == true
            ? AuthService.currentUser!.displayName!
            : AuthService.currentUser?.email?.split('@').first ?? 'Player';
    final currentLevelQuestion = NpcQuestion.forLevel(1, currentLevel);
    final sampleQuestion = NpcQuestion.forLevel(
      currentLevel > 1 ? currentLevel.clamp(1, NpcQuestion.all.length) : 1,
      currentLevel,
    );
    final examplePrompt = sampleQuestion.prompt;
    final guidanceSteps = <FirstTimeTutorialStep>[
      FirstTimeTutorialStep(
        title: 'Welcome to Game Mode, $userName!',
        message:
            'I’m your guide for this stage. Today, we will practice ${currentLevelQuestion.topic.toLowerCase()} and learn how to solve the questions you will encounter in Game Mode.',
      ),
      FirstTimeTutorialStep(
        title: 'What This Game Mode Teaches',
        message:
            'This challenge focuses on ${currentLevelQuestion.lesson}. In this game mode, you will answer NPC math questions and then collect the number that matches the correct answer. The goal is to solve the problem, not just move around the map.',
      ),
      FirstTimeTutorialStep(
        title: 'Example: Solve the Question',
        message:
            'Look at this actual question from the game: "$examplePrompt". First identify the operation, then calculate carefully. Use the same method you would use on your worksheet: simplify when needed, check your work, and choose the answer that matches the final result.',
      ),
      FirstTimeTutorialStep(
        title: 'How to Play',
        message:
            'Talk to each NPC, answer the question correctly, and then collect the matching number in the stage. A correct NPC answer or a matching number you collect earns 10 points. An incorrect answer costs one heart. You have three hearts in total.',
      ),
      FirstTimeTutorialStep(
        title: 'Points and Leaderboard',
        message:
            'Your points are added to the leaderboard. The more correct answers and numbers you collect, the higher your rank becomes. The Help button on the right side of the screen can reopen these instructions at any time.',
      ),
    ];
    return guidanceSteps;
  }

  Future<void> _checkFirstTimeGameModeIntro() async {
    if (_hasPromptedGameModeIntro || _isGameModeIntroInProgress) return;

    final user = AuthService.currentUser;
    if (user == null) {
      _hasPromptedGameModeIntro = true;
      return;
    }

    try {
      final shouldShow =
          await UserProgressService.shouldShowGameModeIntroduction(
        uid: user.uid,
      );
      if (!mounted || !shouldShow) {
        if (mounted) {
          setState(() => _hasPromptedGameModeIntro = true);
        }
        return;
      }

      if (!mounted) return;
      await _progressRestoration;
      if (!mounted) return;
      if (levelCompleted) {
        setState(() => _hasPromptedGameModeIntro = true);
        return;
      }
      gameInstance.resumeWorld();
      setState(() {
        _hasPromptedGameModeIntro = true;
        _isGameModeIntroInProgress = true;
        _showGameModeIntroOverlay = true;
      });
    } catch (error, stackTrace) {
      debugPrint('Unable to check Game Mode intro status: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() => _showGameModeIntroOverlay = false);
      }
    }
  }

  Future<void> _completeGameModeIntro() async {
    final user = AuthService.currentUser;
    if (user != null) {
      await UserProgressService.markGameModeIntroductionSeen(uid: user.uid);
    }
    if (!mounted) return;
    setState(() {
      _isGameModeIntroInProgress = false;
      _showGameModeIntroOverlay = false;
    });
    await _showGameModeInstructions();
  }

  Future<void> _showGameModeInstructions() async {
    if (!mounted || _showGameModeIntroOverlay || _isGameModeIntroInProgress) {
      return;
    }

    final currentQuestion = NpcQuestion.forLevel(
      1,
      currentLevel,
    );
    final exampleQuestion = currentQuestion.prompt;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Game Mode Instructions'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Purpose: Game Mode helps you practice ${currentQuestion.topic.toLowerCase()} by solving the same kinds of math questions asked by the NPCs in the stage.',
                style: const TextStyle(height: 1.4),
              ),
              const SizedBox(height: 10),
              const Text(
                'Gameplay: Talk to an NPC, answer the question, and then move through the stage to collect the number that matches your answer. Keep your score and hearts in mind while you play.',
                style: TextStyle(height: 1.4),
              ),
              const SizedBox(height: 10),
              const Text(
                'Points System: Every correct NPC answer and every matching number you collect gives 10 points. Wrong answers cost a heart.',
                style: TextStyle(height: 1.4),
              ),
              const SizedBox(height: 10),
              const Text(
                'Leaderboard: The points you earn help your rank on the leaderboard, so your progress can be compared with other players.',
                style: TextStyle(height: 1.4),
              ),
              const SizedBox(height: 12),
              Text(
                'Example: $exampleQuestion',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _handleJoystickChanged(Offset offset) {
    if (offset.dx.abs() > offset.dy.abs()) {
      gameInstance.stopMove();
      if (offset.dx > 0.3) {
        gameInstance.startMoveRight();
      } else if (offset.dx < -0.3) {
        gameInstance.startMoveLeft();
      }
      return;
    }

    gameInstance.stopMove();
    if (offset.dy > 0.3) {
      gameInstance.startMoveDown();
    } else if (offset.dy < -0.3) {
      gameInstance.startMoveUp();
    }
  }

  MathWorldGame _createGame() => MathWorldGame(
        level: currentLevel,
        correctAnswer: currentCorrectAnswer,
        problem: currentProblem,
        onNumberCollected: _onCorrectNumberCollected,
        onWrongNumberCollected: _onWrongNumberCollected,
        onNpcQuestion: _onNpcQuestion,
        onNpcQuestionLocked: _showLockedQuestion,
      );

  Future<void> _initializeMusic() async {
    try {
      await _musicPlayer.setAsset(
        'assets/BGM/andorios-arcade_music4-361010.mp3',
      );
      await _musicPlayer.setLoopMode(LoopMode.one);
      if (isMusicEnabled) {
        unawaited(_playMusic());
      }
    } catch (error, stackTrace) {
      if (error is MissingPluginException ||
          error.toString().contains('MissingPluginException')) {
        debugPrint(
            'Audio unavailable in this environment; skipping game music.');
        return;
      }
      debugPrint('Unable to initialize game mode music: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _playMusic() async {
    try {
      await _musicPlayer.play();
    } catch (error, stackTrace) {
      if (error is MissingPluginException ||
          error.toString().contains('MissingPluginException')) {
        return;
      }
      debugPrint('Unable to play game mode music: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _playSoundEffect(String fileName) {
    _soundEffectQueue = _soundEffectQueue.then((_) async {
      try {
        await _soundEffectPlayer.setAsset('assets/BGM/$fileName');
        final duration = _soundEffectPlayer.duration;
        final playbackFinished = duration == null
            ? _soundEffectPlayer.processingStateStream
                .firstWhere((state) => state == ProcessingState.completed)
            : Future<void>.delayed(duration);
        unawaited(
          _soundEffectPlayer.play().catchError(
            (Object error, StackTrace stackTrace) {
              if (error is MissingPluginException ||
                  error.toString().contains('MissingPluginException')) {
                return;
              }
              debugPrint(
                'Unable to start game mode sound effect "$fileName": $error',
              );
              debugPrintStack(stackTrace: stackTrace);
            },
          ),
        );
        await playbackFinished;
      } catch (error, stackTrace) {
        if (error is MissingPluginException ||
            error.toString().contains('MissingPluginException')) {
          return;
        }
        debugPrint('Unable to play game mode sound effect "$fileName": $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    });
    return _soundEffectQueue;
  }

  Future<void> _playGameOverSound() async {
    try {
      await _gameOverSoundPlayer.setAsset('assets/BGM/Game Over.mp3');
      final duration = _gameOverSoundPlayer.duration;
      unawaited(
        _gameOverSoundPlayer.play().catchError(
          (Object error, StackTrace stackTrace) {
            if (error is MissingPluginException ||
                error.toString().contains('MissingPluginException')) {
              return;
            }
            debugPrint('Unable to start the game-over sound: $error');
            debugPrintStack(stackTrace: stackTrace);
          },
        ),
      );
      if (duration != null) {
        await Future<void>.delayed(duration);
      }
    } catch (error, stackTrace) {
      if (error is MissingPluginException ||
          error.toString().contains('MissingPluginException')) {
        return;
      }
      debugPrint('Unable to prepare the game-over sound: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _requestGameOrientation() async {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      debugPrint('Game Mode enabled for landscape orientation.');
    } catch (error, stackTrace) {
      debugPrint('Unable to set landscape orientation: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _onNpcQuestion(NpcQuestion question) async {
    if (_isHandlingNpcQuestion || _isRetryingNpcProgressSave) return;
    _isHandlingNpcQuestion = true;
    try {
      await _handleNpcQuestion(question);
    } finally {
      _isHandlingNpcQuestion = false;
    }
  }

  Future<void> _handleNpcQuestion(NpcQuestion question) async {
    if (!mounted || levelCompleted || _completionPending || _isLeaving) return;
    final activeGame = gameInstance;
    var activeQuestion = question;
    bool? isCorrect;
    try {
      while (mounted) {
        final attemptIds = GameModeAnswerAttemptIds(
          createId: UserProgressService.newGameModeAnswerAttemptId,
        );
        isCorrect = await showDialog<bool>(
          context: context,
          builder: (_) => NpcQuestionDialog(
            question: activeQuestion,
            onAnswerSelected: (selectedAnswer, answerIsCorrect) async {
              final scoreEarned = answerIsCorrect ? 10 : 0;
              final saveAnswer = widget.saveGameModeAnswer;
              if (saveAnswer != null) {
                await saveAnswer(
                  level: currentLevel,
                  questionNumber: activeQuestion.questionNumber,
                  question: activeQuestion.prompt,
                  selectedAnswer: selectedAnswer,
                  correctAnswer:
                      activeQuestion.choices[activeQuestion.correctAnswerIndex],
                  isCorrect: answerIsCorrect,
                  scoreEarned: scoreEarned,
                  scoreAfter: score + scoreEarned,
                );
              } else {
                await UserProgressService.recordGameModeAnswer(
                  attemptId:
                      attemptIds.forAnswer(selectedAnswer, answerIsCorrect),
                  level: currentLevel,
                  questionNumber: activeQuestion.questionNumber,
                  question: activeQuestion.prompt,
                  selectedAnswer: selectedAnswer,
                  correctAnswer:
                      activeQuestion.choices[activeQuestion.correctAnswerIndex],
                  isCorrect: answerIsCorrect,
                  scoreEarned: scoreEarned,
                  scoreAfter: score + scoreEarned,
                );
              }
              if (answerIsCorrect) {
                await activeGame.recordCorrectlyAnsweredQuestion(
                  activeQuestion,
                );
              }
            },
          ),
        );
        if (isCorrect != false) break;

        await _handleDamage(
          'Wrong answer. You lost 1 heart. {health} remaining. Try again.',
        );
        if (!mounted ||
            health <= 0 ||
            activeGame != gameInstance ||
            levelCompleted ||
            _completionPending ||
            _isLeaving) {
          return;
        }
      }
    } finally {
      activeGame.closeNpcQuestion();
    }

    if (!mounted || isCorrect == null) return;

    if (isCorrect) {
      final bool saved;
      try {
        saved = await activeGame.completeNpcQuestion(
          question.questionNumber,
        );
      } catch (error, stackTrace) {
        if (error is FirebaseException) {
          debugPrint(
            'NPC progress save failed (${error.plugin}/${error.code}): '
            '${error.message ?? 'No Firebase error message was provided.'}',
          );
        } else {
          debugPrint(
            'NPC progress save failed (${error.runtimeType}): $error',
          );
        }
        debugPrintStack(stackTrace: stackTrace);
        if (!mounted) return;
        final snackBar = await _npcProgressSaveError(
          error,
          activeGame,
          question,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
        return;
      }

      if (!mounted) return;
      if (!saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              activeGame.allNpcQuestionsCompleted
                  ? 'All NPC questions are complete.'
                  : 'Complete Question ${activeGame.currentQuestionNumber} first.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      await _finishSavedNpcQuestion(activeGame, question);
    }
  }

  Future<SnackBar> _npcProgressSaveError(
    Object error,
    MathWorldGame activeGame,
    NpcQuestion question,
  ) async {
    final code = error is FirebaseException ? error.code : null;
    final canRetry = code == null ||
        !{'permission-denied', 'unauthenticated'}.contains(code);
    final message = code == 'permission-denied'
        ? await AuthService.savePermissionDeniedMessage('progress')
        : switch (code) {
            'unauthenticated' =>
              'Your session expired. Sign in again before retrying.',
            'unavailable' ||
            'deadline-exceeded' ||
            'aborted' ||
            'resource-exhausted' =>
              'Your progress is still waiting to save. Check your connection and retry.',
            null => 'Could not save your progress. Please retry.',
            _ => 'Could not save your progress ($code).',
          };
    return SnackBar(
      content: Text(message),
      action: canRetry
          ? SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(
                _retryNpcProgressSave(activeGame, question),
              ),
            )
          : null,
    );
  }

  Future<void> _retryNpcProgressSave(
    MathWorldGame activeGame,
    NpcQuestion question,
  ) async {
    if (_isRetryingNpcProgressSave) return;
    _isRetryingNpcProgressSave = true;
    try {
      final saved = await activeGame.completeNpcQuestion(
        question.questionNumber,
      );
      if (!mounted) return;
      if (!saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              activeGame.allNpcQuestionsCompleted
                  ? 'All NPC questions are complete.'
                  : 'Complete Question ${activeGame.currentQuestionNumber} first.',
            ),
          ),
        );
        return;
      }
      await _finishSavedNpcQuestion(activeGame, question);
    } catch (error, stackTrace) {
      if (error is FirebaseException) {
        debugPrint(
          'NPC progress retry failed (${error.plugin}/${error.code}): '
          '${error.message ?? 'No Firebase error message was provided.'}',
        );
      } else {
        debugPrint('NPC progress retry failed (${error.runtimeType}): $error');
      }
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        final snackBar = await _npcProgressSaveError(
          error,
          activeGame,
          question,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    } finally {
      _isRetryingNpcProgressSave = false;
    }
  }

  Future<void> _finishSavedNpcQuestion(
    MathWorldGame activeGame,
    NpcQuestion question,
  ) async {
    if (!mounted) return;
    final isFinalQuestion = question.questionNumber == NpcQuestion.all.length;
    unawaited(_playSoundEffect('Correct Answer.mp3'));
    setState(() => score += 10);
    if (isFinalQuestion) {
      _completionPending = true;
      final victorySound = _playSoundEffect('Victory.mp3');
      activeGame.pauseWorld();
      final navigator = Navigator.of(context);
      await _showLevelClearedDialog(navigator, victorySound);
      if (!mounted) return;
      await _advanceToNextLevel(navigator);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Question ${question.questionNumber} complete! '
          'Question ${activeGame.currentQuestionNumber} unlocked.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showLevelClearedDialog(
    NavigatorState navigator,
    Future<void> victorySound,
  ) async {
    final dialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Text('Stage Cleared!'),
        content: Text('You completed all six NPC challenges.'),
      ),
    );

    await Future.wait([
      Future<void>.delayed(const Duration(seconds: 2)),
      victorySound,
    ]);
    if (!mounted) return;
    navigator.pop();
    await dialog;
  }

  void _showLockedQuestion(int currentQuestionNumber) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Question locked. Complete Question $currentQuestionNumber first.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onCorrectNumberCollected() async {
    if (!mounted || levelCompleted || _completionPending) return;

    final correctSound = _playSoundEffect('Correct Answer.mp3');
    final victorySound = _playSoundEffect('Victory.mp3');
    _completionPending = true;
    if (!_correctNumberCollected) {
      _correctNumberCollected = true;
      setState(() => score += 10);
    }
    gameInstance.pauseWorld();

    // Show correct answer indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 60,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Correct!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final navigator = Navigator.of(context);

    await Future.wait([
      Future<void>.delayed(const Duration(milliseconds: 1500)),
      correctSound,
      victorySound,
    ]);

    if (!mounted) return;
    navigator.pop(); // Close the correct indicator dialog

    await _advanceToNextLevel(navigator);
  }

  Future<void> _resetCurrentLevelProgressForExit() async {
    try {
      await UserProgressService.resetNpcQuestionsForLevel(currentLevel);
    } catch (error, stackTrace) {
      debugPrint('Unable to reset level progress on exit: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _advanceToNextLevel(NavigatorState navigator) async {
    if (_isFinalizingLevel || _isLeaving) return;
    if (!gameInstance.allNpcQuestionsCompleted) {
      _completionPending = false;
      gameInstance.resumeWorld();
      return;
    }

    _isFinalizingLevel = true;
    final finalScore = _pendingFinalScore ??= score;
    try {
      await UserProgressService.completeGameMode(currentLevel, finalScore);
    } catch (error, stackTrace) {
      _isFinalizingLevel = false;
      final errorCode = error is FirebaseFunctionsException
          ? error.code
          : error is FirebaseException
              ? error.code
              : null;
      debugPrint(
        'Unable to persist completed Game Mode score'
        '${errorCode == null ? '' : ' ($errorCode)'}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() => levelCompleted = false);
        gameInstance.pauseWorld();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorCode == null
                  ? 'Could not save the final score. Please try again.'
                  : 'Could not save the final score ($errorCode). Please try again.',
            ),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_advanceToNextLevel(navigator)),
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;

    setState(() {
      levelCompleted = true;
      _completionPending = false;
    });
    _isLeaving = true;
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && navigator.canPop()) {
      navigator.pop(true);
    }
  }

  void _onWrongNumberCollected() {
    unawaited(
      _handleDamage('Wrong! Lives left: {health} ❌', snackDuration: 1),
    );
  }

  Future<void> _handleDamage(
    String message, {
    int snackDuration = 2,
  }) async {
    if (!mounted || levelCompleted || health <= 0 || _isGameOverDialogOpen) {
      return;
    }

    setState(() => health--);
    final damageSound = _playSoundEffect('Health Damage.mp3');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.replaceAll('{health}', '$health')),
        duration: Duration(seconds: snackDuration),
        backgroundColor: Colors.red,
      ),
    );

    if (health > 0) {
      await damageSound;
      return;
    }
    await _handleGameOver(damageSound);
  }

  Future<void> _handleGameOver(Future<void> damageSound) async {
    if (!mounted || _isGameOverDialogOpen) return;
    _isGameOverDialogOpen = true;
    gameInstance.pauseWorld();
    try {
      await _musicInitialization;
      await _musicPlayer.pause();
    } catch (error, stackTrace) {
      debugPrint('Unable to pause game music after game over: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    unawaited(damageSound);
    unawaited(_playGameOverSound());
    if (!mounted) return;

    final shouldRestart = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Game Over'),
        content: const Text('Do you want to restart this stage or quit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Quit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
    _isGameOverDialogOpen = false;
    if (!mounted) return;

    if (shouldRestart == true) {
      await _resetCurrentLevel();
      if (isMusicEnabled) {
        unawaited(_playMusic());
      }
    } else {
      _isLeaving = true;
      await _resetCurrentLevelProgressForExit();
      setState(() {});
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _resetCurrentLevel() async {
    if (!mounted || _isResettingLevel || levelCompleted) return;

    _isResettingLevel = true;
    gameInstance.pauseWorld();
    try {
      await UserProgressService.resetNpcQuestionsForLevel(currentLevel);
    } catch (error, stackTrace) {
      debugPrint('Unable to clear NPC progress for level restart: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not sync stage progress. Restarting this attempt locally.',
            ),
          ),
        );
      }
    }
    if (!mounted) return;

    setState(() {
      health = 3;
      score = 0;
      levelCompleted = false;
      gameInstance = _createGame();
      _isResettingLevel = false;
    });
    _completionPending = false;
    _correctNumberCollected = false;
    _pendingFinalScore = null;
  }

  void _onMusicPressed() {
    setState(() {
      isMusicEnabled = !isMusicEnabled;
    });
    unawaited(_syncMusicPlayback());
  }

  Future<void> _syncMusicPlayback() async {
    try {
      await _musicInitialization;
      if (isMusicEnabled) {
        unawaited(_playMusic());
      } else {
        try {
          await _musicPlayer.pause();
        } catch (error, stackTrace) {
          if (error is MissingPluginException ||
              error.toString().contains('MissingPluginException')) {
            return;
          }
          debugPrint('Unable to pause game mode music: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
    } catch (error, stackTrace) {
      if (error is MissingPluginException ||
          error.toString().contains('MissingPluginException')) {
        return;
      }
      debugPrint('Unable to update game mode music playback: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _onMenuPressed() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Game Menu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Stage: $currentLevel'),
              Text('Score: $score'),
              Text('Health: $health'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Resume'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showExitDialog();
              },
              child: const Text('Quit'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double minSide = min(screenSize.width, screenSize.height);
    final double directionButtonSize = (minSide * 0.11).clamp(44.0, 56.0);
    final double directionContainerSize =
        (directionButtonSize * 2.1).clamp(110.0, 140.0);
    return PopScope(
      canPop: _isLeaving,
      onPopInvokedWithResult: (_, __) {
        _showExitDialog();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFD09F5C),
        body: FutureBuilder<void>(
          future: _orientationChange,
          builder: (context, orientationSnapshot) {
            if (orientationSnapshot.connectionState != ConnectionState.done) {
              return _buildLoadingState();
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: FloatingGameJoystick(
                    size: directionContainerSize,
                    enabled: !_showGameModeIntroOverlay &&
                        !gameInstance.isMovementPaused,
                    onJoystickChanged: _handleJoystickChanged,
                    onJoystickEnd: gameInstance.stopMove,
                    child: Focus(
                      autofocus: true,
                      child: GameWidget(
                        game: gameInstance,
                        loadingBuilder: (_) => _buildLoadingState(),
                        errorBuilder: (context, error) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.white,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Unable to load Game Mode.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  error.toString(),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _showExitDialog,
                                  child: const Text(
                                      'Return to the previous screen'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Stack(
                    children: [
                      GameHUD(
                        score: score,
                        health: health,
                        onMusicPressed: _onMusicPressed,
                        onMenuPressed: _onMenuPressed,
                        onHelpPressed: _showGameModeInstructions,
                        isMusicEnabled: isMusicEnabled,
                      ),
                      if (_showGameModeIntroOverlay)
                        Positioned.fill(
                          child: FirstTimeTutorialOverlay(
                            steps: _gameModeTutorialSteps,
                            onComplete: _completeGameModeIntro,
                            gameModeLayout: true,
                            typewriterText: true,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const ColoredBox(
      color: Color(0xFF17202A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Loading Game...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitDialog() {
    if (!mounted || _isExitDialogOpen || _isLeaving) return;
    _isExitDialogOpen = true;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Stage?'),
        content: const Text('Are you sure you want to go back?'),
        actions: [
          TextButton(
            onPressed: () {
              _isExitDialogOpen = false;
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _confirmExit(context),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmExit(BuildContext dialogContext) async {
    if (_isLeaving) return;
    _isLeaving = true;
    _isExitDialogOpen = false;
    final navigator = Navigator.of(context);
    Navigator.pop(dialogContext);
    await _resetCurrentLevelProgressForExit();
    setState(() {});
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && navigator.canPop()) {
      navigator.pop(true);
    }
  }

  Future<void> _restoreAppOrientation() async {
    try {
      await _orientationChange;
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      debugPrint('Restored portrait orientation after Game Mode.');
    } catch (error, stackTrace) {
      debugPrint('Unable to restore portrait orientation: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    unawaited(_restoreAppOrientation());
    unawaited(() async {
      try {
        await _musicPlayer.dispose();
      } catch (error) {
        if (error is! MissingPluginException &&
            !error.toString().contains('MissingPluginException')) {
          rethrow;
        }
      }
    }());
    unawaited(() async {
      try {
        await _soundEffectPlayer.dispose();
      } catch (error) {
        if (error is! MissingPluginException &&
            !error.toString().contains('MissingPluginException')) {
          rethrow;
        }
      }
    }());
    unawaited(() async {
      try {
        await _gameOverSoundPlayer.dispose();
      } catch (error) {
        if (error is! MissingPluginException &&
            !error.toString().contains('MissingPluginException')) {
          rethrow;
        }
      }
    }());
    gameInstance.removeFromParent();
    super.dispose();
  }
}
