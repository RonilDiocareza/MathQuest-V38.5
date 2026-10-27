import 'package:flutter/material.dart';

import '../services/user_progress_service.dart';

class GameModeAnswerHistoryEntry extends StatelessWidget {
  const GameModeAnswerHistoryEntry({
    super.key,
    required this.attempt,
  });

  final GameModeAnswerAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final attemptedAt = attempt.attemptedAt;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stage ${attempt.level} · Question ${attempt.questionNumber} · '
              '${attempt.isCorrect ? 'Correct' : 'Incorrect'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              'Score earned: ${attempt.scoreEarned} · '
              'Score after answer: ${attempt.scoreAfter}',
            ),
            Text(
              attemptedAt == null
                  ? 'Time: Syncing'
                  : 'Time: ${attemptedAt.toLocal()}',
            ),
          ],
        ),
      ),
    );
  }
}
