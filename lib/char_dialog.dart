import 'package:flutter/material.dart';

class BirdDialog extends StatelessWidget {
  final String imagePath;
  final List<String> acceptedAnswers;
  final String trivia;
  final String birdName;
  final VoidCallback onCorrect;
  final VoidCallback onWrong;
  const BirdDialog({super.key, required this.imagePath, required this.acceptedAnswers, required this.trivia, required this.birdName, required this.onCorrect, required this.onWrong});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(birdName),
      content: Column(mainAxisSize: MainAxisSize.min, children: [Image.asset(imagePath, width: 100, height: 100), Text(trivia)]),
      actions: [TextButton(onPressed: onWrong, child: const Text('Wrong')), TextButton(onPressed: onCorrect, child: const Text('Correct'))],
    );
  }
}
