import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/screens/home_screen.dart';

void main() {
  testWidgets('dashboard menu stays visible without a blocking loader',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen()),
    );
    await tester.pumpAndSettle();

    for (final label in [
      'Module',
      'Stages',
      'Classroom Quests',
      'My Progress',
      'Badges',
      'Leaderboard',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
