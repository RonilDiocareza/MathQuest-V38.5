import 'package:flutter/material.dart';

class ResultDialog extends StatelessWidget {
  final bool failed;
  final int score;
  final VoidCallback onRetry;
  final VoidCallback onExit;
  const ResultDialog({super.key, required this.failed, required this.score, required this.onRetry, required this.onExit});

  @override
  Widget build(BuildContext context) {
    return Center(child: Material(child: Container(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(failed ? 'You failed' : 'You win'), const SizedBox(height: 10), Text('Score: $score'), const SizedBox(height: 10), Row(mainAxisSize: MainAxisSize.min, children: [ElevatedButton(onPressed: onRetry, child: const Text('Retry')), const SizedBox(width:10), ElevatedButton(onPressed: onExit, child: const Text('Exit'))])]))));
  }
}
