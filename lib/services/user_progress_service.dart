import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'leaderboard_service.dart';
import 'firestore_transaction.dart';
import 'auth_service.dart';
import '../worksheet_lesson_data.dart';

class UserProgress {
  static const int npcQuestionCount = 6;
  static const Map<int, List<int>> worksheetModuleRequiredCompletions = {
    2: [8],
    3: [15],
    4: [20],
    5: [25],
    6: [30],
    7: [35],
    8: [41, 42],
  };

  final List<int> completedLevels;
  final List<int> completedNpcQuestions;
  final Map<int, List<int>> completedNpcQuestionsByLevel;
  final int unlockedLevels;
  final int questAttempts;
  final Map<String, int> classroomQuestCompletionTimes;
  final Map<String, Map<String, dynamic>> classroomQuestResults;
  final Map<int, int> maxUnlockedSubLevel;
  final Map<int, LevelQuestionAnswer> levelQuestionAnswers;
  final Map<int, int> gameModeFinalScores;

  UserProgress({
    required this.completedLevels,
    required this.completedNpcQuestions,
    this.completedNpcQuestionsByLevel = const {},
    required this.unlockedLevels,
    required this.questAttempts,
    required this.maxUnlockedSubLevel,
    this.classroomQuestCompletionTimes = const {},
    this.classroomQuestResults = const {},
    this.levelQuestionAnswers = const {},
    this.gameModeFinalScores = const {},
  });

  int get completedCount => completedLevels.length;

  static UserProgress forClassroomQuest(Map<String, dynamic>? data) {
    final rawProgress = data?['progress'];
    if (rawProgress != null && rawProgress is! Map) {
      throw const FormatException(
        'Invalid saved progress while loading Classroom Quest.',
      );
    }
    final progress = rawProgress is Map ? rawProgress : const {};
    final rawCompletedLevels = progress['completedLevels'];
    if (rawCompletedLevels != null && rawCompletedLevels is! List) {
      throw const FormatException(
        'Invalid completed-level data while loading Classroom Quest.',
      );
    }
    final completedLevels = (rawCompletedLevels as List<dynamic>? ?? [])
        .map((value) => int.tryParse(value.toString()))
        .whereType<int>()
        .toSet()
        .toList()
      ..sort();
    return UserProgress(
      completedLevels: completedLevels,
      completedNpcQuestions: const [],
      unlockedLevels: 1,
      questAttempts: 0,
      maxUnlockedSubLevel: const {},
    );
  }

  int get completedNpcQuestionCount {
    var count = 0;
    for (final entry in completedNpcQuestionsByLevel.entries) {
      count += entry.value.length;
    }
    if (!completedNpcQuestionsByLevel.containsKey(1)) {
      count += completedNpcQuestions.toSet().length;
    }
    return count;
  }

  int get completedNpcRoundCount {
    var count = completedNpcQuestionsByLevel.values
        .where((questions) => questions.length >= npcQuestionCount)
        .length;
    if (!completedNpcQuestionsByLevel.containsKey(1) &&
        completedNpcQuestions.toSet().length >= npcQuestionCount) {
      count++;
    }
    return count;
  }

  int get currentNpcQuestionNumber {
    for (var questionNumber = 1;
        questionNumber <= npcQuestionCount;
        questionNumber++) {
      if (!completedNpcQuestions.contains(questionNumber)) {
        return questionNumber;
      }
    }
    return npcQuestionCount;
  }

  bool get areNpcQuestionsCompleted =>
      List.generate(npcQuestionCount, (index) => index + 1)
          .every(completedNpcQuestions.contains);

  List<int> completedNpcQuestionsForLevel(int level) =>
      completedNpcQuestionsByLevel[level] ??
      (level == 1 ? completedNpcQuestions : const []);

  int currentNpcQuestionNumberForLevel(int level) {
    final completed = completedNpcQuestionsForLevel(level);
    for (var questionNumber = 1;
        questionNumber <= npcQuestionCount;
        questionNumber++) {
      if (!completed.contains(questionNumber)) return questionNumber;
    }
    return npcQuestionCount;
  }

  bool areNpcQuestionsCompletedForLevel(int level) {
    final completed = completedNpcQuestionsForLevel(level);
    return List.generate(npcQuestionCount, (index) => index + 1)
        .every(completed.contains);
  }

  int get highestCompletedLevel =>
      completedLevels.isEmpty ? 0 : completedLevels.reduce(max);

  int? nextRequiredGameModeLevelForTopic(int level) {
    final moduleIndex = gameModeModuleIndexForLevel(level);
    for (var requiredLevel = 1;
        requiredLevel < gameModeModuleStartLevels[moduleIndex];
        requiredLevel++) {
      if (!gameModeFinalScores.containsKey(requiredLevel)) {
        return requiredLevel;
      }
    }
    return null;
  }

  bool isGameModeTopicUnlocked(int level) =>
      nextRequiredGameModeLevelForTopic(level) == null;

  bool isWorksheetModuleUnlocked(int moduleNumber) {
    if (moduleNumber < 1 || moduleNumber > 8) return false;
    if (moduleNumber == 1) return true;

    for (var module = 2; module <= moduleNumber; module++) {
      if (!worksheetModuleRequiredCompletions[module]!
          .every(completedLevels.contains)) {
        return false;
      }
    }
    return true;
  }

  String worksheetModuleUnlockLabel(int moduleNumber) {
    if (isWorksheetModuleUnlocked(moduleNumber)) return 'Unlocked';
    return worksheetModuleRequirementLabel(moduleNumber);
  }

  static String worksheetModuleRequirementLabel(int moduleNumber) {
    final requiredLevels = worksheetModuleRequiredCompletions[moduleNumber];
    if (requiredLevels == null) return 'Unlocked';

    final labels = requiredLevels.map((globalLevel) {
      return switch (globalLevel) {
        8 => 'Stage 1 - 8',
        15 => 'Stage 1 - 15',
        20 => 'Stage 1 - 20',
        25 => 'Stage 1',
        30 => 'Stage 2 - 10',
        35 => 'Stage 2 - 15',
        41 => 'Stage 1',
        42 => 'Stage 2',
        _ => throw StateError(
            'No worksheet module label is defined for level $globalLevel.',
          ),
      };
    }).toList(growable: false);
    if (labels.length == 1) return 'Complete ${labels.single}';
    return 'Complete ${labels.sublist(0, labels.length - 1).join(', ')} '
        'and ${labels.last}';
  }
}

class WorksheetModuleAccess {
  const WorksheetModuleAccess({
    required this.sessionVerified,
    required this.progress,
    required this.usingCachedProgress,
  });

  final bool sessionVerified;
  final UserProgress? progress;
  final bool usingCachedProgress;

  bool canOpenModule(int moduleNumber) =>
      sessionVerified &&
      (moduleNumber == 1 ||
          (progress?.isWorksheetModuleUnlocked(moduleNumber) ?? false));
}

typedef WorksheetModuleAccessLoader = Future<WorksheetModuleAccess> Function({
  required bool refreshFromServer,
});

class WorksheetModuleAccessException implements Exception {
  const WorksheetModuleAccessException(
    this.message, {
    this.securityFailure = false,
  });

  final String message;
  final bool securityFailure;

  @override
  String toString() => message;
}

class ClassroomQuestAttempt {
  const ClassroomQuestAttempt({
    required this.id,
    required this.questionNumber,
    required this.answer,
    required this.isCorrect,
    required this.score,
    required this.attemptNumber,
    required this.timeSpentSeconds,
    required this.timedOut,
    required this.status,
    this.attemptedAt,
  });

  final String id;
  final int questionNumber;
  final String answer;
  final bool isCorrect;
  final int score;
  final int attemptNumber;
  final int timeSpentSeconds;
  final bool timedOut;
  final String status;
  final DateTime? attemptedAt;

  static ClassroomQuestAttempt? fromDocument(
    String id,
    Map<String, dynamic> data,
  ) {
    final questionNumber = data['questionNumber'];
    final answer = data['answer'];
    final isCorrect = data['isCorrect'];
    final score = data['score'];
    final attemptNumber = data['attemptNumber'];
    final timeSpentSeconds = data['timeSpentSeconds'];
    final timedOut = data['timedOut'];
    final status = data['status'];
    final attemptedAtValue = data['attemptedAt'];
    if (data['questId'] != UserProgressService.classroomQuestId ||
        data['type'] != 'answer' ||
        questionNumber is! int ||
        questionNumber < 1 ||
        questionNumber > 3 ||
        answer is! String ||
        isCorrect is! bool ||
        score is! int ||
        attemptNumber is! int ||
        attemptNumber < 1 ||
        timeSpentSeconds is! int ||
        timeSpentSeconds < 0 ||
        timeSpentSeconds > 60 ||
        timedOut is! bool ||
        status is! String ||
        (attemptedAtValue != null &&
            attemptedAtValue is! Timestamp &&
            attemptedAtValue is! DateTime)) {
      return null;
    }
    if (timedOut) {
      if (answer.isNotEmpty ||
          isCorrect ||
          score != 0 ||
          status != 'timed_out') {
        return null;
      }
    } else if (answer.isEmpty ||
        status != (isCorrect ? 'correct' : 'incorrect') ||
        score != (isCorrect ? 10 : 0)) {
      return null;
    }

    return ClassroomQuestAttempt(
      id: id,
      questionNumber: questionNumber,
      answer: answer,
      isCorrect: isCorrect,
      score: score,
      attemptNumber: attemptNumber,
      timeSpentSeconds: timeSpentSeconds,
      timedOut: timedOut,
      status: status,
      attemptedAt: attemptedAtValue is Timestamp
          ? attemptedAtValue.toDate()
          : attemptedAtValue as DateTime?,
    );
  }

  Map<String, dynamic> toDocument(String uid) => {
        'uid': uid,
        'questId': UserProgressService.classroomQuestId,
        'type': 'answer',
        'questionNumber': questionNumber,
        'answer': answer,
        'isCorrect': isCorrect,
        'score': score,
        'attemptNumber': attemptNumber,
        'timeSpentSeconds': timeSpentSeconds,
        'timedOut': timedOut,
        'status': status,
        'attemptedAt': FieldValue.serverTimestamp(),
      };
}

class ClassroomQuestDailyState {
  const ClassroomQuestDailyState({
    required this.progress,
    required this.dayKey,
    required this.completed,
    required this.previousQuestionIds,
    this.completedQuestionIds = const [],
  });

  final UserProgress progress;
  final String dayKey;
  final bool completed;
  final List<String> previousQuestionIds;
  final List<String> completedQuestionIds;
}

class GameModeAnswerAttempt {
  const GameModeAnswerAttempt({
    required this.id,
    required this.level,
    required this.questionNumber,
    required this.question,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.scoreEarned,
    required this.scoreAfter,
    this.attemptedAt,
  });

  final String id;
  final int level;
  final int questionNumber;
  final String question;
  final String selectedAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final int scoreEarned;
  final int scoreAfter;
  final DateTime? attemptedAt;

  static GameModeAnswerAttempt? fromDocument(
    String id,
    Map<String, dynamic> data,
  ) {
    final level = data['level'];
    final questionNumber = data['questionNumber'];
    final question = data['question'];
    final selectedAnswer = data['selectedAnswer'];
    final correctAnswer = data['correctAnswer'];
    final isCorrect = data['isCorrect'];
    final scoreEarned = data['scoreEarned'];
    final scoreAfter = data['scoreAfter'];
    final attemptedAt = data['attemptedAt'];
    if (level is! int ||
        level < 1 ||
        level > 60 ||
        questionNumber is! int ||
        questionNumber < 1 ||
        questionNumber > UserProgress.npcQuestionCount ||
        question is! String ||
        selectedAnswer is! String ||
        correctAnswer is! String ||
        isCorrect is! bool ||
        scoreEarned is! int ||
        scoreEarned != (isCorrect ? 10 : 0) ||
        scoreAfter is! int ||
        scoreAfter < scoreEarned ||
        scoreAfter > 70 ||
        (attemptedAt != null &&
            attemptedAt is! Timestamp &&
            attemptedAt is! DateTime)) {
      return null;
    }
    return GameModeAnswerAttempt(
      id: id,
      level: level,
      questionNumber: questionNumber,
      question: question,
      selectedAnswer: selectedAnswer,
      correctAnswer: correctAnswer,
      isCorrect: isCorrect,
      scoreEarned: scoreEarned,
      scoreAfter: scoreAfter,
      attemptedAt: attemptedAt is Timestamp
          ? attemptedAt.toDate()
          : attemptedAt as DateTime?,
    );
  }
}

class GameModeAnswerAttemptIds {
  GameModeAnswerAttemptIds({required String Function() createId})
      : _createId = createId;

  final String Function() _createId;
  final Map<(String, bool), String> _idsByAnswer = {};

  String forAnswer(String answer, bool isCorrect) =>
      _idsByAnswer.putIfAbsent((answer, isCorrect), _createId);
}

class ProblemLevelAnswerAttemptIds {
  ProblemLevelAnswerAttemptIds({required String Function() createId})
      : _createId = createId;

  final String Function() _createId;
  final Map<(int, String, int, int), String> _idsByAnswer = {};

  String forAnswer({
    required int level,
    required String question,
    required int selectedAnswer,
    required int correctAnswer,
  }) =>
      _idsByAnswer.putIfAbsent(
        (level, question, selectedAnswer, correctAnswer),
        _createId,
      );
}

class LevelQuestionAnswer {
  const LevelQuestionAnswer({
    required this.firstOperand,
    required this.secondOperand,
    required this.operation,
    required this.correctAnswer,
  });

  final int firstOperand;
  final int secondOperand;
  final String operation;
  final int correctAnswer;

  factory LevelQuestionAnswer.fromData(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid saved level question.');
    }
    final firstOperand = value['firstOperand'];
    final secondOperand = value['secondOperand'];
    final operation = value['operation'];
    final correctAnswer = value['correctAnswer'];
    if (firstOperand is! num ||
        secondOperand is! num ||
        operation is! String ||
        correctAnswer is! num ||
        (operation != '+' && operation != '-') ||
        (operation == '+' &&
            firstOperand.toInt() + secondOperand.toInt() !=
                correctAnswer.toInt()) ||
        (operation == '-' &&
            firstOperand.toInt() - secondOperand.toInt() !=
                correctAnswer.toInt())) {
      throw const FormatException('Invalid saved level question.');
    }
    return LevelQuestionAnswer(
      firstOperand: firstOperand.toInt(),
      secondOperand: secondOperand.toInt(),
      operation: operation,
      correctAnswer: correctAnswer.toInt(),
    );
  }

  Map<String, dynamic> toData() => {
        'firstOperand': firstOperand,
        'secondOperand': secondOperand,
        'operation': operation,
        'correctAnswer': correctAnswer,
      };
}

class LevelQuestionCompletion {
  const LevelQuestionCompletion({
    required this.answer,
    required this.wasAlreadyCompleted,
  });

  final LevelQuestionAnswer answer;
  final bool wasAlreadyCompleted;
}

class UserProgressService {
  static const String classroomQuestId = 'classroom_quest';
  static const Duration _manilaUtcOffset = Duration(hours: 8);

  static String classroomQuestDayKey([DateTime? dateTime]) {
    final manilaDate = (dateTime ?? DateTime.now()).toUtc().add(
          _manilaUtcOffset,
        );
    return '${manilaDate.year.toString().padLeft(4, '0')}-'
        '${manilaDate.month.toString().padLeft(2, '0')}-'
        '${manilaDate.day.toString().padLeft(2, '0')}';
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

  static CollectionReference<Map<String, dynamic>> get _users {
    try {
      return FirebaseFirestore.instance.collection('users');
    } on FirebaseException {
      throw StateError(
          'Firebase Firestore is not available because Firebase is not initialized.');
    } catch (_) {
      throw StateError(
          'Firebase Firestore is not available because Firebase is not initialized.');
    }
  }

  static const _gameModeFinalScoreKeyPrefix =
      'mathquest_game_mode_final_score_';
  static const _gameModeIntroKeyPrefix = 'mathquest_game_mode_intro_seen_';
  static const Duration _moduleAccessVerificationTimeout = Duration(seconds: 8);
  static String? _cachedCurrentUid;
  static Future<UserProgress>? _cachedCurrentProgress;
  static String? _verifiedWorksheetUid;
  static String? _verifiedWorksheetSessionKey;
  static UserProgress? _verifiedWorksheetProgress;
  static StreamSubscription<void>? _sessionInvalidationSubscription;
  static StreamSubscription<User?>? _authStateSubscription;

  static void _ensureVerifiedWorksheetListeners() {
    _sessionInvalidationSubscription ??=
        AuthService.sessionInvalidations.listen((_) {
      _clearVerifiedWorksheetProgress();
    });
    _authStateSubscription ??= _authOrNull?.authStateChanges().listen(
      (user) {
        if (user?.uid != _verifiedWorksheetUid) {
          _clearVerifiedWorksheetProgress();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Unable to observe auth changes for module access: $error');
        debugPrintStack(stackTrace: stackTrace);
        _clearVerifiedWorksheetProgress();
      },
    );
  }

  static void _clearVerifiedWorksheetProgress() {
    _verifiedWorksheetUid = null;
    _verifiedWorksheetSessionKey = null;
    _verifiedWorksheetProgress = null;
  }

  static bool _isTemporaryNetworkFailure(String code) => const {
        'deadline-exceeded',
        'network-request-failed',
        'unavailable',
      }.contains(code);

  static WorksheetModuleAccess? _cachedWorksheetAccess(
    String uid,
    String sessionKey,
  ) {
    if (_verifiedWorksheetUid != uid ||
        _verifiedWorksheetSessionKey != sessionKey) {
      return null;
    }
    return WorksheetModuleAccess(
      sessionVerified: true,
      progress: _verifiedWorksheetProgress,
      usingCachedProgress: true,
    );
  }

  static Future<WorksheetModuleAccess> getWorksheetModuleAccess({
    bool refreshFromServer = false,
  }) async {
    _ensureVerifiedWorksheetListeners();
    final uid = _uid();
    final sessionKey = await AuthService.currentVerifiedSessionCacheKey();
    if (sessionKey == null) {
      _clearVerifiedWorksheetProgress();
      throw const WorksheetModuleAccessException(
        'Sign in and verify your active session online before opening lessons.',
        securityFailure: true,
      );
    }

    final cached = _cachedWorksheetAccess(uid, sessionKey);
    if (!refreshFromServer && cached != null) return cached;

    final SaveAuthorizationStatus authorization;
    try {
      authorization = await AuthService.checkCurrentSaveAuthorizationStatus()
          .timeout(_moduleAccessVerificationTimeout);
    } on TimeoutException {
      return cached ??
          const WorksheetModuleAccess(
            sessionVerified: true,
            progress: null,
            usingCachedProgress: true,
          );
    }
    if (authorization != SaveAuthorizationStatus.authorized) {
      if (authorization == SaveAuthorizationStatus.temporarilyUnableToVerify) {
        return cached ??
            const WorksheetModuleAccess(
              sessionVerified: true,
              progress: null,
              usingCachedProgress: true,
            );
      }

      _clearVerifiedWorksheetProgress();
      AuthService.invalidateCurrentVerifiedSession();
      throw WorksheetModuleAccessException(
        authorization == SaveAuthorizationStatus.accountNotApproved
            ? 'This student account is no longer approved.'
            : authorization == SaveAuthorizationStatus.sessionExpired
                ? 'The active student session is no longer valid.'
                : authorization ==
                        SaveAuthorizationStatus.securityVerificationFailed
                    ? 'Firebase denied verification of this student session.'
                    : 'Verify the student session online before opening lessons.',
        securityFailure: true,
      );
    }

    try {
      final snapshot = await _users
          .doc(uid)
          .get(
            const GetOptions(source: Source.server),
          )
          .timeout(_moduleAccessVerificationTimeout);
      final account = snapshot.data();
      if (!snapshot.exists ||
          account?['role']?.toString().toLowerCase() != 'student' ||
          account?['status']?.toString().toLowerCase() != 'approved') {
        _clearVerifiedWorksheetProgress();
        AuthService.invalidateCurrentVerifiedSession();
        throw const WorksheetModuleAccessException(
          'This student account is no longer approved.',
          securityFailure: true,
        );
      }

      final currentSessionKey =
          await AuthService.currentVerifiedSessionCacheKey();
      if (AuthService.currentUser?.uid != uid ||
          currentSessionKey != sessionKey) {
        _clearVerifiedWorksheetProgress();
        throw const WorksheetModuleAccessException(
          'The active student session changed while checking module access.',
          securityFailure: true,
        );
      }

      final progress = _fromData(account);
      _verifiedWorksheetUid = uid;
      _verifiedWorksheetSessionKey = sessionKey;
      _verifiedWorksheetProgress = progress;
      return WorksheetModuleAccess(
        sessionVerified: true,
        progress: progress,
        usingCachedProgress: false,
      );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Unable to refresh verified module progress: '
        'uid=$uid, path=users/$uid, plugin=${error.plugin}, '
        'code=${error.code}, message=${error.message}.',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (_isTemporaryNetworkFailure(error.code)) {
        return cached ??
            const WorksheetModuleAccess(
              sessionVerified: true,
              progress: null,
              usingCachedProgress: true,
            );
      }

      _clearVerifiedWorksheetProgress();
      if (error.code == 'permission-denied' ||
          error.code == 'unauthenticated') {
        AuthService.invalidateCurrentVerifiedSession();
      }
      rethrow;
    } on TimeoutException {
      return cached ??
          const WorksheetModuleAccess(
            sessionVerified: true,
            progress: null,
            usingCachedProgress: true,
          );
    } on WorksheetModuleAccessException {
      rethrow;
    } catch (error, stackTrace) {
      _clearVerifiedWorksheetProgress();
      debugPrint('Unable to parse verified module progress: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  static String _uid([String? uid]) {
    final resolved = uid ?? _authOrNull?.currentUser?.uid;
    if (resolved == null || resolved.isEmpty) {
      throw StateError('Not signed in.');
    }
    return resolved;
  }

  static String newClassroomQuestAttemptId() {
    return _users.doc(_uid()).collection('classroomQuestAttempts').doc().id;
  }

  static String newGameModeAnswerAttemptId() {
    return _users.doc(_uid()).collection('gameModeAttempts').doc().id;
  }

  static String newProblemLevelAnswerAttemptId() {
    return _users.doc(_uid()).collection('problemLevelAttempts').doc().id;
  }

  static Stream<UserProgress> watchCurrentUserProgress() {
    return _users
        .doc(_uid())
        .snapshots()
        .map((snapshot) => _fromData(snapshot.data()));
  }

  static Stream<(UserProgress, bool)> watchCurrentUserProgressWithSource() {
    return _users.doc(_uid()).snapshots(includeMetadataChanges: true).map(
          (snapshot) => (
            _fromData(snapshot.data()),
            snapshot.metadata.isFromCache,
          ),
        );
  }

  static Stream<List<GameModeAnswerAttempt>> watchGameModeAnswerAttempts({
    required String uid,
  }) {
    final targetUid = _uid(uid);
    return _users
        .doc(targetUid)
        .collection('gameModeAttempts')
        .orderBy('attemptedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((document) => GameModeAnswerAttempt.fromDocument(
                document.id, document.data()))
            .whereType<GameModeAnswerAttempt>()
            .toList(growable: false));
  }

  static Future<List<String>> getCorrectGameModeQuestions({
    required String uid,
  }) async {
    final snapshot = await _users
        .doc(_uid(uid))
        .collection('gameModeAttempts')
        .where('isCorrect', isEqualTo: true)
        .get();
    return snapshot.docs
        .map((document) => document.data()['question'])
        .whereType<String>()
        .where((question) => question.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static Future<void> recordGameModeAnswer({
    required String attemptId,
    required int level,
    required int questionNumber,
    required String question,
    required String selectedAnswer,
    required String correctAnswer,
    required bool isCorrect,
    required int scoreEarned,
    required int scoreAfter,
  }) async {
    if (attemptId.isEmpty || attemptId.length > 100) {
      throw ArgumentError.value(attemptId, 'attemptId');
    }
    if (level < 1 || level > 60) {
      throw ArgumentError.value(level, 'level');
    }
    if (questionNumber < 1 || questionNumber > UserProgress.npcQuestionCount) {
      throw ArgumentError.value(questionNumber, 'questionNumber');
    }
    if (question.isEmpty ||
        question.length > 500 ||
        selectedAnswer.isEmpty ||
        selectedAnswer.length > 120 ||
        correctAnswer.isEmpty ||
        correctAnswer.length > 120) {
      throw ArgumentError('Invalid Game Mode answer text.');
    }
    if (scoreEarned != (isCorrect ? 10 : 0) ||
        scoreAfter < scoreEarned ||
        scoreAfter > 70) {
      throw ArgumentError('Invalid Game Mode score.');
    }

    var stage = 'resolve authenticated student';
    try {
      final userId = _uid();
      final authUser = _authOrNull?.currentUser;
      debugPrint(
        'Game Mode answer save: authenticated=${authUser != null}, '
        'targetMatchesAuthenticated=${authUser?.uid == userId}, '
        'document=users/{uid}/gameModeAttempts/{attemptId}, '
        'write=create, level=$level, questionNumber=$questionNumber.',
      );
      final attemptRef =
          _users.doc(userId).collection('gameModeAttempts').doc(attemptId);
      final attemptData = <String, dynamic>{
        'uid': userId,
        'level': level,
        'questionNumber': questionNumber,
        'question': question,
        'selectedAnswer': selectedAnswer,
        'correctAnswer': correctAnswer,
        'isCorrect': isCorrect,
        'scoreEarned': scoreEarned,
        'scoreAfter': scoreAfter,
      };

      stage = 'read attempt document and commit transaction';
      await runFirestoreTransactionWithRetry<void>(FirebaseFirestore.instance,
          (transaction) async {
        final snapshot = await transaction.get(attemptRef);
        if (snapshot.exists) {
          final saved = snapshot.data()!;
          final isSameAttempt = attemptData.entries
              .every((entry) => saved[entry.key] == entry.value);
          if (!isSameAttempt) {
            throw StateError(
              'This Game Mode answer attempt ID is already used.',
            );
          }
          return;
        }

        transaction.set(attemptRef, {
          ...attemptData,
          'attemptedAt': FieldValue.serverTimestamp(),
        });
      });
      debugPrint(
        'Game Mode answer save: transaction committed for '
        'users/{uid}/gameModeAttempts/{attemptId}.',
      );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Game Mode answer save failed during "$stage": '
        'plugin=${error.plugin}, code=${error.code}, '
        'message=${error.message}.',
      );
      debugPrintStack(stackTrace: stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    } catch (error, stackTrace) {
      debugPrint(
        'Game Mode answer save failed during "$stage": '
        'exceptionType=${error.runtimeType}, message=$error.',
      );
      debugPrintStack(stackTrace: stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static Stream<List<ClassroomQuestAttempt>> watchClassroomQuestAttempts({
    String? uid,
  }) {
    return _users
        .doc(_uid(uid))
        .collection('classroomQuestAttempts')
        .orderBy('attemptedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((document) => ClassroomQuestAttempt.fromDocument(
                document.id, document.data()))
            .whereType<ClassroomQuestAttempt>()
            .toList(growable: false));
  }

  static Stream<int> watchClassroomQuestAttemptCount({String? uid}) {
    return _users
        .doc(_uid(uid))
        .snapshots()
        .map((snapshot) => _fromData(snapshot.data()).questAttempts);
  }

  static Future<ClassroomQuestDailyState> getCurrentClassroomQuestDailyState({
    DateTime? now,
  }) async {
    final uid = _uid();
    final userRef = _users.doc(uid);
    final dayKey = classroomQuestDayKey(now);
    final dailyRef =
        userRef.collection('classroomQuestDailyCompletions').doc(dayKey);
    Future<T> readAtStage<T>(String stage, Future<T> Function() read) async {
      try {
        return await read();
      } catch (error, stackTrace) {
        debugPrint(
          'Classroom Quest loading failed during "$stage": '
          'uid=$uid, document=${userRef.path}, '
          'exceptionType=${error.runtimeType}, message=$error'
          '${error is FirebaseException ? ', plugin=${error.plugin}, '
              'code=${error.code}, firebaseMessage=${error.message}' : ''}.',
        );
        debugPrintStack(stackTrace: stackTrace);
        Error.throwWithStackTrace(error, stackTrace);
      }
    }

    debugPrint(
      'Classroom Quest loading: reading server state for uid=$uid, '
      'dayKey=$dayKey.',
    );
    final snapshots = await Future.wait([
      readAtStage(
        'read student progress from server',
        () => userRef.get(const GetOptions(source: Source.server)),
      ),
      readAtStage(
        'read today\'s completion from server',
        () => dailyRef.get(const GetOptions(source: Source.server)),
      ),
      readAtStage(
        'read latest completion for question rotation from server',
        () => userRef
            .collection('classroomQuestDailyCompletions')
            .orderBy('completedAt', descending: true)
            .limit(1)
            .get(const GetOptions(source: Source.server)),
      ),
    ]);
    final userSnapshot = snapshots[0] as DocumentSnapshot<Map<String, dynamic>>;
    final dailySnapshot =
        snapshots[1] as DocumentSnapshot<Map<String, dynamic>>;
    final latestSnapshot = snapshots[2] as QuerySnapshot<Map<String, dynamic>>;
    final userData = userSnapshot.data();
    late final UserProgress progress;
    late final List<String> previousQuestionIds;
    late final List<String> completedQuestionIds;
    late final bool legacyCompletedToday;
    try {
      progress = UserProgress.forClassroomQuest(userData);
      final latestDaily =
          latestSnapshot.docs.isEmpty ? null : latestSnapshot.docs.first.data();
      final previousIds = latestDaily?['questionIds'];
      previousQuestionIds = previousIds is List
          ? previousIds.whereType<String>().toList(growable: false)
          : const [];
      final currentCompletedIds = dailySnapshot.data()?['questionIds'];
      completedQuestionIds = currentCompletedIds is List
          ? currentCompletedIds.whereType<String>().toList(growable: false)
          : const [];
      final legacyResult =
          (userData?['progress'] as Map?)?['classroomQuestResults'];
      final legacyCompletion =
          legacyResult is Map ? legacyResult[classroomQuestId] : null;
      final legacyCompletedAt =
          legacyCompletion is Map ? legacyCompletion['completedAt'] : null;
      legacyCompletedToday = legacyCompletedAt is Timestamp &&
          classroomQuestDayKey(legacyCompletedAt.toDate()) == dayKey;
    } catch (error, stackTrace) {
      debugPrint(
        'Classroom Quest loading failed during '
        '"parse student progress and daily status": '
        'uid=$uid, document=${userRef.path}, '
        'exceptionType=${error.runtimeType}, message=$error.',
      );
      debugPrintStack(stackTrace: stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
    debugPrint(
      'Classroom Quest loading: server state loaded; '
      'userDocumentExists=${userSnapshot.exists}, '
      'todayCompleted=${dailySnapshot.exists || legacyCompletedToday}, '
      'unlockedWorksheetModules=${List<int>.generate(8, (index) => index + 1).where(progress.isWorksheetModuleUnlocked).toList()}.',
    );
    return ClassroomQuestDailyState(
      progress: progress,
      dayKey: dayKey,
      completed: dailySnapshot.exists || legacyCompletedToday,
      previousQuestionIds: previousQuestionIds,
      completedQuestionIds: completedQuestionIds,
    );
  }

  static Future<void> recordClassroomQuestAttempt(
    ClassroomQuestAttempt attempt,
  ) async {
    var stage = 'resolve authenticated student';
    var documentPath = 'users/{uid}/classroomQuestAttempts/${attempt.id}';
    try {
      final uid = _uid();
      final userRef = _users.doc(uid);
      final attemptRef =
          userRef.collection('classroomQuestAttempts').doc(attempt.id);
      documentPath = attemptRef.path;
      stage = 'read user and attempt, then commit transaction';
      await FirebaseFirestore.instance
          .runTransaction<void>((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        final attemptSnapshot = await transaction.get(attemptRef);
        if (attemptSnapshot.exists) return;
        if (!userSnapshot.exists) {
          throw StateError('The user profile does not exist.');
        }

        final data = userSnapshot.data() ?? {};
        final rawProgress = data['progress'];
        if (rawProgress != null && rawProgress is! Map) {
          throw const FormatException('Invalid saved user progress.');
        }
        final progress = rawProgress is Map
            ? Map<String, dynamic>.from(rawProgress)
            : <String, dynamic>{};
        final savedAttempts = progress['questAttempts'] ?? 0;
        if (savedAttempts is! int || savedAttempts < 0) {
          throw const FormatException('Invalid saved Classroom Quest count.');
        }

        transaction.set(attemptRef, attempt.toDocument(uid));
        transaction.update(userRef, {
          'progress.questAttempts': savedAttempts + 1,
          'progress.latestClassroomQuestAttemptId': attempt.id,
        });
      });
      stage = 'commit Classroom Quest attempt transaction';
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Classroom Quest attempt save failed during "$stage": '
        'document=$documentPath, plugin=${error.plugin}, '
        'code=${error.code}, message=${error.message}.',
      );
      debugPrintStack(stackTrace: stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    } catch (error, stackTrace) {
      debugPrint(
        'Classroom Quest attempt save failed during "$stage": '
        'document=$documentPath, exceptionType=${error.runtimeType}, '
        'message=$error.',
      );
      debugPrintStack(stackTrace: stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
    _invalidateCurrentProgressCache();
  }

  static UserProgress _fromData(Map<String, dynamic>? data) {
    final progress = data?['progress'] as Map<String, dynamic>? ?? {};
    final completed = (progress['completedLevels'] as List<dynamic>? ?? [])
        .map((value) => int.tryParse(value.toString()))
        .whereType<int>()
        .toSet()
        .toList()
      ..sort();
    final completedNpcQuestions =
        (progress['completedNpcQuestions'] as List<dynamic>? ?? [])
            .map((value) => int.tryParse(value.toString()))
            .where((value) => value != null && value >= 1 && value <= 8)
            .cast<int>()
            .toSet()
            .toList()
          ..sort();
    final rawNpcQuestionsByLevel =
        progress['completedNpcQuestionsByLevel'] as Map<String, dynamic>? ?? {};
    final completedNpcQuestionsByLevel = <int, List<int>>{};
    for (final entry in rawNpcQuestionsByLevel.entries) {
      final level = int.tryParse(entry.key);
      final questions = (entry.value as List<dynamic>? ?? [])
          .map((value) => int.tryParse(value.toString()))
          .where((value) =>
              value != null &&
              value >= 1 &&
              value <= UserProgress.npcQuestionCount)
          .cast<int>()
          .toSet()
          .toList()
        ..sort();
      if (level != null && level >= 1 && level <= 60) {
        completedNpcQuestionsByLevel[level] = questions;
      }
    }
    final rawSublevels =
        progress['maxUnlockedSubLevel'] as Map<String, dynamic>? ?? {};
    final rawClassroomQuestCompletionTimes =
        progress['classroomQuestCompletionTimes'] as Map<String, dynamic>? ??
            {};
    final rawClassroomQuestResults =
        progress['classroomQuestResults'] as Map<String, dynamic>? ?? {};
    final rawLevelQuestionAnswers =
        progress['levelQuestionAnswers'] as Map<String, dynamic>? ?? {};
    final rawGameModeFinalScores =
        progress['gameModeFinalScores'] as Map<String, dynamic>? ?? {};
    return UserProgress(
      completedLevels: completed,
      completedNpcQuestions: completedNpcQuestions,
      completedNpcQuestionsByLevel: completedNpcQuestionsByLevel,
      unlockedLevels: (progress['unlockedLevels'] as num?)?.toInt() ?? 1,
      questAttempts: (progress['questAttempts'] as num?)?.toInt() ?? 0,
      classroomQuestCompletionTimes: {
        for (final entry in rawClassroomQuestCompletionTimes.entries)
          if (entry.value is num && (entry.value as num) >= 0)
            entry.key: (entry.value as num).toInt(),
      },
      classroomQuestResults: {
        for (final entry in rawClassroomQuestResults.entries)
          if (entry.value is Map<String, dynamic>)
            entry.key: Map<String, dynamic>.from(entry.value as Map),
      },
      maxUnlockedSubLevel: {
        1: (rawSublevels['1'] as num?)?.toInt() ?? 1,
        2: (rawSublevels['2'] as num?)?.toInt() ?? 1,
        3: (rawSublevels['3'] as num?)?.toInt() ?? 1,
      },
      levelQuestionAnswers: {
        for (final entry in rawLevelQuestionAnswers.entries)
          if (int.tryParse(entry.key) case final int level
              when level >= 1 && level <= 60)
            level: LevelQuestionAnswer.fromData(entry.value),
      },
      gameModeFinalScores: {
        for (final entry in rawGameModeFinalScores.entries)
          if (int.tryParse(entry.key) case final int level
              when level >= 1 && level <= 60)
            if (entry.value is int && entry.value >= 0 && entry.value <= 70)
              level: entry.value as int,
      },
    );
  }

  static Future<UserProgress> getProgressForUid(String uid) async {
    final snapshot = await _users.doc(uid).get();
    return _fromData(snapshot.data());
  }

  static Future<UserProgress> getProgressForEmail(String email) async {
    final snapshot =
        await _users.where('email', isEqualTo: email).limit(1).get();
    return snapshot.docs.isEmpty
        ? _fromData(null)
        : _fromData(snapshot.docs.first.data());
  }

  static Future<UserProgress> getCurrentUserProgress(
      {bool forceRefresh = false}) {
    final uid = _uid();
    if (forceRefresh ||
        _cachedCurrentUid != uid ||
        _cachedCurrentProgress == null) {
      _cachedCurrentUid = uid;
      _cachedCurrentProgress = getProgressForUid(uid).then<UserProgress>(
        (progress) => progress,
        onError: (Object error, StackTrace stackTrace) {
          if (_cachedCurrentUid == uid) {
            _cachedCurrentUid = null;
            _cachedCurrentProgress = null;
          }
          Error.throwWithStackTrace(error, stackTrace);
        },
      );
    }
    return _cachedCurrentProgress!;
  }

  static Future<void> preloadCurrentUserProgress() async {
    await getCurrentUserProgress();
  }

  static void _invalidateCurrentProgressCache() {
    _cachedCurrentUid = null;
    _cachedCurrentProgress = null;
  }

  static Future<LevelQuestionCompletion> completeLevelQuestion(
    int level,
    LevelQuestionAnswer answer,
  ) async {
    if (level < 1 || level > 60) {
      throw ArgumentError.value(level, 'level');
    }

    var stage = 'resolve authenticated user';
    try {
      final authUser = _authOrNull?.currentUser;
      debugPrint(
        'Level Question save: authenticated=${authUser != null}.',
      );
      final uid = _uid();
      final userRef = _users.doc(uid);
      debugPrint(
        'Level Question save: targetMatchesAuthenticated=${authUser?.uid == uid}, '
        'document=${userRef.path}, '
        'fields=[progress.levelQuestionAnswers.$level,'
        'progress.latestLevelQuestionAnswerLevel].',
      );

      stage = 'read user progress transaction';
      final completion =
          await runFirestoreTransactionWithRetry<LevelQuestionCompletion>(
        FirebaseFirestore.instance,
        (transaction) async {
          debugPrint('Level Question save: reading ${userRef.path}.');
          final snapshot = await transaction.get(userRef);
          debugPrint(
            'Level Question save: read completed; '
            'documentExists=${snapshot.exists}.',
          );
          if (!snapshot.exists) {
            throw StateError('The user progress document does not exist.');
          }

          stage = 'parse existing level question answer';
          final userData = snapshot.data()!;
          final rawProgress = userData['progress'];
          if (rawProgress != null && rawProgress is! Map<String, dynamic>) {
            throw const FormatException('Invalid saved user progress.');
          }
          final progress = rawProgress as Map<String, dynamic>?;
          final rawAnswers = progress?['levelQuestionAnswers'];
          if (rawAnswers != null && rawAnswers is! Map<String, dynamic>) {
            throw const FormatException(
              'Invalid saved level question answers.',
            );
          }
          final savedAnswerData =
              (rawAnswers as Map<String, dynamic>?)?[level.toString()];
          if (savedAnswerData != null) {
            debugPrint(
              'Level Question save: level $level was already completed; '
              'no write required.',
            );
            return LevelQuestionCompletion(
              answer: LevelQuestionAnswer.fromData(savedAnswerData),
              wasAlreadyCompleted: true,
            );
          }

          stage = 'write level question answer transaction';
          debugPrint(
            'Level Question save: writing ${userRef.path}; '
            'payloadFields=[progress.levelQuestionAnswers.$level,'
            'progress.latestLevelQuestionAnswerLevel], '
            'answerFields=firstOperand,secondOperand,operation,correctAnswer.',
          );
          transaction.update(userRef, {
            'progress.levelQuestionAnswers.$level': answer.toData(),
            'progress.latestLevelQuestionAnswerLevel': level.toString(),
          });
          return LevelQuestionCompletion(
            answer: answer,
            wasAlreadyCompleted: false,
          );
        },
      );
      debugPrint(
        'Level Question save: transaction committed; '
        'alreadyCompleted=${completion.wasAlreadyCompleted}.',
      );
      _invalidateCurrentProgressCache();
      return completion;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Level Question save failed during "$stage": '
        '${error.runtimeType}, code=${error.code}, message=${error.message}.',
      );
      debugPrintStack(stackTrace: stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    } catch (error, stackTrace) {
      debugPrint(
        'Level Question save failed during "$stage": '
        '${error.runtimeType}: $error.',
      );
      debugPrintStack(stackTrace: stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static Future<void> recordProblemLevelAnswer({
    required String attemptId,
    required int level,
    required String question,
    required int selectedAnswer,
    required int correctAnswer,
  }) async {
    if (attemptId.isEmpty || attemptId.length > 100) {
      throw ArgumentError.value(attemptId, 'attemptId');
    }
    if (level < 1 || level > 60) {
      throw ArgumentError.value(level, 'level');
    }
    if (question.isEmpty || question.length > 500) {
      throw ArgumentError.value(question, 'question');
    }

    final userId = _uid();
    final attemptRef =
        _users.doc(userId).collection('problemLevelAttempts').doc(attemptId);
    final attemptData = <String, dynamic>{
      'uid': userId,
      'level': level,
      'question': question,
      'selectedAnswer': selectedAnswer,
      'correctAnswer': correctAnswer,
      'isCorrect': selectedAnswer == correctAnswer,
    };

    var stage = 'start answer attempt transaction';
    try {
      final authUser = _authOrNull?.currentUser;
      if (kDebugMode) {
        debugPrint(
          'Problem Level answer save: authenticated=${authUser != null}, '
          'targetMatchesAuthenticated=${authUser?.uid == userId}, '
          'document=${attemptRef.path}, '
          'fields=[uid,level,question,selectedAnswer,correctAnswer,isCorrect,attemptedAt], '
          'write=create, level=$level, '
          'isCorrect=${selectedAnswer == correctAnswer}.',
        );
      }
      await runFirestoreTransactionWithRetry<void>(FirebaseFirestore.instance,
          (transaction) async {
        stage = 'read answer attempt document';
        final snapshot = await transaction.get(attemptRef);
        if (kDebugMode) {
          debugPrint(
            'Problem Level answer save: transaction read '
            '${attemptRef.path}; exists=${snapshot.exists}.',
          );
        }
        if (snapshot.exists) {
          final saved = snapshot.data()!;
          final isSameAttempt = attemptData.entries
              .every((entry) => saved[entry.key] == entry.value);
          if (!isSameAttempt) {
            throw StateError(
              'This Problem Level answer attempt ID is already used.',
            );
          }
          return;
        }

        stage = 'create answer attempt document';
        if (kDebugMode) {
          debugPrint(
            'Problem Level answer save: creating ${attemptRef.path}; '
            'fields=[uid,level,question,selectedAnswer,correctAnswer,'
            'isCorrect,attemptedAt].',
          );
        }
        transaction.set(attemptRef, {
          ...attemptData,
          'attemptedAt': FieldValue.serverTimestamp(),
        });
      });
      if (kDebugMode) {
        debugPrint(
          'Problem Level answer save: transaction committed for '
          '${attemptRef.path}.',
        );
      }
    } on FirebaseException catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Problem Level answer save failed during "$stage": '
          'document=${attemptRef.path}, '
          'plugin=${error.plugin}, code=${error.code}, '
          'message=${error.message}.',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Problem Level answer save failed during "$stage": '
          'document=${attemptRef.path}, '
          'exceptionType=${error.runtimeType}, message=$error.',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static Future<int?> getGameModeFinalScore(int level, {String? uid}) async {
    if (level < 1 || level > 60) {
      throw ArgumentError.value(level, 'level');
    }
    final savedScore =
        (await getProgressForUid(_uid(uid))).gameModeFinalScores[level];
    if (savedScore != null) return savedScore;

    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(
      '$_gameModeFinalScoreKeyPrefix${_uid(uid)}_$level',
    );
  }

  static Future<int?> getPendingGameModeScore(int level, {String? uid}) async {
    if (level < 1 || level > 60) {
      throw ArgumentError.value(level, 'level');
    }
    final resolvedUid = _uid(uid);
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(
      '$_gameModeFinalScoreKeyPrefix${resolvedUid}_pending_$level',
    );
  }

  static Future<void> clearPendingGameModeScore(
    int level, {
    String? uid,
  }) async {
    if (level < 1 || level > 60) {
      throw ArgumentError.value(level, 'level');
    }
    final resolvedUid = _uid(uid);
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(
      '$_gameModeFinalScoreKeyPrefix${resolvedUid}_pending_$level',
    );
  }

  static Future<bool> shouldShowGameModeIntroduction({String? uid}) async {
    final resolvedUid = _uid(uid);
    final preferences = await SharedPreferences.getInstance();
    return !(preferences.getBool('$_gameModeIntroKeyPrefix$resolvedUid') ??
        false);
  }

  static Future<void> markGameModeIntroductionSeen({String? uid}) async {
    final resolvedUid = _uid(uid);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('$_gameModeIntroKeyPrefix$resolvedUid', true);
  }

  static Future<void> completeGameMode(int level, int score) async {
    if (level < 1 || level > 60) {
      throw ArgumentError.value(level, 'level');
    }
    if (score < UserProgress.npcQuestionCount * 10 || score > 70) {
      throw ArgumentError.value(score, 'score');
    }

    final uid = _uid();
    final firestore = FirebaseFirestore.instance;
    final userRef = _users.doc(uid);
    final leaderboardRef =
        firestore.collection(LeaderboardService.collectionName).doc(uid);
    final awardRef = userRef.collection('scoreAwards').doc('game-mode-$level');

    var stage = 'start final score transaction';
    if (kDebugMode) {
      debugPrint(
        'Game Mode final score save: '
        'userDocument=${userRef.path}, '
        'leaderboardDocument=${leaderboardRef.path}, '
        'awardDocument=${awardRef.path}, level=$level, score=$score.',
      );
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      final pendingScoreKey =
          '$_gameModeFinalScoreKeyPrefix${uid}_pending_$level';
      if (!await preferences.setInt(pendingScoreKey, score)) {
        throw StateError('Unable to retain the pending Game Mode score.');
      }
      await runFirestoreTransactionWithRetry<void>(firestore,
          (transaction) async {
        stage = 'read user, leaderboard, and score award';
        final userSnapshot = await transaction.get(userRef);
        final leaderboardSnapshot = await transaction.get(leaderboardRef);
        final awardSnapshot = await transaction.get(awardRef);
        if (kDebugMode) {
          debugPrint(
            'Game Mode final score save: transaction reads completed; '
            'userExists=${userSnapshot.exists}, '
            'leaderboardExists=${leaderboardSnapshot.exists}, '
            'awardExists=${awardSnapshot.exists}.',
          );
        }
        if (!userSnapshot.exists) {
          throw StateError('User profile not found.');
        }

        final userData = userSnapshot.data()!;
        if (userData['role']?.toString().toLowerCase() != 'student' ||
            userData['status']?.toString().toLowerCase() != 'approved') {
          throw StateError(
              'Only approved student accounts can save Game Mode scores.');
        }

        final savedProgress = _fromData(userData);
        final existingScore = savedProgress.gameModeFinalScores[level];
        if (existingScore != null) {
          if (existingScore != score) {
            throw StateError('A completed Game Mode score cannot be changed.');
          }
          if (kDebugMode) {
            debugPrint(
              'Game Mode final score save: level $level is already saved; '
              'no write required.',
            );
          }
          return;
        }

        if (!savedProgress.areNpcQuestionsCompletedForLevel(level)) {
          throw StateError(
            'All NPC questions must be completed before saving a Game Mode score.',
          );
        }

        if (awardSnapshot.exists) {
          throw StateError(
            'Game Mode score award exists without a completed score record.',
          );
        }

        final baseline = userData['scoreBaseline'] ?? 0;
        final earned = userData['scoreEarned'] ?? 0;
        if (baseline is! int || baseline < 0 || earned is! int || earned < 0) {
          throw const FormatException('The saved total score data is invalid.');
        }
        final oldLeaderboardScore =
            _leaderboardScore(leaderboardSnapshot.data() ?? const {});
        final newEarned = earned + score;
        final newGameScore = baseline + newEarned;
        if (newGameScore < 0) {
          throw const FormatException('The saved total score data is invalid.');
        }

        final completed = FieldValue.arrayUnion([level]);
        final mainLevel = ((level - 1) ~/ 20) + 1;
        final displayNumber = level % 20 == 0 ? 20 : level % 20;
        final nextSubLevel = displayNumber + 1;
        final sublevels = {...savedProgress.maxUnlockedSubLevel};
        if (nextSubLevel <= 20 && nextSubLevel > (sublevels[mainLevel] ?? 1)) {
          sublevels[mainLevel] = nextSubLevel;
        }
        final unlockedLevels = displayNumber == 20 && mainLevel < 3
            ? max(savedProgress.unlockedLevels, mainLevel + 1)
            : savedProgress.unlockedLevels;

        stage = 'write final score and user progress';
        if (kDebugMode) {
          debugPrint(
            'Game Mode final score save: updating ${userRef.path}; '
            'fields=[progress.completedLevels,progress.unlockedLevels,'
            'progress.maxUnlockedSubLevel,'
            'progress.gameModeFinalScores.$level,'
            'progress.latestCompletedGameModeLevel,scoreEarned,gameScore].',
          );
        }
        transaction.update(userRef, {
          'progress.completedLevels': completed,
          'progress.unlockedLevels': unlockedLevels,
          'progress.maxUnlockedSubLevel': {
            '1': sublevels[1] ?? 1,
            '2': sublevels[2] ?? 1,
            '3': sublevels[3] ?? 1,
          },
          'progress.gameModeFinalScores.$level': score,
          'progress.latestCompletedGameModeLevel': '$level',
          'scoreEarned': newEarned,
          'gameScore': newGameScore,
        });

        stage = 'create one-time score award';
        transaction.set(awardRef, {
          'points': score,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final displayName = (userData['name'] ?? 'Player').toString();
        final totalScore = oldLeaderboardScore + score;
        final createdAt = userData['createdAt'] ?? FieldValue.serverTimestamp();
        stage = leaderboardSnapshot.exists
            ? 'update leaderboard score'
            : 'create leaderboard score';
        if (kDebugMode) {
          debugPrint(
            'Game Mode final score save: $stage at '
            '${leaderboardRef.path}; fields=[uid,displayName,totalScore,'
            'createdAt,updatedAt], newTotalScore=$totalScore.',
          );
        }
        if (leaderboardSnapshot.exists) {
          final existingLeaderboard =
              leaderboardSnapshot.data() ?? const <String, dynamic>{};
          final leaderboardUpdate = <String, dynamic>{
            'uid': uid,
            'displayName': displayName,
            'totalScore': totalScore,
            'createdAt': createdAt,
            'updatedAt': FieldValue.serverTimestamp(),
          };
          if (existingLeaderboard.containsKey('displayname')) {
            leaderboardUpdate['displayname'] = FieldValue.delete();
          }
          if (existingLeaderboard.containsKey('name')) {
            leaderboardUpdate['name'] = FieldValue.delete();
          }
          if (existingLeaderboard.containsKey('totalscore')) {
            leaderboardUpdate['totalscore'] = FieldValue.delete();
          }
          transaction.update(leaderboardRef, leaderboardUpdate);
        } else {
          transaction.set(leaderboardRef, {
            'uid': uid,
            'displayName': displayName,
            'totalScore': totalScore,
            'createdAt': createdAt,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        stage = 'commit final score transaction';
      });
      if (kDebugMode) {
        debugPrint('Game Mode final score save: transaction committed.');
      }
      try {
        await preferences.remove(pendingScoreKey);
      } catch (error, stackTrace) {
        debugPrint(
            'Unable to clear saved Game Mode score retry marker: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    } on FirebaseException catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Game Mode final score save failed during "$stage": '
          'plugin=${error.plugin}, code=${error.code}, '
          'message=${error.message}.',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Game Mode final score save failed during "$stage": '
          'exceptionType=${error.runtimeType}, message=$error.',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    _invalidateCurrentProgressCache();
  }

  static int _leaderboardScore(Map<String, dynamic> data) {
    final rawScore = data['totalScore'] ?? data['totalscore'] ?? 0;
    if (rawScore is int && rawScore >= 0) return rawScore;
    if (rawScore is num && rawScore >= 0) return rawScore.toInt();
    final parsedScore = int.tryParse(rawScore.toString());
    if (parsedScore != null && parsedScore >= 0) return parsedScore;
    throw const FormatException('The saved leaderboard score is invalid.');
  }

  static Future<void> saveLevelCompletion(int level, {String? email}) async {
    final userRef = _users.doc(_uid());
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final progress = _fromData(snapshot.data());
      final completed = {...progress.completedLevels, level}.toList()..sort();
      final mainLevel = ((level - 1) ~/ 20) + 1;
      final displayNumber = level % 20 == 0 ? 20 : level % 20;
      final nextSubLevel = displayNumber + 1;
      final sublevels = {...progress.maxUnlockedSubLevel};
      if (nextSubLevel <= 20 && nextSubLevel > (sublevels[mainLevel] ?? 1)) {
        sublevels[mainLevel] = nextSubLevel;
      }
      final unlockedLevels = displayNumber == 20 && mainLevel < 3
          ? max(progress.unlockedLevels, mainLevel + 1)
          : progress.unlockedLevels;
      transaction.set(
        userRef,
        {
          'progress': {
            'completedLevels': completed,
            'unlockedLevels': unlockedLevels,
            'questAttempts': progress.questAttempts,
            'maxUnlockedSubLevel': {
              '1': sublevels[1] ?? 1,
              '2': sublevels[2] ?? 1,
              '3': sublevels[3] ?? 1,
            },
          },
        },
        SetOptions(merge: true),
      );
    });
    _invalidateCurrentProgressCache();
  }

  static Future<bool> completeNpcQuestion(
    int questionNumber, {
    String? uid,
    int level = 1,
  }) async {
    if (questionNumber < 1 || questionNumber > UserProgress.npcQuestionCount) {
      throw ArgumentError.value(questionNumber, 'questionNumber');
    }
    if (level < 1 || level > 60) {
      throw ArgumentError.value(level, 'level');
    }

    final userRef = _users.doc(_uid(uid));
    var stage = 'read and update NPC progress transaction';
    try {
      final completed = await runFirestoreTransactionWithRetry<bool>(
        FirebaseFirestore.instance,
        (transaction) async {
          final snapshot = await transaction.get(userRef);
          if (!snapshot.exists) {
            throw StateError('User profile not found.');
          }
          final progress = _fromData(snapshot.data());
          if (progress
              .completedNpcQuestionsForLevel(level)
              .contains(questionNumber)) {
            return true;
          }
          if (progress.areNpcQuestionsCompletedForLevel(level) ||
              progress.currentNpcQuestionNumberForLevel(level) !=
                  questionNumber) {
            return false;
          }

          final questions = {
            ...progress.completedNpcQuestionsForLevel(level),
            questionNumber,
          }.toList()
            ..sort();
          final completedByLevel = {
            for (final entry in progress.completedNpcQuestionsByLevel.entries)
              entry.key.toString(): entry.value,
            level.toString(): questions,
          };
          final updatedProgress = <String, dynamic>{
            'completedNpcQuestionsByLevel': completedByLevel,
            'latestCompletedNpcQuestionLevel': level.toString(),
          };
          if (level == 1) {
            updatedProgress['completedNpcQuestions'] = questions;
          }
          stage = 'write NPC progress transaction';
          transaction.set(
            userRef,
            {'progress': updatedProgress},
            SetOptions(merge: true),
          );
          return true;
        },
      );
      if (completed) _invalidateCurrentProgressCache();
      return completed;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'NPC progress save failed during "$stage": '
        'plugin=${error.plugin}, code=${error.code}, '
        'message=${error.message}.',
      );
      debugPrintStack(stackTrace: stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    } catch (error, stackTrace) {
      debugPrint(
        'NPC progress save failed during "$stage": '
        'exceptionType=${error.runtimeType}, message=$error.',
      );
      debugPrintStack(stackTrace: stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static Future<void> resetNpcQuestionsForLevel(
    int level, {
    String? uid,
  }) async {
    if (level < 1 || level > 60) {
      throw ArgumentError.value(level, 'level');
    }

    final userRef = _users.doc(_uid(uid));
    await FirebaseFirestore.instance.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) return;

      final progress = _fromData(snapshot.data());
      if (!progress.completedNpcQuestionsByLevel.containsKey(level) &&
          (level != 1 || progress.completedNpcQuestions.isEmpty)) {
        return;
      }

      final updates = <String, dynamic>{
        'progress.completedNpcQuestionsByLevel.$level': FieldValue.delete(),
      };
      if (level == 1) {
        updates['progress.completedNpcQuestions'] = <int>[];
      }
      transaction.update(userRef, updates);
    });
    _invalidateCurrentProgressCache();
  }

  static Future<void> saveClassroomQuestCompletion({
    required int completionTimeSeconds,
    required int correctAnswers,
    required int totalQuestions,
    required List<String> questionIds,
    required List<String> correctAttemptIds,
  }) async {
    if (completionTimeSeconds < 1) {
      throw ArgumentError.value(completionTimeSeconds, 'completionTimeSeconds');
    }
    if (totalQuestions != 3 || correctAnswers != 3) {
      throw ArgumentError(
        'A completed Classroom Quest must have all three questions correct.',
      );
    }
    if (questionIds.length != totalQuestions ||
        questionIds.toSet().length != totalQuestions ||
        correctAttemptIds.length != totalQuestions ||
        correctAttemptIds.toSet().length != totalQuestions) {
      throw ArgumentError(
        'A completed Classroom Quest must include three unique questions '
        'and their saved correct attempts.',
      );
    }

    final score = correctAnswers * 10;
    bool hasSameDailyRecord(
      Map<String, dynamic>? dailyData,
      Map<String, dynamic>? userData,
      String expectedDayKey,
    ) {
      bool sameList(Object? stored, List<String> expected) {
        if (stored is! List || stored.length != expected.length) return false;
        for (var index = 0; index < expected.length; index++) {
          if (stored[index] != expected[index]) return false;
        }
        return true;
      }

      final progress = userData?['progress'];
      final results =
          progress is Map ? progress['classroomQuestResults'] : null;
      final result = results is Map ? results[classroomQuestId] : null;
      return dailyData != null &&
          dailyData['questId'] == classroomQuestId &&
          dailyData['dayKey'] == expectedDayKey &&
          dailyData['score'] == score &&
          sameList(dailyData['questionIds'], questionIds) &&
          sameList(dailyData['correctAttemptIds'], correctAttemptIds) &&
          result is Map &&
          result['status'] == 'completed' &&
          result['dayKey'] == dailyData['dayKey'] &&
          result['score'] == score &&
          result['completionTimeSeconds'] == dailyData['completionTimeSeconds'];
    }

    var stage = 'resolve authenticated student';
    var documentPath = 'users/{uid}';
    try {
      final uid = _uid();
      final userRef = _users.doc(uid);
      final dayKey = classroomQuestDayKey();
      final dailyRef =
          userRef.collection('classroomQuestDailyCompletions').doc(dayKey);
      documentPath = userRef.path;
      debugPrint(
        'Classroom Quest completion save: document=$documentPath, '
        'correctAnswers=$correctAnswers, totalQuestions=$totalQuestions, '
        'score=$score, completionTimeSeconds=$completionTimeSeconds.',
      );
      stage = 'read existing completion and progress';
      try {
        await FirebaseFirestore.instance
            .runTransaction<void>((transaction) async {
          final snapshot = await transaction.get(userRef);
          final dailySnapshot = await transaction.get(dailyRef);
          if (!snapshot.exists) {
            throw StateError('The user progress document does not exist.');
          }
          final data = snapshot.data() ?? {};
          final progress = data['progress'] as Map<String, dynamic>? ?? {};
          if (dailySnapshot.exists) {
            if (hasSameDailyRecord(dailySnapshot.data(), data, dayKey)) return;
            throw StateError(
              'Today\'s Classroom Quest has already been completed.',
            );
          }
          final results = Map<String, dynamic>.from(
              progress['classroomQuestResults'] as Map? ?? {});
          final previousResult = results[classroomQuestId];
          final previousCompletedAt =
              previousResult is Map ? previousResult['completedAt'] : null;
          if (previousCompletedAt is Timestamp &&
              classroomQuestDayKey(previousCompletedAt.toDate()) == dayKey) {
            return;
          }
          final completionHistory = Map<String, dynamic>.from(
            progress['classroomQuestHistory'] as Map? ?? {},
          );
          final completionId =
              userRef.collection('classroomQuestAttempts').doc().id;

          final completionTimes = Map<String, dynamic>.from(
            progress['classroomQuestCompletionTimes'] as Map? ?? {},
          )..[classroomQuestId] = completionTimeSeconds;
          final completion = {
            'type': 'completion',
            'completionTimeSeconds': completionTimeSeconds,
            'score': score,
            'correctAnswers': correctAnswers,
            'totalQuestions': totalQuestions,
            'dayKey': dayKey,
            'completedAt': FieldValue.serverTimestamp(),
          };
          completionHistory[completionId] = completion;
          results[classroomQuestId] = {
            'status': 'completed',
            'completionTimeSeconds': completionTimeSeconds,
            'score': score,
            'correctAnswers': correctAnswers,
            'totalQuestions': totalQuestions,
            'dayKey': dayKey,
            'completedAt': FieldValue.serverTimestamp(),
          };
          stage = 'write completion result, timestamp, and history';
          transaction.update(userRef, {
            'progress.classroomQuestCompletionTimes': completionTimes,
            'progress.classroomQuestResults': results,
            'progress.classroomQuestHistory': completionHistory,
            'progress.latestClassroomQuestHistoryId': completionId,
          });
          transaction.set(dailyRef, {
            'uid': uid,
            'questId': classroomQuestId,
            'dayKey': dayKey,
            'completionId': completionId,
            'questionIds': questionIds,
            'correctAttemptIds': correctAttemptIds,
            'completionTimeSeconds': completionTimeSeconds,
            'correctAnswers': correctAnswers,
            'totalQuestions': totalQuestions,
            'score': score,
            'completedAt': FieldValue.serverTimestamp(),
          });
          stage = 'commit Classroom Quest completion transaction';
        });
      } on FirebaseException catch (error, stackTrace) {
        if (error.code == 'permission-denied') {
          DocumentSnapshot<Map<String, dynamic>> confirmedDaily;
          DocumentSnapshot<Map<String, dynamic>> confirmedUser;
          try {
            confirmedDaily =
                await dailyRef.get(const GetOptions(source: Source.server));
            confirmedUser =
                await userRef.get(const GetOptions(source: Source.server));
          } on FirebaseException catch (verificationError, verificationStack) {
            debugPrint(
              'Unable to verify Classroom Quest completion after '
              'permission-denied: ${verificationError.code}.',
            );
            debugPrintStack(stackTrace: verificationStack);
            Error.throwWithStackTrace(error, stackTrace);
          }
          if (hasSameDailyRecord(
            confirmedDaily.data(),
            confirmedUser.data(),
            dayKey,
          )) {
            debugPrint(
              'Classroom Quest completion already committed by a concurrent '
              'request for the same attempt.',
            );
            _invalidateCurrentProgressCache();
            return;
          }
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
      debugPrint('Classroom Quest completion save: transaction committed.');
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Classroom Quest completion save failed during "$stage": '
        'document=$documentPath, plugin=${error.plugin}, '
        'code=${error.code}, message=${error.message}, '
        'correctAnswers=$correctAnswers, totalQuestions=$totalQuestions, '
        'score=$score, completionTimeSeconds=$completionTimeSeconds.',
      );
      debugPrintStack(stackTrace: stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    } catch (error, stackTrace) {
      debugPrint(
        'Classroom Quest completion save failed during "$stage": '
        'document=$documentPath, exceptionType=${error.runtimeType}, '
        'message=$error.',
      );
      debugPrintStack(stackTrace: stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
    _invalidateCurrentProgressCache();
  }
}
