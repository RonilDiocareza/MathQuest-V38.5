import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../classroom_quest_questions.dart';
import '../services/user_progress_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/math_background.dart';

class ClassroomQuestScreen extends StatefulWidget {
  const ClassroomQuestScreen({
    super.key,
    this.saveAttempt,
    this.attemptIdGenerator,
    this.loadDailyState,
    this.selectQuestions,
  });

  final Future<void> Function(ClassroomQuestAttempt attempt)? saveAttempt;
  final String Function()? attemptIdGenerator;
  final Future<ClassroomQuestDailyState> Function()? loadDailyState;
  final List<ClassroomQuestQuestion> Function(ClassroomQuestDailyState state)?
      selectQuestions;

  @override
  State<ClassroomQuestScreen> createState() => _ClassroomQuestScreenState();
}

class _ClassroomQuestScreenState extends State<ClassroomQuestScreen> {
  late TextEditingController _answerController;
  final GlobalKey _answerFieldKey = GlobalKey();
  double _answerFieldOffset = 0;
  Timer? _timer;
  Timer? _dailyRolloverTimer;
  String? _loadedDayKey;
  late DateTime _completionStartedAt;
  int _timerGeneration = 0;
  int _remainingSeconds = 60;
  int _attempts = 0;
  int _correctAnswers = 0;
  final List<String> _correctAttemptIds = [];
  List<ClassroomQuestQuestion> _questions = const [];
  ClassroomQuestAttempt? _pendingAttempt;
  bool? _pendingAttemptIsCorrect;
  int? _pendingCompletionSeconds;
  bool _isCheckingAnswer = false;
  bool _attemptSaveFailed = false;
  bool _isSavingCompletion = false;
  bool _completionSaveFailed = false;
  bool _isSubmitted = false;
  bool _isTimeUp = false;
  bool _isTimeoutDialogShowing = false;
  bool _isLoadingDailyState = true;
  bool _dailyQuestCompleted = false;
  bool _dailyStateLoadFailed = false;
  String? _feedbackMessage;
  int _currentLevel = 0;

  static const int _totalTime = 60;

  ClassroomQuestQuestion get _currentProblem => _questions[_currentLevel];
  bool get _isLastLevel => _currentLevel == _questions.length - 1;

  @override
  void initState() {
    super.initState();
    _answerController = TextEditingController();
    _completionStartedAt = DateTime.now();
    unawaited(_loadDailyQuest());
  }

  @override
  void dispose() {
    _timerGeneration++;
    _timer?.cancel();
    _dailyRolloverTimer?.cancel();
    _answerController.dispose();
    super.dispose();
  }

  void _startQuestionTimer({bool restartAttempt = false}) {
    _timerGeneration++;
    _timer?.cancel();
    _timer = null;
    final timerGeneration = _timerGeneration;
    setState(() {
      if (restartAttempt) {
        _currentLevel = 0;
        _correctAnswers = 0;
        _correctAttemptIds.clear();
        _completionStartedAt = DateTime.now();
      }
      _remainingSeconds = _totalTime;
      _attempts = 0;
      _isCheckingAnswer = false;
      _isSubmitted = false;
      _isTimeUp = false;
      _feedbackMessage = null;
      _answerController.clear();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || timerGeneration != _timerGeneration) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds <= 1) {
        if (_isCheckingAnswer || _attemptSaveFailed) {
          setState(() => _remainingSeconds = 1);
          return;
        }
        timer.cancel();
        _timer = null;
        _timerGeneration++;
        if (_isTimeUp || _isSubmitted || _isTimeoutDialogShowing) return;
        final questionNumber = _currentLevel + 1;
        final attemptNumber = _attempts + 1;
        setState(() {
          _currentLevel = 0;
          _remainingSeconds = 0;
          _attempts = 0;
          _correctAnswers = 0;
          _isCheckingAnswer = false;
          _isTimeUp = true;
          _feedbackMessage = null;
          _answerController.clear();
        });
        unawaited(_handleTimedOutAttempt(questionNumber, attemptNumber));
        return;
      }

      setState(() => _remainingSeconds -= 1);
    });
  }

  Future<void> _loadDailyQuest({
    bool preserveCompletedStateOnFailure = false,
  }) async {
    var stage = 'load daily state';
    try {
      final loadDailyState = widget.loadDailyState;
      final dailyState = loadDailyState == null
          ? await UserProgressService.getCurrentClassroomQuestDailyState()
          : await loadDailyState();
      if (!mounted) return;
      stage = 'select randomized questions from unlocked modules';
      final selectQuestions = widget.selectQuestions;
      final savedCompletedQuestions = dailyState.completed
          ? classroomQuestQuestionsForIds(
              dailyState.progress,
              dailyState.completedQuestionIds,
            )
          : null;
      final questions = savedCompletedQuestions ??
          (selectQuestions == null
              ? selectClassroomQuestQuestions(
                  dailyState.progress,
                  previousQuestionIds: dailyState.previousQuestionIds,
                )
              : selectQuestions(dailyState));
      if (questions.length != 3) {
        throw StateError(
          'Classroom Quest selection returned ${questions.length} questions; '
          'exactly three are required.',
        );
      }
      final wasDailyQuestCompleted = _dailyQuestCompleted;
      debugPrint(
        'Classroom Quest loading succeeded: dayKey=${dailyState.dayKey}, '
        'completed=${dailyState.completed}, questionIds='
        '${questions.map((question) => question.id).toList()}.',
      );
      setState(() {
        _questions = questions;
        _dailyQuestCompleted = dailyState.completed;
        _loadedDayKey = dailyState.dayKey;
        _isLoadingDailyState = false;
        _dailyStateLoadFailed = false;
      });
      if (_dailyQuestCompleted) {
        _scheduleNextManilaDayRefresh();
      } else {
        _dailyRolloverTimer?.cancel();
        _dailyRolloverTimer = null;
        _startQuestionTimer(restartAttempt: wasDailyQuestCompleted);
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Unable to load daily Classroom Quest during "$stage": '
        'exceptionType=${error.runtimeType}, message=$error'
        '${error is FirebaseException ? ', plugin=${error.plugin}, '
            'code=${error.code}, firebaseMessage=${error.message}' : ''}.',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      if (preserveCompletedStateOnFailure && _dailyQuestCompleted) {
        _scheduleNextManilaDayRefresh(
          delay: const Duration(minutes: 1),
        );
        return;
      }
      setState(() {
        _isLoadingDailyState = false;
        _dailyStateLoadFailed = true;
      });
    }
  }

  void _scheduleNextManilaDayRefresh({Duration? delay}) {
    _dailyRolloverTimer?.cancel();
    final refreshDelay = delay ??
        () {
          final nowUtc = DateTime.now().toUtc();
          final manilaNow = nowUtc.add(const Duration(hours: 8));
          final nextManilaMidnightUtc = DateTime.utc(
            manilaNow.year,
            manilaNow.month,
            manilaNow.day + 1,
          ).subtract(const Duration(hours: 8));
          return nextManilaMidnightUtc.difference(nowUtc);
        }();
    _dailyRolloverTimer = Timer(refreshDelay, () {
      if (!mounted) return;
      if (UserProgressService.classroomQuestDayKey() == _loadedDayKey) {
        _scheduleNextManilaDayRefresh(
          delay: const Duration(minutes: 1),
        );
        return;
      }
      unawaited(
        _loadDailyQuest(preserveCompletedStateOnFailure: true),
      );
    });
  }

  void _cancelQuestionTimer() {
    _timerGeneration++;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _showTimeUpDialog() async {
    if (_isTimeoutDialogShowing || !mounted) return;
    _isTimeoutDialogShowing = true;
    var retryingAttemptSave = false;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Text("Time's Up!"),
              actions: [
                if (_pendingAttempt != null)
                  TextButton(
                    onPressed: retryingAttemptSave
                        ? null
                        : () async {
                            setDialogState(() => retryingAttemptSave = true);
                            await _retrySaveAttempt();
                            if (!dialogContext.mounted) return;
                            setDialogState(() => retryingAttemptSave = false);
                          },
                    child: Text(
                      retryingAttemptSave ? 'Saving...' : 'Retry Save',
                    ),
                  ),
                TextButton(
                  onPressed: _pendingAttempt != null
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          _startQuestionTimer(restartAttempt: true);
                        },
                  child: const Text('Try Again'),
                ),
                TextButton(
                  onPressed: _pendingAttempt != null
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          Navigator.pop(context);
                        },
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      _isTimeoutDialogShowing = false;
    }
  }

  Future<void> _submitAnswer() async {
    if (_dailyQuestCompleted ||
        _isTimeUp ||
        _isSubmitted ||
        _isCheckingAnswer ||
        _attemptSaveFailed ||
        _isSavingCompletion ||
        _completionSaveFailed) {
      return;
    }

    if (_answerController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an answer first!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final isCorrect = _answerMatches(
      _answerController.text,
      _currentProblem.answer,
    );
    if (isCorrect == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid answer.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final attempt = ClassroomQuestAttempt(
        id: _newAttemptId(),
        questionNumber: _currentLevel + 1,
        answer: _answerController.text.trim(),
        isCorrect: isCorrect,
        score: isCorrect ? 10 : 0,
        attemptNumber: _attempts + 1,
        timeSpentSeconds: _elapsedQuestionSeconds(),
        timedOut: false,
        status: isCorrect ? 'correct' : 'incorrect',
      );
      setState(() {
        _isCheckingAnswer = true;
        _attempts += 1;
        _pendingAttempt = attempt;
        _pendingAttemptIsCorrect = isCorrect;
      });
      await _savePendingAttempt();
    } catch (error, stackTrace) {
      _reportAttemptSaveError(error, stackTrace);
      if (!mounted) return;
      setState(() {
        _isCheckingAnswer = false;
        _attemptSaveFailed = _pendingAttempt != null;
      });
      if (_pendingAttempt != null) {
        _showAttemptSaveFailure();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your attempt could not be prepared for saving.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int _elapsedQuestionSeconds() =>
      (_totalTime - _remainingSeconds).clamp(0, _totalTime);

  Future<void> _handleTimedOutAttempt(
    int questionNumber,
    int attemptNumber,
  ) async {
    ClassroomQuestAttempt? attempt;
    try {
      attempt = ClassroomQuestAttempt(
        id: _newAttemptId(),
        questionNumber: questionNumber,
        answer: '',
        isCorrect: false,
        score: 0,
        attemptNumber: attemptNumber,
        timeSpentSeconds: _totalTime,
        timedOut: true,
        status: 'timed_out',
      );
      await _recordClassroomQuestAttempt(attempt);
    } catch (error, stackTrace) {
      _reportAttemptSaveError(error, stackTrace);
      if (mounted) {
        setState(() {
          _pendingAttempt = attempt;
          _pendingAttemptIsCorrect = null;
          _attemptSaveFailed = attempt != null;
        });
        if (attempt != null) {
          _showAttemptSaveFailure();
        }
      }
    }
    if (mounted) await _showTimeUpDialog();
  }

  Future<void> _savePendingAttempt() async {
    final attempt = _pendingAttempt;
    if (attempt == null) return;
    try {
      await _recordClassroomQuestAttempt(attempt);
      final isCorrect = _pendingAttemptIsCorrect;
      final attemptId = attempt.id;
      if (!mounted) return;
      setState(() {
        _pendingAttempt = null;
        _pendingAttemptIsCorrect = null;
        _attemptSaveFailed = false;
        _isCheckingAnswer = false;
      });
      if (isCorrect != null) await _applyAnswerResult(isCorrect, attemptId);
    } catch (error, stackTrace) {
      _reportAttemptSaveError(error, stackTrace);
      if (!mounted) return;
      setState(() {
        _isCheckingAnswer = false;
        _attemptSaveFailed = true;
      });
      _showAttemptSaveFailure();
    }
  }

  String _newAttemptId() =>
      widget.attemptIdGenerator?.call() ??
      UserProgressService.newClassroomQuestAttemptId();

  Future<void> _recordClassroomQuestAttempt(
    ClassroomQuestAttempt attempt,
  ) async {
    final saveAttempt = widget.saveAttempt;
    if (saveAttempt != null) {
      await saveAttempt(attempt);
      return;
    }
    await UserProgressService.recordClassroomQuestAttempt(attempt);
  }

  Future<bool> _retrySaveAttempt() async {
    if (_dailyQuestCompleted || _pendingAttempt == null || _isCheckingAnswer) {
      return false;
    }
    setState(() => _isCheckingAnswer = true);
    await _savePendingAttempt();
    return !_attemptSaveFailed;
  }

  void _reportAttemptSaveError(Object error, StackTrace stackTrace) {
    final code = error is FirebaseException ? error.code : error.runtimeType;
    debugPrint(
      'Unable to save Classroom Quest attempt ($code) at '
      'users/{uid}/classroomQuestAttempts/{attemptId}.',
    );
    debugPrintStack(stackTrace: stackTrace);
  }

  void _showAttemptSaveFailure() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Could not save your attempt to My Progress.'),
        backgroundColor: Colors.red,
        action: _pendingAttempt == null
            ? null
            : SnackBarAction(
                label: 'Retry Save',
                onPressed: () => unawaited(_retrySaveAttempt()),
              ),
      ),
    );
  }

  Future<void> _applyAnswerResult(bool isCorrect, String attemptId) async {
    if (isCorrect) {
      _correctAnswers++;
      _correctAttemptIds.add(attemptId);
      if (_isLastLevel) {
        _cancelQuestionTimer();
        final elapsedMilliseconds =
            DateTime.now().difference(_completionStartedAt).inMilliseconds;
        final elapsedSeconds = (elapsedMilliseconds + 999) ~/ 1000;
        _pendingCompletionSeconds = elapsedSeconds < 1 ? 1 : elapsedSeconds;
        setState(() {
          _isCheckingAnswer = false;
          _feedbackMessage = 'Saving your Classroom Quest completion...';
        });
        await _saveCompletion();
      } else {
        setState(() {
          _currentLevel += 1;
          _isCheckingAnswer = false;
          _feedbackMessage = 'Correct! Starting stage ${_currentLevel + 1}.';
          _answerController.clear();
          _isSubmitted = false;
          _isTimeUp = false;
          _remainingSeconds = _totalTime;
          _attempts = 0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Correct! Stage ${_currentLevel + 1} is ready.'),
            backgroundColor: Colors.green,
          ),
        );

        _startQuestionTimer();
      }
    } else {
      setState(() {
        _feedbackMessage = 'Wrong answer. Attempts: $_attempts';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wrong answer. Attempts: $_attempts'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveCompletion() async {
    if (_dailyQuestCompleted ||
        _pendingCompletionSeconds == null ||
        _isSavingCompletion ||
        _isSubmitted) {
      return;
    }
    setState(() {
      _isSavingCompletion = true;
      _completionSaveFailed = false;
    });
    try {
      await UserProgressService.saveClassroomQuestCompletion(
        completionTimeSeconds: _pendingCompletionSeconds!,
        correctAnswers: _correctAnswers,
        totalQuestions: _questions.length,
        questionIds: _questions.map((question) => question.id).toList(),
        correctAttemptIds: List.unmodifiable(_correctAttemptIds),
      );
      if (!mounted) return;
      setState(() {
        _isSavingCompletion = false;
        _completionSaveFailed = false;
        _isSubmitted = true;
        _dailyQuestCompleted = true;
        _feedbackMessage =
            'Great job! You completed all stages in ${_formatTime(_pendingCompletionSeconds!)}.';
      });
      _scheduleNextManilaDayRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Classroom Quest completion saved.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error, stackTrace) {
      final code = error is FirebaseException ? error.code : error.runtimeType;
      debugPrint(
        'Unable to save Classroom Quest completion ($code) at '
        'users/{uid}.progress.classroomQuestHistory.',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _isSavingCompletion = false;
        _completionSaveFailed = true;
        _feedbackMessage = 'Your completion could not be saved. Please retry.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save your Classroom Quest result. Tap Retry Save to try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool? _answerMatches(String input, String expected) {
    final answer = _numericAnswer(input);
    final correct = _numericAnswer(expected);
    if (correct != null) return answer == null ? null : answer == correct;
    final normalizedInput =
        input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final normalizedExpected =
        expected.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (normalizedInput.isEmpty) return null;
    return normalizedInput == normalizedExpected;
  }

  double? _numericAnswer(String value) {
    final normalized = value.trim().replaceAll('−', '-');
    final fractionMatch =
        RegExp(r'^(-?\d+)\s*/\s*(-?\d+)$').firstMatch(normalized);
    if (fractionMatch != null) {
      final numerator = int.tryParse(fractionMatch.group(1)!);
      final denominator = int.tryParse(fractionMatch.group(2)!);
      if (numerator == null || denominator == null || denominator == 0) {
        return null;
      }
      return numerator / denominator;
    }

    final mixedMatch =
        RegExp(r'^(-?\d+)\s+(\d+)\s*/\s*(\d+)$').firstMatch(normalized);
    if (mixedMatch != null) {
      final whole = int.tryParse(mixedMatch.group(1)!);
      final numerator = int.tryParse(mixedMatch.group(2)!);
      final denominator = int.tryParse(mixedMatch.group(3)!);
      if (whole == null ||
          numerator == null ||
          denominator == null ||
          denominator == 0 ||
          numerator >= denominator) {
        return null;
      }
      return whole + (whole < 0 ? -1 : 1) * numerator / denominator;
    }
    return double.tryParse(normalized);
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remaining = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remaining';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDailyState || _dailyStateLoadFailed) {
      final message = _dailyQuestCompleted
          ? "You've already completed today's Classroom Quest. Come back tomorrow for a new challenge!"
          : _dailyStateLoadFailed
              ? 'Could not load today\'s Classroom Quest. Please try again.'
              : 'Loading today\'s Classroom Quest...';
      return Scaffold(
        body: MathBackground(
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (_isLoadingDailyState) ...[
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(),
                    ],
                    if (_dailyStateLoadFailed) ...[
                      const SizedBox(height: 20),
                      CustomButton(
                        text: 'Retry',
                        onPressed: () {
                          setState(() {
                            _isLoadingDailyState = true;
                            _dailyStateLoadFailed = false;
                          });
                          unawaited(_loadDailyQuest());
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    CustomButton(
                      text: 'Back',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final answerFieldObject =
        _answerFieldKey.currentContext?.findRenderObject();
    var answerFieldOffset = 0.0;
    if (keyboardInset > 0 &&
        answerFieldObject is RenderBox &&
        answerFieldObject.hasSize) {
      final keyboardTop = MediaQuery.sizeOf(context).height - keyboardInset;
      final answerFieldBottom =
          answerFieldObject.localToGlobal(Offset.zero).dy +
              answerFieldObject.size.height -
              _answerFieldOffset;
      final requiredOffset = keyboardTop - answerFieldBottom - 12;
      answerFieldOffset = requiredOffset < 0 ? requiredOffset : 0;
    }
    _answerFieldOffset = answerFieldOffset;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: MathBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),

                            // HEADER
                            Row(
                              children: [
                                const SizedBox(width: 48),
                                const Expanded(
                                  child: Text(
                                    'Classroom Quest',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 48),
                              ],
                            ),

                            const SizedBox(height: 30),

                            // 🔥 ORANGE CARD (NUMBER WIDTH CONTROL HERE)
                            Center(
                              child: Container(
                                width: double.infinity,
                                constraints:
                                    const BoxConstraints(maxWidth: 350),
                                padding: const EdgeInsets.all(25),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1D0AD),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Math Problem',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            'Level ${_currentLevel + 1} of ${_questions.length}',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Module ${_currentProblem.moduleNumber}',
                                            style:
                                                const TextStyle(fontSize: 18),
                                          ),
                                          const SizedBox(height: 15),
                                          Text(
                                            _currentProblem.prompt,
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 30),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Time Remaining',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color.fromARGB(255, 0, 0, 0),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _formatTime(_remainingSeconds),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color.fromARGB(255, 0, 0, 0),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Attempts',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '$_attempts',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            if (_feedbackMessage != null) ...[
                              const SizedBox(height: 20),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Text(
                                  _feedbackMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 30),

                            const Text(
                              'Your Answer',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),

                            const SizedBox(height: 10),

                            if (_dailyQuestCompleted) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F3E8),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Text(
                                  "You've already completed today's Classroom Quest. Come back tomorrow for a new challenge!",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF3D2A1B),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

                            Transform.translate(
                              offset: Offset(0, answerFieldOffset),
                              child: Center(
                                child: CustomTextField(
                                  key: _answerFieldKey,
                                  hint: 'Enter answer...',
                                  controller: _answerController,
                                  keyboardType: TextInputType.text,
                                  height: 60,
                                  width: 200,
                                  enabled: !_isTimeUp &&
                                      !_dailyQuestCompleted &&
                                      !_isSubmitted &&
                                      !_attemptSaveFailed &&
                                      !_isSavingCompletion &&
                                      !_completionSaveFailed,
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            Center(
                              child: SizedBox(
                                width: 200,
                                child: CustomButton(
                                  text: _dailyQuestCompleted
                                      ? 'Completed'
                                      : _isSubmitted
                                          ? '✅ Submitted!'
                                          : _attemptSaveFailed ||
                                                  _completionSaveFailed
                                              ? 'Retry Save'
                                              : _isSavingCompletion
                                                  ? 'Saving...'
                                                  : 'Submit Answer',
                                  onPressed: _dailyQuestCompleted ||
                                          _isSubmitted ||
                                          _isTimeUp ||
                                          _isCheckingAnswer ||
                                          _isSavingCompletion
                                      ? null
                                      : _attemptSaveFailed
                                          ? _retrySaveAttempt
                                          : _completionSaveFailed
                                              ? _saveCompletion
                                              : _submitAnswer,
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            Center(
                              child: SizedBox(
                                width: 200,
                                child: CustomButton(
                                  text: 'Back',
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
