import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/screens/story_levels_screen.dart';
import 'package:flutter_mathquest/services/user_progress_service.dart';

UserProgress _progress({
  List<int> completedLevels = const [],
  int unlockedLevels = 1,
  Map<int, int> maxUnlockedSubLevel = const {1: 1, 2: 1, 3: 1},
}) =>
    UserProgress(
      completedLevels: completedLevels,
      completedNpcQuestions: const [],
      unlockedLevels: unlockedLevels,
      questAttempts: 0,
      maxUnlockedSubLevel: maxUnlockedSubLevel,
    );

Finder _levelCard(int displayNumber) => find
    .ancestor(
      of: find.text('$displayNumber'),
      matching: find.byType(GestureDetector),
    )
    .first;

void main() {
  testWidgets('Stage Selection applies confirmed progress updates live',
      (tester) async {
    final progressUpdates = StreamController<UserProgress>.broadcast();
    addTearDown(progressUpdates.close);

    await tester.pumpWidget(
      MaterialApp(
        home: StoryLevelsScreen(progressUpdates: progressUpdates.stream),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stage 1'));
    await tester.pumpAndSettle();

    expect(tester.widget<GestureDetector>(_levelCard(2)).onTap, isNull);

    progressUpdates.add(_progress(
      completedLevels: const [1],
      maxUnlockedSubLevel: const {1: 2, 2: 1, 3: 1},
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(tester.widget<GestureDetector>(_levelCard(2)).onTap, isNotNull);
    expect(tester.widget<GestureDetector>(_levelCard(3)).onTap, isNull);

    progressUpdates.add(_progress(
      completedLevels: const [1, 8],
      maxUnlockedSubLevel: const {1: 9, 2: 1, 3: 1},
    ));
    await tester.pumpAndSettle();
    expect(tester.widget<GestureDetector>(_levelCard(9)).onTap, isNotNull);

    progressUpdates.add(_progress(
      completedLevels: const [1, 8, 19],
      maxUnlockedSubLevel: const {1: 20, 2: 1, 3: 1},
    ));
    await tester.pumpAndSettle();
    expect(tester.widget<GestureDetector>(_levelCard(20)).onTap, isNotNull);

    progressUpdates.add(_progress(
      completedLevels: const [1, 8, 19, 20],
      unlockedLevels: 2,
      maxUnlockedSubLevel: const {1: 20, 2: 1, 3: 1},
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsNWidgets(4));
    await tester.tap(find.text('Stage 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stage 2'));
    await tester.pumpAndSettle();

    expect(tester.widget<GestureDetector>(_levelCard(1)).onTap, isNotNull);
  });

  testWidgets('failed completion does not unlock a level optimistically',
      (tester) async {
    final progressUpdates = StreamController<UserProgress>.broadcast();
    addTearDown(progressUpdates.close);

    await tester.pumpWidget(
      MaterialApp(
        home: StoryLevelsScreen(progressUpdates: progressUpdates.stream),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stage 1'));
    await tester.pumpAndSettle();

    expect(tester.widget<GestureDetector>(_levelCard(2)).onTap, isNull);
  });
}
