import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/services/leaderboard_service.dart';

void main() {
  test('sorts by score, then registration time, then uid', () {
    final entries = LeaderboardService.sortEntries([
      const LeaderboardEntry(
          uid: 'z-user', displayName: 'Zero Z', totalScore: 0),
      const LeaderboardEntry(
          uid: 'b-user', displayName: 'Tie B', totalScore: 20),
      const LeaderboardEntry(
          uid: 'a-user', displayName: 'Tie A', totalScore: 20),
      const LeaderboardEntry(
          uid: 'a-zero', displayName: 'Zero A', totalScore: 0),
      LeaderboardEntry(
        uid: 'new-zero',
        displayName: 'New Zero',
        totalScore: 0,
        createdAt: DateTime(2026, 3),
      ),
      LeaderboardEntry(
        uid: 'old-zero',
        displayName: 'Old Zero',
        totalScore: 0,
        createdAt: DateTime(2025, 3),
      ),
    ]);

    expect(
      entries.map((entry) => entry.uid).toList(),
      ['a-user', 'b-user', 'a-zero', 'z-user', 'old-zero', 'new-zero'],
    );
    expect(
      List<int>.generate(entries.length, (index) => index + 1),
      [1, 2, 3, 4, 5, 6],
    );
    expect(entries.skip(2).every((entry) => entry.totalScore == 0), isTrue);
  });
}
