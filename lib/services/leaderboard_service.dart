import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firestore_transaction.dart';

class LeaderboardEntry {
  final String uid;
  final String displayName;
  final int totalScore;
  final int highestCompletedLevel;
  final DateTime? createdAt;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.totalScore,
    this.highestCompletedLevel = 0,
    this.createdAt,
  });
}

class LeaderboardEntriesSnapshot {
  const LeaderboardEntriesSnapshot({
    required this.entries,
    required this.isFromCache,
  });

  final List<LeaderboardEntry> entries;
  final bool isFromCache;
}

class LeaderboardService {
  static FirebaseFirestore? get _firestoreOrNull {
    try {
      return FirebaseFirestore.instance;
    } on FirebaseException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static FirebaseAuth? get _authOrNull {
    try {
      return FirebaseAuth.instance;
    } on FirebaseException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static const String collectionName = 'leaderboard';

  static CollectionReference<Map<String, dynamic>> get _collection {
    final firestore = _firestoreOrNull ??
        (throw StateError(
          'Firebase Firestore is not available because Firebase is not initialized.',
        ));
    return firestore.collection(collectionName);
  }

  static Stream<List<LeaderboardEntry>> watchTopEntries({
    int? limit,
  }) {
    return _collection.snapshots().map((snapshot) {
      final entries = sortEntries(
        snapshot.docs.map(_entryFromDocument).whereType<LeaderboardEntry>(),
      );
      return limit == null ? entries : entries.take(limit).toList();
    });
  }

  static Stream<LeaderboardEntriesSnapshot> watchTopEntriesWithSource({
    int? limit,
  }) {
    return _collection.snapshots(includeMetadataChanges: true).map((snapshot) {
      final entries = sortEntries(
        snapshot.docs.map(_entryFromDocument).whereType<LeaderboardEntry>(),
      );
      return LeaderboardEntriesSnapshot(
        entries: limit == null ? entries : entries.take(limit).toList(),
        isFromCache: snapshot.metadata.isFromCache,
      );
    });
  }

  static List<LeaderboardEntry> sortEntries(
    Iterable<LeaderboardEntry> entries,
  ) {
    final sortedEntries = entries.toList()
      ..sort((first, second) {
        final scoreOrder = second.totalScore.compareTo(first.totalScore);
        if (scoreOrder != 0) return scoreOrder;

        final firstCreatedAt = first.createdAt;
        final secondCreatedAt = second.createdAt;
        if (firstCreatedAt != null && secondCreatedAt != null) {
          final creationOrder = firstCreatedAt.compareTo(secondCreatedAt);
          if (creationOrder != 0) return creationOrder;
        } else if (firstCreatedAt == null && secondCreatedAt != null) {
          return -1;
        } else if (firstCreatedAt != null && secondCreatedAt == null) {
          return 1;
        }

        return first.uid.compareTo(second.uid);
      });
    return sortedEntries;
  }

  static Stream<LeaderboardEntry?> watchCurrentEntry() {
    final user = _authOrNull?.currentUser;

    if (user == null) {
      return Stream.value(null);
    }

    return _collection.doc(user.uid).snapshots().map((document) {
      if (!document.exists) {
        return null;
      }

      return _entryFromDocument(document);
    });
  }

  static LeaderboardEntry? _entryFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      return null;
    }

    final uid = (data['uid'] ?? document.id).toString();

    final displayName =
        (data['displayName'] ?? data['displayname'] ?? data['name'] ?? 'Player')
            .toString();

    final rawScore = data['totalScore'] ?? data['totalscore'] ?? 0;

    int totalScore;

    if (rawScore is int) {
      totalScore = rawScore;
    } else if (rawScore is num) {
      totalScore = rawScore.toInt();
    } else {
      totalScore = int.tryParse(rawScore.toString()) ?? 0;
    }

    return LeaderboardEntry(
      uid: uid,
      displayName: displayName,
      totalScore: totalScore,
      highestCompletedLevel:
          (data['highestCompletedLevel'] as num?)?.toInt() ?? 0,
      createdAt: _dateTimeFromValue(data['createdAt']),
    );
  }

  static DateTime? _dateTimeFromValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int _progressScore(Map<String, dynamic> userData) {
    final progress = userData['progress'] as Map<String, dynamic>? ?? {};
    final completedLevels = <int>{};
    for (final value in progress['completedLevels'] as List<dynamic>? ?? []) {
      final level = int.tryParse(value.toString());
      if (level != null && level >= 1 && level <= 60) {
        completedLevels.add(level);
      }
    }

    final rawFinalScores =
        progress['gameModeFinalScores'] as Map<String, dynamic>? ?? {};
    final finalScores = <int, int>{};
    for (final entry in rawFinalScores.entries) {
      final level = int.tryParse(entry.key);
      final score = entry.value;
      if (level != null &&
          level >= 1 &&
          level <= 60 &&
          score is int &&
          score >= 0 &&
          score <= 70) {
        finalScores[level] = score;
      }
    }

    final savedScore = userData['gameScore'];
    final baseline = userData['scoreBaseline'];
    final earned = userData['scoreEarned'];
    final storedScore = savedScore is num
        ? savedScore.toInt()
        : baseline is num && earned is num
            ? baseline.toInt() + earned.toInt()
            : 0;
    final finalGameModeScore =
        finalScores.values.fold<int>(0, (total, score) => total + score);
    final legacyCompletedLevelScore = completedLevels
            .where((level) => !finalScores.containsKey(level))
            .length *
        10;
    final progressScore = finalGameModeScore + legacyCompletedLevelScore;
    return storedScore > progressScore ? storedScore : progressScore;
  }

  static int _highestCompletedLevel(Map<String, dynamic> userData) {
    final progress = userData['progress'] as Map<String, dynamic>? ?? {};
    final completedLevels =
        (progress['completedLevels'] as List<dynamic>? ?? [])
            .map((value) => int.tryParse(value.toString()))
            .whereType<int>()
            .where((level) => level >= 1 && level <= 60)
            .toList();
    if (completedLevels.isNotEmpty) {
      return completedLevels.reduce((a, b) => a > b ? a : b);
    }
    final unlocked = progress['unlockedLevels'];
    return unlocked is num ? unlocked.toInt() : 0;
  }

  static Future<void> createRegistrationEntry({
    required String uid,
    required String displayName,
  }) async {
    final firestore = _firestoreOrNull ??
        (throw StateError(
          'Firebase Firestore is not available because Firebase is not initialized.',
        ));
    final userRef = firestore.collection('users').doc(uid);
    final leaderboardRef = _collection.doc(uid);
    await firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) {
        throw StateError('User profile not found.');
      }
      final userData = userSnapshot.data();
      if (userData == null ||
          userData['role']?.toString().toLowerCase() != 'student') {
        throw StateError('Only student accounts can join the leaderboard.');
      }

      final leaderboardSnapshot = await transaction.get(leaderboardRef);
      if (leaderboardSnapshot.exists) {
        final entryData = leaderboardSnapshot.data();
        if (entryData != null && entryData['createdAt'] == null) {
          transaction.update(leaderboardRef, {
            'createdAt': userData['createdAt'] ?? FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        return;
      }

      transaction.set(leaderboardRef, {
        'uid': uid,
        'displayName': (userData['name'] ?? displayName).toString(),
        'totalScore': 0,
        'createdAt': userData['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> ensureCurrentEntry() async {
    final user = _authOrNull?.currentUser;
    if (user == null) {
      throw StateError('No logged-in user.');
    }
    final firestore = _firestoreOrNull ??
        (throw StateError(
          'Firebase Firestore is not available because Firebase is not initialized.',
        ));
    final userRef = firestore.collection('users').doc(user.uid);
    final leaderboardRef = _collection.doc(user.uid);
    await runFirestoreTransactionWithRetry(firestore, (transaction) async {
      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) {
        throw StateError('User profile not found.');
      }

      final userData = userSnapshot.data();
      if (userData == null ||
          userData['role']?.toString().toLowerCase() != 'student' ||
          userData['status']?.toString().toLowerCase() != 'approved') {
        throw StateError('Only approved students can join the leaderboard.');
      }

      final leaderboardSnapshot = await transaction.get(leaderboardRef);
      final displayName = (userData['name'] ?? 'Player').toString();
      final profileCreatedAt = userData['createdAt'];
      final createdAt = profileCreatedAt ?? FieldValue.serverTimestamp();
      if (leaderboardSnapshot.exists) {
        final existingData = leaderboardSnapshot.data();
        if (existingData == null) {
          throw StateError('Leaderboard entry data is empty.');
        }

        final updates = <String, dynamic>{};
        if (existingData['uid'] != user.uid) {
          updates['uid'] = user.uid;
        }
        if (existingData['displayName'] != displayName) {
          updates['displayName'] = displayName;
        }
        if (existingData['createdAt'] != profileCreatedAt &&
            profileCreatedAt != null) {
          updates['createdAt'] = profileCreatedAt;
        } else if (existingData['createdAt'] is! Timestamp &&
            profileCreatedAt == null) {
          updates['createdAt'] = FieldValue.serverTimestamp();
        }
        if (updates.isNotEmpty) {
          updates['updatedAt'] = FieldValue.serverTimestamp();
          transaction.update(leaderboardRef, updates);
        }
        return;
      }

      transaction.set(leaderboardRef, {
        'uid': user.uid,
        'displayName': displayName,
        'totalScore': 0,
        'createdAt': createdAt,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> initializeApprovedStudentEntry(String uid) async {
    final admin = _authOrNull?.currentUser;
    if (admin == null) {
      throw StateError('No logged-in admin.');
    }

    final firestore = _firestoreOrNull ??
        (throw StateError(
          'Firebase Firestore is not available because Firebase is not initialized.',
        ));
    final adminRef = firestore.collection('users').doc(admin.uid);
    final studentRef = firestore.collection('users').doc(uid);
    final leaderboardRef = _collection.doc(uid);
    await firestore.runTransaction((transaction) async {
      final adminSnapshot = await transaction.get(adminRef);
      final studentSnapshot = await transaction.get(studentRef);
      final leaderboardSnapshot = await transaction.get(leaderboardRef);

      if (adminSnapshot.data()?['role']?.toString().toLowerCase() != 'admin') {
        throw StateError('Only admins can initialize student entries.');
      }
      final studentData = studentSnapshot.data();
      if (!studentSnapshot.exists ||
          studentData?['role']?.toString().toLowerCase() != 'student' ||
          studentData?['status']?.toString().toLowerCase() != 'approved') {
        throw StateError('Student account is not approved.');
      }
      if (leaderboardSnapshot.exists) {
        final entryData = leaderboardSnapshot.data();
        if (entryData != null && entryData['createdAt'] == null) {
          transaction.update(leaderboardRef, {
            'createdAt':
                studentData?['createdAt'] ?? FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        return;
      }

      transaction.set(leaderboardRef, {
        'uid': uid,
        'displayName': (studentData?['name'] ?? 'Player').toString(),
        'totalScore': 0,
        'createdAt': studentData?['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static String newScoreAwardId() => _collection.doc().id;

  static Future<bool> hasPendingLevelQuestionPoints(int level) async {
    if (level < 1 || level > 60) {
      throw ArgumentError.value(level, 'level');
    }
    final uid = _authOrNull?.currentUser?.uid;
    if (uid == null) return false;
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(
          'mathquest_pending_level_question_award_${uid}_$level',
        ) ??
        false;
  }

  static Future<void> addPoints(
    int points, {
    required String awardId,
  }) async {
    if (points != 5 && points != 10) {
      throw ArgumentError.value(
        points,
        'points',
        'Leaderboard awards must be 5 or 10 points.',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(awardId)) {
      throw ArgumentError.value(awardId, 'awardId');
    }
    await _awardPoints(points, 'mission-$awardId');
  }

  static Future<void> awardLevelQuestionPoints(int level) async {
    if (level < 1 || level > 60) {
      throw ArgumentError.value(level, 'level');
    }
    final uid = _authOrNull?.currentUser?.uid;
    if (uid == null) {
      throw StateError('No logged-in user.');
    }
    final preferences = await SharedPreferences.getInstance();
    final pendingKey = 'mathquest_pending_level_question_award_${uid}_$level';
    if (!await preferences.setBool(pendingKey, true)) {
      throw StateError('Unable to retain the pending leaderboard award.');
    }
    await _awardPoints(
      10,
      level.toString(),
      expectedUid: uid,
      levelQuestionLevel: level,
    );
    try {
      await preferences.remove(pendingKey);
    } catch (error, stackTrace) {
      debugPrint('Unable to clear saved leaderboard retry marker: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> _awardPoints(
    int points,
    String awardId, {
    String? expectedUid,
    int? levelQuestionLevel,
  }) async {
    final user = _authOrNull?.currentUser;
    if (user == null) {
      throw StateError('No logged-in user.');
    }
    if (expectedUid != null && user.uid != expectedUid) {
      throw StateError('The signed-in account changed during score saving.');
    }

    final firestore = _firestoreOrNull ??
        (throw StateError(
          'Firebase Firestore is not available because Firebase is not initialized.',
        ));
    final userRef = firestore.collection('users').doc(user.uid);
    final leaderboardRef = _collection.doc(user.uid);
    final awardRef = userRef.collection('scoreAwards').doc(awardId);

    await ensureCurrentEntry();
    await runFirestoreTransactionWithRetry(firestore, (transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final leaderboardSnapshot = await transaction.get(leaderboardRef);
      final awardSnapshot = await transaction.get(awardRef);
      if (!userSnapshot.exists || userSnapshot.data() == null) {
        throw StateError('User profile not found.');
      }

      final userData = userSnapshot.data()!;
      if (userData['role']?.toString().toLowerCase() != 'student' ||
          userData['status']?.toString().toLowerCase() != 'approved') {
        throw StateError('Only approved student accounts can earn points.');
      }

      if (awardSnapshot.exists) {
        final savedPoints = awardSnapshot.data()?['points'];
        if (savedPoints != points) {
          throw const FormatException(
            'The saved leaderboard score award is invalid.',
          );
        }
        return;
      }

      if (levelQuestionLevel != null) {
        final progress = userData['progress'];
        final answers =
            progress is Map ? progress['levelQuestionAnswers'] : null;
        if (answers is! Map ||
            !answers.containsKey(levelQuestionLevel.toString())) {
          throw StateError(
            'The level question must be completed before points are awarded.',
          );
        }
      }
      if (!leaderboardSnapshot.exists || leaderboardSnapshot.data() == null) {
        throw StateError('The leaderboard entry could not be initialized.');
      }

      final existingData = leaderboardSnapshot.data()!;
      final rawScore =
          existingData['totalScore'] ?? existingData['totalscore'] ?? 0;
      final oldScore = rawScore is int
          ? rawScore
          : rawScore is num
              ? rawScore.toInt()
              : int.tryParse(rawScore.toString());
      if (oldScore == null || oldScore < 0) {
        throw const FormatException('The saved leaderboard score is invalid.');
      }

      final userCreatedAt = userData['createdAt'];
      final createdAt = existingData['createdAt'] ??
          userCreatedAt ??
          FieldValue.serverTimestamp();
      final leaderboardUpdate = <String, dynamic>{
        'uid': user.uid,
        'displayName': (userData['name'] ?? 'Player').toString(),
        'totalScore': oldScore + points,
        'createdAt': createdAt,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (existingData.containsKey('displayname')) {
        leaderboardUpdate['displayname'] = FieldValue.delete();
      }
      if (existingData.containsKey('name')) {
        leaderboardUpdate['name'] = FieldValue.delete();
      }
      if (existingData.containsKey('totalscore')) {
        leaderboardUpdate['totalscore'] = FieldValue.delete();
      }

      transaction.set(awardRef, {
        'points': points,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(leaderboardRef, leaderboardUpdate);
    });
  }

  static Future<int?> getRank() async {
    final user = _authOrNull?.currentUser;

    if (user == null) {
      return null;
    }

    final sortedEntries = await getEntriesFromServer();
    final rank =
        sortedEntries.indexWhere((candidate) => candidate.uid == user.uid);
    return rank < 0 ? null : rank + 1;
  }

  static Future<List<LeaderboardEntry>> getEntriesFromServer() async {
    final snapshot = await _collection.get(
      const GetOptions(source: Source.server),
    );
    return sortEntries(
      snapshot.docs.map(_entryFromDocument).whereType<LeaderboardEntry>(),
    );
  }

  static Future<int> backfillEntries() async {
    final currentUser = _authOrNull?.currentUser;

    if (currentUser == null) {
      throw Exception('No logged-in user.');
    }

    final firestore = _firestoreOrNull ??
        (throw StateError(
          'Firebase Firestore is not available because Firebase is not initialized.',
        ));

    final adminSnapshot =
        await firestore.collection('users').doc(currentUser.uid).get();

    if (!adminSnapshot.exists) {
      throw Exception('Admin account not found.');
    }

    final adminData = adminSnapshot.data();

    if (adminData == null ||
        adminData['role']?.toString().toLowerCase() != 'admin') {
      throw Exception(
        'Only admins can sync the leaderboard.',
      );
    }

    final usersSnapshot = await firestore.collection('users').get();

    final leaderboardSnapshot = await _collection.get();

    final existingScores = <String, int>{};
    final existingCreationTimes = <String, Object?>{};

    for (final document in leaderboardSnapshot.docs) {
      final data = document.data();

      final rawScore = data['totalScore'] ?? data['totalscore'] ?? 0;

      int score;

      if (rawScore is int) {
        score = rawScore;
      } else if (rawScore is num) {
        score = rawScore.toInt();
      } else {
        score = int.tryParse(rawScore.toString()) ?? 0;
      }

      existingScores[document.id] = score;
      existingCreationTimes[document.id] = data['createdAt'];
    }

    final students = usersSnapshot.docs.where(
      (document) {
        final data = document.data();

        final role = data['role']?.toString().toLowerCase();

        return role == 'student';
      },
    ).toList();

    var processed = 0;
    for (var start = 0; start < students.length; start += 400) {
      final end = start + 400 < students.length ? start + 400 : students.length;

      final batch = firestore.batch();

      for (final userDocument in students.sublist(start, end)) {
        final data = userDocument.data();

        final uid = userDocument.id;

        final displayName = (data['name'] ?? 'Player').toString();

        final score = [
          existingScores[uid] ?? 0,
          _progressScore(data),
        ].reduce((left, right) => left > right ? left : right);
        final highestCompletedLevel = _highestCompletedLevel(data);

        final leaderboardRef = _collection.doc(uid);

        batch.set(
          leaderboardRef,
          {
            'uid': uid,
            'displayName': displayName,
            'totalScore': score,
            'highestCompletedLevel': highestCompletedLevel,
            'createdAt': data['createdAt'] ??
                existingCreationTimes[uid] ??
                FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      processed += end - start;
    }
    return processed;
  }
}
