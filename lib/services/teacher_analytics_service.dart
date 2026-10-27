import 'package:cloud_firestore/cloud_firestore.dart';

class StudentAnalytics {
  final String uid;
  final String name;
  final String status;
  final bool hasProgressRecord;
  final String levelProgress;
  final int questAttempts;
  final int? classroomQuestCompletionTimeSeconds;
  final int levelsCompleted;
  final int totalLevels;
  final int? score;
  final List<int> completedLevelNumbers;
  final Map<int, int> gameModeFinalScores;
  final int completedNpcQuestionCount;
  final int? classroomQuestScore;
  final int? classroomQuestCorrectAnswers;
  final int? classroomQuestTotalQuestions;

  int get activityCount =>
      questAttempts +
      completedNpcQuestionCount +
      gameModeFinalScores.length +
      (classroomQuestScore != null ? 1 : 0);

  const StudentAnalytics({
    this.uid = '',
    required this.name,
    this.status = 'approved',
    this.hasProgressRecord = false,
    required this.levelProgress,
    required this.questAttempts,
    required this.classroomQuestCompletionTimeSeconds,
    required this.levelsCompleted,
    required this.totalLevels,
    this.score,
    this.completedLevelNumbers = const [],
    this.gameModeFinalScores = const {},
    this.completedNpcQuestionCount = 0,
    this.classroomQuestScore,
    this.classroomQuestCorrectAnswers,
    this.classroomQuestTotalQuestions,
  });

  StudentAnalytics copyWith({int? questAttempts}) => StudentAnalytics(
        uid: uid,
        name: name,
        status: status,
        hasProgressRecord: hasProgressRecord,
        levelProgress: levelProgress,
        questAttempts: questAttempts ?? this.questAttempts,
        classroomQuestCompletionTimeSeconds:
            classroomQuestCompletionTimeSeconds,
        levelsCompleted: levelsCompleted,
        totalLevels: totalLevels,
        score: score,
        completedLevelNumbers: completedLevelNumbers,
        gameModeFinalScores: gameModeFinalScores,
        completedNpcQuestionCount: completedNpcQuestionCount,
        classroomQuestScore: classroomQuestScore,
        classroomQuestCorrectAnswers: classroomQuestCorrectAnswers,
        classroomQuestTotalQuestions: classroomQuestTotalQuestions,
      );

  factory StudentAnalytics.fromUserDocument(
    String uid,
    Map<String, dynamic> data,
  ) {
    final rawProgress = data['progress'];
    final progress = _stringKeyedMap(rawProgress) ?? const {};
    final completedLevels = _readIntList(progress['completedLevels'])
        .where((level) => level >= 1 && level <= 60)
        .toSet()
        .toList()
      ..sort();

    final gameModeScores = <int, int>{};
    final rawGameModeScores = _stringKeyedMap(progress['gameModeFinalScores']);
    for (final entry
        in rawGameModeScores?.entries ?? const <MapEntry<String, dynamic>>[]) {
      final level = int.tryParse(entry.key);
      final score = _optionalNonNegativeInt(entry.value);
      if (level != null &&
          level >= 1 &&
          level <= 60 &&
          score != null &&
          score <= 70) {
        gameModeScores[level] = score;
      }
    }

    final questResults =
        _stringKeyedMap(progress['classroomQuestResults']) ?? const {};
    final quest = _stringKeyedMap(questResults['classroom_quest']);
    final completionTimes =
        _stringKeyedMap(progress['classroomQuestCompletionTimes']) ?? const {};
    final completionTime = _optionalNonNegativeInt(
          quest?['completionTimeSeconds'],
        ) ??
        _optionalNonNegativeInt(completionTimes['classroom_quest']);

    final npcQuestionsByLevel =
        _stringKeyedMap(progress['completedNpcQuestionsByLevel']);
    var completedNpcQuestionCount = 0;
    if (npcQuestionsByLevel == null || !npcQuestionsByLevel.containsKey('1')) {
      completedNpcQuestionCount =
          _readIntList(progress['completedNpcQuestions'])
              .where((question) => question >= 1 && question <= 6)
              .toSet()
              .length;
    }
    for (final entry in npcQuestionsByLevel?.entries ??
        const <MapEntry<String, dynamic>>[]) {
      final level = int.tryParse(entry.key);
      if (level == null || level <= 1 || level > 60) continue;
      completedNpcQuestionCount += _readIntList(entry.value)
          .where((question) => question >= 1 && question <= 6)
          .toSet()
          .length;
    }

    final rawName = data['name'];
    final name = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim()
        : 'Student';
    final levelsCompleted = completedLevels.length;

    return StudentAnalytics(
      uid: uid,
      name: name,
      status: data['status'] is String ? data['status'] as String : 'unknown',
      hasProgressRecord: rawProgress is Map && rawProgress.isNotEmpty,
      levelProgress: (levelsCompleted / 60 * 100).toStringAsFixed(1),
      questAttempts: _optionalNonNegativeInt(progress['questAttempts']) ?? 0,
      classroomQuestCompletionTimeSeconds: completionTime,
      levelsCompleted: levelsCompleted,
      totalLevels: 60,
      score: _studentScore(data),
      completedLevelNumbers: completedLevels,
      gameModeFinalScores: gameModeScores,
      completedNpcQuestionCount: completedNpcQuestionCount,
      classroomQuestScore: _optionalNonNegativeInt(quest?['score']),
      classroomQuestCorrectAnswers:
          _optionalNonNegativeInt(quest?['correctAnswers']),
      classroomQuestTotalQuestions:
          _optionalNonNegativeInt(quest?['totalQuestions']),
    );
  }
}

int? _studentScore(Map<String, dynamic> data) {
  final score = _optionalNonNegativeInt(data['gameScore']);
  if (score != null) return score;

  final baseline = _optionalNonNegativeInt(data['scoreBaseline']);
  final earned = _optionalNonNegativeInt(data['scoreEarned']);
  if (baseline == null || earned == null) return null;
  return baseline + earned;
}

int? _optionalNonNegativeInt(Object? value) {
  if (value is! num || !value.isFinite || value < 0 || value != value.toInt()) {
    return null;
  }
  return value.toInt();
}

List<int> _readIntList(Object? value) {
  if (value is! List) return const [];
  return value
      .map(_optionalNonNegativeInt)
      .whereType<int>()
      .toList(growable: false);
}

Map<String, dynamic>? _stringKeyedMap(Object? value) {
  if (value is! Map) return null;
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

class TeacherAnalyticsService {
  static List<StudentAnalytics> rankStudents(
    Iterable<StudentAnalytics> students,
  ) {
    final rankedStudents = students.toList();
    rankedStudents.sort((first, second) {
      final progressOrder =
          second.levelsCompleted.compareTo(first.levelsCompleted);
      if (progressOrder != 0) return progressOrder;

      final activityOrder = second.activityCount.compareTo(first.activityCount);
      if (activityOrder != 0) return activityOrder;

      final nameOrder = first.name.compareTo(second.name);
      if (nameOrder != 0) return nameOrder;
      return first.uid.compareTo(second.uid);
    });
    return rankedStudents;
  }

  static Stream<List<StudentAnalytics>> watchStudents() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .snapshots()
        .map((snapshot) {
      final students = snapshot.docs.map((document) =>
          StudentAnalytics.fromUserDocument(document.id, document.data()));
      return rankStudents(students);
    });
  }
}
