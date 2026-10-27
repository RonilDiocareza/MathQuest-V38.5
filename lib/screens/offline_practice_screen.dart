import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../game/npc_question.dart';
import '../services/auth_service.dart';
import '../services/user_progress_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/math_background.dart';
import '../worksheet_lesson_data.dart';

class OfflinePracticeScreen extends StatefulWidget {
  const OfflinePracticeScreen({
    super.key,
    this.loadModuleAccess,
    this.random,
    this.isModalPanel = false,
  });

  final WorksheetModuleAccessLoader? loadModuleAccess;
  final Random? random;
  final bool isModalPanel;

  @override
  State<OfflinePracticeScreen> createState() => _OfflinePracticeScreenState();
}

class _OfflinePracticeScreenState extends State<OfflinePracticeScreen>
    with WidgetsBindingObserver {
  static const int _practiceQuestionCount = 10;

  WorksheetModuleAccess? _moduleAccess;
  StreamSubscription<void>? _sessionInvalidationSubscription;
  bool _isCheckingAccess = true;
  bool _sessionInvalidated = false;
  String? _accessError;
  int? _selectedModuleIndex;
  List<NpcQuestion> _questions = const [];
  int _questionIndex = 0;
  int _correctAnswers = 0;
  int? _selectedChoiceIndex;
  bool _answerSubmitted = false;
  bool _showSummary = false;
  int _accessRequest = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionInvalidationSubscription =
        AuthService.sessionInvalidations.listen((_) {
      _accessRequest++;
      if (!mounted) return;
      setState(() {
        _sessionInvalidated = true;
        _moduleAccess = null;
        _accessError = 'Your verified session is no longer valid.';
        _isCheckingAccess = false;
        _clearPracticeSession();
      });
    });
    unawaited(_loadModuleAccess(refreshFromServer: false));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_sessionInvalidated) {
      unawaited(_loadModuleAccess(refreshFromServer: true));
    }
  }

  Future<void> _loadModuleAccess({required bool refreshFromServer}) async {
    final request = ++_accessRequest;
    if (_moduleAccess == null && mounted) {
      setState(() => _isCheckingAccess = true);
    }
    try {
      final loadAccess = widget.loadModuleAccess ??
          UserProgressService.getWorksheetModuleAccess;
      final access = await loadAccess(refreshFromServer: refreshFromServer);
      if (!mounted || request != _accessRequest) return;
      if (!access.sessionVerified) {
        setState(() {
          _moduleAccess = null;
          _accessError =
              'Verify your student session online to use Practice Mode.';
          _isCheckingAccess = false;
          _clearPracticeSession();
        });
        return;
      }
      setState(() {
        _moduleAccess = access;
        _accessError = null;
        _isCheckingAccess = false;
      });
    } catch (error, stackTrace) {
      if (!mounted || request != _accessRequest) return;
      debugPrint('Unable to verify Practice Mode access: $error');
      debugPrintStack(stackTrace: stackTrace);
      setState(() {
        _moduleAccess = null;
        _accessError = error is WorksheetModuleAccessException
            ? error.message
            : 'Could not verify Practice Mode access. Try again when online.';
        _isCheckingAccess = false;
        _clearPracticeSession();
      });
    }
  }

  bool _isModuleUnlocked(int moduleIndex) =>
      !_sessionInvalidated &&
      (_moduleAccess?.canOpenModule(moduleIndex + 1) ?? false);

  void _clearPracticeSession() {
    _selectedModuleIndex = null;
    _questions = const [];
    _questionIndex = 0;
    _correctAnswers = 0;
    _selectedChoiceIndex = null;
    _answerSubmitted = false;
    _showSummary = false;
  }

  void _startPractice(int moduleIndex) {
    if (!_isModuleUnlocked(moduleIndex)) return;
    final questions = NpcQuestion.practiceQuestionsForModule(
      moduleIndex,
      count: _practiceQuestionCount,
      random: widget.random,
    );
    setState(() {
      _selectedModuleIndex = moduleIndex;
      _questions = questions;
      _questionIndex = 0;
      _correctAnswers = 0;
      _selectedChoiceIndex = null;
      _answerSubmitted = false;
      _showSummary = false;
    });
  }

  void _submitAnswer() {
    if (_answerSubmitted || _selectedChoiceIndex == null) return;
    setState(() {
      _answerSubmitted = true;
      if (_selectedChoiceIndex ==
          _questions[_questionIndex].correctAnswerIndex) {
        _correctAnswers++;
      }
    });
  }

  void _continuePractice() {
    if (!_answerSubmitted) return;
    if (_questionIndex + 1 == _questions.length) {
      setState(() => _showSummary = true);
      return;
    }
    setState(() {
      _questionIndex++;
      _selectedChoiceIndex = null;
      _answerSubmitted = false;
    });
  }

  void _returnToTopics() {
    setState(_clearPracticeSession);
  }

  WorksheetLesson? _lessonForQuestion(NpcQuestion question) {
    for (final lesson in worksheetLessons) {
      if (lesson.moduleId == question.moduleId &&
          lesson.question == question.prompt) {
        return lesson;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _accessRequest++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_sessionInvalidationSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('practice-back-button'),
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back),
                  color: Colors.black87,
                ),
                const Expanded(
                  child: Text(
                    'Practice Mode',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: _sessionInvalidated
                ? _buildAccessMessage(
                    'Your verified session is no longer valid. Sign in '
                    'again while online to continue.',
                  )
                : _isCheckingAccess && _moduleAccess == null
                    ? const Center(child: CircularProgressIndicator())
                    : _moduleAccess == null
                        ? _buildAccessMessage(
                            _accessError ??
                                'Verify your student session online to '
                                    'use Practice Mode.',
                          )
                        : _showSummary
                            ? _buildSummary()
                            : _questions.isNotEmpty
                                ? _buildQuestion()
                                : _buildTopicSelection(),
          ),
        ],
      ),
    );

    if (widget.isModalPanel) return content;

    return Scaffold(
      body: MathBackground(child: content),
    );
  }

  Widget _buildAccessMessage(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, color: Colors.black87),
              ),
              const SizedBox(height: 18),
              if (!_sessionInvalidated)
                CustomButton(
                  text: 'Retry Verification',
                  onPressed: () =>
                      unawaited(_loadModuleAccess(refreshFromServer: true)),
                ),
            ],
          ),
        ),
      );

  Widget _buildTopicSelection() => Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 4, 22, 12),
            child: Text(
              'Practice math questions anytime, even offline. Results do not '
              'affect your official score or progress. Choose an unlocked topic.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87, fontSize: 15),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              itemCount: worksheetModuleIds.length,
              itemBuilder: (context, index) {
                final unlocked = _isModuleUnlocked(index);
                final selected = _selectedModuleIndex == index;
                final requirement = _moduleAccess?.progress
                        ?.worksheetModuleUnlockLabel(index + 1) ??
                    UserProgress.worksheetModuleRequirementLabel(index + 1);
                return Card(
                  color: selected
                      ? const Color(0xFFF3D5AA)
                      : unlocked
                          ? const Color(0xFFFFF3D8)
                          : Colors.grey.shade300,
                  child: ListTile(
                    key: ValueKey('practice-topic-${index + 1}'),
                    enabled: unlocked,
                    onTap: unlocked
                        ? () => setState(() => _selectedModuleIndex = index)
                        : null,
                    leading: Icon(
                      unlocked ? Icons.calculate_outlined : Icons.lock_outline,
                      color: const Color(0xFF725A41),
                    ),
                    title: Text(
                      worksheetModuleNames[index],
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      unlocked ? 'Available for practice' : requirement,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: CustomButton(
              text: 'Start Practice',
              onPressed: _selectedModuleIndex != null &&
                      _isModuleUnlocked(_selectedModuleIndex!)
                  ? () => _startPractice(_selectedModuleIndex!)
                  : null,
            ),
          ),
        ],
      );

  Widget _buildQuestion() {
    final question = _questions[_questionIndex];
    final answer = question.choices[question.correctAnswerIndex];
    final lesson = _lessonForQuestion(question);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      children: [
        Text(
          worksheetModuleNames[_selectedModuleIndex!],
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF725A41),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Question ${_questionIndex + 1} of ${_questions.length}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3D8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF8A5C2E), width: 2),
          ),
          child: Text(
            question.prompt,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (var index = 0; index < question.choices.length; index++)
          Card(
            color: _answerSubmitted && index == question.correctAnswerIndex
                ? Colors.green.shade100
                : _answerSubmitted && index == _selectedChoiceIndex
                    ? Colors.red.shade100
                    : Colors.white.withValues(alpha: 0.9),
            child: ListTile(
              key: ValueKey('practice-choice-$index'),
              enabled: !_answerSubmitted,
              selected: _selectedChoiceIndex == index,
              onTap: _answerSubmitted
                  ? null
                  : () => setState(() => _selectedChoiceIndex = index),
              title: Text(
                question.choices[index],
                style: const TextStyle(color: Colors.black87, fontSize: 16),
              ),
              trailing: _selectedChoiceIndex == index
                  ? const Icon(Icons.check_circle, color: Color(0xFF57906A))
                  : null,
            ),
          ),
        if (_answerSubmitted) ...[
          const SizedBox(height: 10),
          Text(
            _selectedChoiceIndex == question.correctAnswerIndex
                ? 'Correct!'
                : 'Not quite. The correct answer is $answer.',
            key: const ValueKey('practice-answer-feedback'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _selectedChoiceIndex == question.correctAnswerIndex
                  ? Colors.green.shade900
                  : Colors.red.shade900,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (lesson != null) ...[
            const SizedBox(height: 8),
            Text(
              lesson.solution,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black87),
            ),
          ],
        ],
        const SizedBox(height: 16),
        Center(
          child: CustomButton(
            text: _answerSubmitted
                ? _questionIndex + 1 == _questions.length
                    ? 'View Results'
                    : 'Next Question'
                : 'Check Answer',
            onPressed: _answerSubmitted
                ? _continuePractice
                : _selectedChoiceIndex == null
                    ? null
                    : _submitAnswer,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Answered ${_questionIndex + (_answerSubmitted ? 1 : 0)} of '
          '${_questions.length}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final incorrectAnswers = _questions.length - _correctAnswers;
    final accuracy = _questions.isEmpty
        ? 0
        : (_correctAnswers * 100 / _questions.length).round();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PRACTICE RESULTS ONLY',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF725A41),
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            _summaryLine('Total practice questions', '${_questions.length}'),
            _summaryLine('Correct answers', '$_correctAnswers'),
            _summaryLine('Incorrect answers', '$incorrectAnswers'),
            _summaryLine('Practice accuracy', '$accuracy%'),
            const SizedBox(height: 12),
            const Text(
              'These results are for practice only. No official points or '
              'progress were changed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Practice Again',
              onPressed: _selectedModuleIndex == null
                  ? null
                  : () => _startPractice(_selectedModuleIndex!),
            ),
            const SizedBox(height: 10),
            CustomButton(
              text: 'Choose Another Topic',
              onPressed: _returnToTopics,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.maybePop(context),
              child: const Text('Return Home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryLine(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.black87, fontSize: 16),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
}
