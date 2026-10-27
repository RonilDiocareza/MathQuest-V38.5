import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/screens/badges_screen.dart';
import 'package:flutter_mathquest/screens/leaderboard_screen.dart';
import 'package:flutter_mathquest/services/verified_display_cache.dart';
import 'package:flutter_mathquest/widgets/connectivity_status_indicator.dart';

void main() {
  group('Verified display cache', () {
    test('separates users, sessions, and feature snapshots', () {
      final cache = VerifiedDisplayCacheStore();
      cache.put('student-a', 'session-a', 'progress', 'saved-progress-a');
      cache.put('student-a', 'session-a', 'leaderboard', 'saved-rankings-a');

      expect(
        cache.get<String>('student-a', 'session-a', 'progress'),
        'saved-progress-a',
      );
      expect(
        cache.get<String>('student-a', 'session-a', 'leaderboard'),
        'saved-rankings-a',
      );
      expect(
        cache.get<String>('student-b', 'session-a', 'progress'),
        isNull,
      );
      expect(
        cache.get<String>('student-a', 'new-session', 'progress'),
        isNull,
      );
    });

    test('clears private snapshots on session teardown', () {
      final cache = VerifiedDisplayCacheStore();
      cache.put('student-a', 'session-a', 'progress', 'saved-progress-a');
      cache.put('student-b', 'session-b', 'progress', 'saved-progress-b');

      cache.clearUid('student-a');
      expect(
        cache.get<String>('student-a', 'session-a', 'progress'),
        isNull,
      );
      expect(
        cache.get<String>('student-b', 'session-b', 'progress'),
        'saved-progress-b',
      );

      cache.clear();
      expect(
        cache.get<String>('student-b', 'session-b', 'progress'),
        isNull,
      );
    });
  });

  testWidgets('connectivity indicator starts unverified', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ConnectivityStatusIndicator()),
    );

    expect(find.text('Connection not verified'), findsOneWidget);
  });

  testWidgets('My Progress never shows zero badges without verified data',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BadgesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Could not load your badge progress.'), findsOneWidget);
    expect(find.text('0/9'), findsNothing);
    expect(find.text('Earned'), findsNothing);
  });

  testWidgets('leaderboard never shows an empty ranking as authoritative',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LeaderboardScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Could not load the leaderboard.'), findsOneWidget);
    expect(find.text('No scores yet.'), findsNothing);
  });
}
