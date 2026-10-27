import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'npc_question.dart';
import '../services/auth_service.dart';

class NpcQuestionDialog extends StatefulWidget {
  final NpcQuestion question;
  final Future<void> Function(String selectedAnswer, bool isCorrect)?
      onAnswerSelected;

  const NpcQuestionDialog({
    super.key,
    required this.question,
    this.onAnswerSelected,
  });

  @override
  State<NpcQuestionDialog> createState() => _NpcQuestionDialogState();
}

class _NpcQuestionDialogState extends State<NpcQuestionDialog> {
  bool _isSaving = false;
  int? _pendingAnswerIndex;
  String? _saveError;

  Future<void> _selectAnswer(int index) async {
    if (_isSaving) return;

    final question = widget.question;
    final isCorrect = index == question.correctAnswerIndex;
    final saveAnswer = widget.onAnswerSelected;
    if (saveAnswer == null) {
      Navigator.of(context).pop(isCorrect);
      return;
    }

    setState(() {
      _isSaving = true;
      _pendingAnswerIndex = index;
      _saveError = null;
    });
    try {
      await saveAnswer(question.choices[index], isCorrect);
      if (mounted) Navigator.of(context).pop(isCorrect);
    } catch (error, stackTrace) {
      debugPrint('Unable to save Game Mode answer: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        final message = await _answerSaveErrorMessage(error);
        if (!mounted) return;
        setState(() {
          _isSaving = false;
          _saveError = message;
        });
      }
    }
  }

  Future<String> _answerSaveErrorMessage(Object error) async {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return AuthService.savePermissionDeniedMessage('answer');
      }
      return switch (error.code) {
        'unauthenticated' =>
          'Your sign-in session expired. Sign in again, then retry saving.',
        'unavailable' ||
        'deadline-exceeded' =>
          'Firebase is temporarily unavailable. Check your connection and retry.',
        _ => 'Could not save your answer (${error.code}). Retry the save.',
      };
    }
    return 'Could not save your answer. Check your connection and retry.';
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final question = widget.question;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: screenHeight * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${question.questionNumber}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF52698F),
                        ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close question',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 40, height: 40),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                question.topic,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2B3B5A),
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                question.prompt,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              for (var index = 0; index < question.choices.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => _selectAnswer(index),
                    child: Text(
                      question.choices[index],
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (_isSaving) ...[
                const SizedBox(height: 8),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_saveError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _saveError!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: _pendingAnswerIndex == null
                      ? null
                      : () => _selectAnswer(_pendingAnswerIndex!),
                  child: const Text('Retry Save'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
