import 'package:flutter/material.dart';

class LitterDialog extends StatelessWidget {
  final String question;
  final List<String> choices;
  final int correctAnswerIndex;
  final VoidCallback onCorrect;
  final VoidCallback onWrong;
  const LitterDialog({super.key, required this.question, required this.choices, required this.correctAnswerIndex, required this.onCorrect, required this.onWrong});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(question),
      content: Column(mainAxisSize: MainAxisSize.min, children: choices.map((c) => ListTile(title: Text(c), onTap: (){ if (choices.indexOf(c)==correctAnswerIndex) {
        onCorrect();
      } else {
        onWrong();
      } })).toList()),
      actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Close'))],
    );
  }
}
