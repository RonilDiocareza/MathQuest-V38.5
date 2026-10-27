import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/teacher_analytics_service.dart';
import '../widgets/game_mode_answer_history_entry.dart';
import '../services/profile_service.dart';
import '../services/user_progress_service.dart';
import '../utils/display_text.dart';
import '../widgets/custom_button.dart';
import '../widgets/math_background.dart';
import '../widgets/teacher_profile_avatar.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

class TeacherAnalyticsScreen extends StatefulWidget {
  const TeacherAnalyticsScreen({
    super.key,
    this.isTeacherDashboard = false,
  });

  final bool isTeacherDashboard;

  @override
  State<TeacherAnalyticsScreen> createState() => _TeacherAnalyticsScreenState();
}

class _TeacherAnalyticsScreenState extends State<TeacherAnalyticsScreen>
    with WidgetsBindingObserver {
  List<StudentAnalytics> students = [];
  bool _isLoading = true;
  String? _loadError;
  bool _requestInProgress = false;
  bool _isProfileDialogOpen = false;
  StreamSubscription<List<StudentAnalytics>>? _analyticsSubscription;
  StreamSubscription<List<ClassroomQuestAttempt>>? _attemptHistorySubscription;
  StreamSubscription<int>? _attemptCountSubscription;
  StreamSubscription<UserProgress>? _progressSubscription;
  StreamSubscription<List<GameModeAnswerAttempt>>? _gameModeAttemptSubscription;
  StreamSubscription<User?>? _authStateSubscription;
  List<ClassroomQuestAttempt> _classroomQuestAttempts = [];
  List<GameModeAnswerAttempt> _gameModeAnswerAttempts = [];
  String? _gameModeHistoryUid;
  UserProgress? _currentUserProgress;
  Map<String, String>? _teacherProfileData;
  Uint8List? _teacherProfilePhoto;
  bool _isAttemptHistoryLoading = true;
  String? _attemptHistoryError;
  bool _isGameModeHistoryLoading = true;
  String? _gameModeHistoryError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!widget.isTeacherDashboard) {
      _gameModeHistoryUid = FirebaseAuth.instance.currentUser?.uid;
      _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen(
        _handleGameModeHistoryAuthChange,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint(
              'Unable to observe Game Mode history account changes: $error');
          debugPrintStack(stackTrace: stackTrace);
          if (!mounted) return;
          setState(() {
            _gameModeAnswerAttempts = [];
            _isGameModeHistoryLoading = false;
            _gameModeHistoryError =
                'Could not verify the signed-in account. Sign in again and retry.';
          });
        },
      );
    }
    _loadAnalytics();
    if (widget.isTeacherDashboard) {
      unawaited(_loadTeacherProfile());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isTeacherDashboard) {
      unawaited(_loadAnalytics(showLoading: false));
      unawaited(_loadTeacherProfile());
    }
  }

  Future<void> _loadAnalytics({bool showLoading = true}) async {
    if (widget.isTeacherDashboard) {
      await _watchTeacherAnalytics(showLoading: showLoading);
      return;
    }
    if (_requestInProgress) return;
    _requestInProgress = true;
    if (mounted) {
      setState(() {
        _loadError = null;
        if (showLoading && students.isEmpty) _isLoading = true;
      });
    }
    try {
      final progressFuture = UserProgressService.getCurrentUserProgress();
      final preferencesFuture = SharedPreferences.getInstance();
      final progress = await progressFuture;
      final prefs = await preferencesFuture;
      if (!mounted) return;
      _currentUserProgress = progress;
      _watchCurrentUserProgress();
      final studentName = prefs.getString('current_user_name') ??
          prefs.getString('user_name') ??
          'Student 1';

      const totalLevels = 60;
      final levelProgress = (progress.completedCount / totalLevels) * 100;

      setState(() {
        students = [
          StudentAnalytics(
            name: studentName,
            levelProgress: levelProgress.toStringAsFixed(1),
            questAttempts: progress.questAttempts,
            classroomQuestCompletionTimeSeconds:
                progress.classroomQuestCompletionTimes[
                    UserProgressService.classroomQuestId],
            levelsCompleted: progress.completedCount,
            totalLevels: totalLevels,
          ),
        ];
      });
      await _watchClassroomQuestAttempts();
      await _watchGameModeAnswerAttempts();
    } catch (error, stackTrace) {
      debugPrint(
        'Unable to load progress (${error is FirebaseException ? error.code : error.runtimeType}).',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _loadError = _analyticsErrorMessage(error);
        });
      }
    } finally {
      _requestInProgress = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _watchClassroomQuestAttempts() async {
    await _attemptHistorySubscription?.cancel();
    if (mounted) {
      setState(() {
        _isAttemptHistoryLoading = true;
        _attemptHistoryError = null;
      });
    }

    _attemptHistorySubscription =
        UserProgressService.watchClassroomQuestAttempts().listen(
      (attempts) {
        if (!mounted) return;
        setState(() {
          _classroomQuestAttempts = attempts;
          _isAttemptHistoryLoading = false;
          _attemptHistoryError = null;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        final code =
            error is FirebaseException ? error.code : error.runtimeType;
        debugPrint(
          'Unable to watch Classroom Quest history ($code) at '
          'users/{uid}/classroomQuestAttempts.',
        );
        debugPrintStack(stackTrace: stackTrace);
        if (!mounted) return;
        setState(() {
          _isAttemptHistoryLoading = false;
          _attemptHistoryError = _analyticsErrorMessage(error);
        });
      },
    );
    await _attemptCountSubscription?.cancel();
    _attemptCountSubscription =
        UserProgressService.watchClassroomQuestAttemptCount().listen(
      (count) {
        if (!mounted || widget.isTeacherDashboard || students.length != 1) {
          return;
        }
        setState(() {
          students = [students.single.copyWith(questAttempts: count)];
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        final code =
            error is FirebaseException ? error.code : error.runtimeType;
        debugPrint(
          'Unable to watch Classroom Quest count ($code) at '
          'users/{uid}.progress.questAttempts.',
        );
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  void _watchCurrentUserProgress() {
    unawaited(_progressSubscription?.cancel());
    _progressSubscription =
        UserProgressService.watchCurrentUserProgress().listen(
      (progress) {
        if (!mounted) return;
        setState(() => _currentUserProgress = progress);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Unable to watch My Progress updates: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  Future<void> _watchGameModeAnswerAttempts() async {
    await _bindGameModeAnswerAttempts(
      FirebaseAuth.instance.currentUser?.uid,
    );
  }

  void _handleGameModeHistoryAuthChange(User? user) {
    final uid = user?.uid;
    if (uid == _gameModeHistoryUid) return;
    _gameModeHistoryUid = uid;
    if (mounted) {
      setState(() {
        _gameModeAnswerAttempts = [];
        _isGameModeHistoryLoading = uid != null;
        _gameModeHistoryError = null;
      });
    }
    unawaited(_bindGameModeAnswerAttempts(uid));
  }

  Future<void> _bindGameModeAnswerAttempts(String? uid) async {
    if (mounted) {
      setState(() {
        _isGameModeHistoryLoading = uid != null;
        _gameModeHistoryError = null;
      });
    }
    await _gameModeAttemptSubscription?.cancel();
    if (!mounted || uid != FirebaseAuth.instance.currentUser?.uid) return;
    if (uid == null) return;

    try {
      _gameModeAttemptSubscription =
          UserProgressService.watchGameModeAnswerAttempts(uid: uid).listen(
        (attempts) {
          if (!_isCurrentGameModeHistoryUser(uid)) return;
          setState(() {
            _gameModeAnswerAttempts = attempts;
            _isGameModeHistoryLoading = false;
            _gameModeHistoryError = null;
          });
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!_isCurrentGameModeHistoryUser(uid)) return;
          debugPrint('Unable to watch Game Mode answer history: $error');
          debugPrintStack(stackTrace: stackTrace);
          if (!mounted) return;
          setState(() {
            _isGameModeHistoryLoading = false;
            _gameModeHistoryError = _analyticsErrorMessage(error);
          });
        },
      );
    } catch (error, stackTrace) {
      if (!_isCurrentGameModeHistoryUser(uid)) return;
      debugPrint('Unable to watch Game Mode answer history: $error');
      debugPrintStack(stackTrace: stackTrace);
      setState(() {
        _isGameModeHistoryLoading = false;
        _gameModeHistoryError = _analyticsErrorMessage(error);
      });
    }
  }

  bool _isCurrentGameModeHistoryUser(String uid) =>
      mounted &&
      uid == _gameModeHistoryUid &&
      uid == FirebaseAuth.instance.currentUser?.uid;

  Future<void> _loadTeacherProfile() async {
    try {
      final profileService = ProfileService();
      final profile = await profileService.loadProfile();
      Uint8List? photo;
      try {
        photo = await profileService.getProfilePhoto(
          profilePhotoUrl: profile['profilePhotoUrl'],
        );
      } catch (error, stackTrace) {
        debugPrint('Unable to load teacher profile photo: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted) return;
      setState(() {
        _teacherProfileData = profile;
        _teacherProfilePhoto = photo;
      });
    } catch (error, stackTrace) {
      debugPrint('Unable to load teacher profile details: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _watchTeacherAnalytics({required bool showLoading}) async {
    if (_requestInProgress) return;
    _requestInProgress = true;
    if (mounted) {
      setState(() {
        _loadError = null;
        if (showLoading && students.isEmpty) _isLoading = true;
      });
    }
    try {
      await _analyticsSubscription?.cancel();
      _analyticsSubscription = TeacherAnalyticsService.watchStudents().listen(
        (loadedStudents) {
          if (!mounted) return;
          setState(() {
            students = loadedStudents;
            _isLoading = false;
            _loadError = null;
          });
        },
        onError: (Object error, StackTrace stackTrace) {
          _reportTeacherAnalyticsError(error, stackTrace);
        },
      );
    } catch (error, stackTrace) {
      _reportTeacherAnalyticsError(error, stackTrace);
    } finally {
      _requestInProgress = false;
      if (mounted) setState(() {});
    }
  }

  void _reportTeacherAnalyticsError(Object error, StackTrace stackTrace) {
    final code = error is FirebaseException ? error.code : error.runtimeType;
    debugPrint(
      'Unable to watch student progress ($code) at '
      'users where role == student.',
    );
    debugPrintStack(stackTrace: stackTrace);
    if (mounted) {
      setState(() {
        _loadError = _analyticsErrorMessage(error);
        _isLoading = false;
      });
    }
  }

  String _analyticsErrorMessage(Object error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Firestore denied access. Verify that this account has an approved teacher role and an active session, then check the deployed Firestore rules.',
        'unauthenticated' =>
          'Your sign-in session expired. Sign in again to view student progress.',
        'unavailable' ||
        'deadline-exceeded' =>
          'Firebase is temporarily unavailable. Check your connection and retry.',
        _ =>
          'Could not load student progress (${error.code}). Retry or contact an administrator.',
      };
    }
    return 'Could not load student progress. Check your connection and account access, then retry.';
  }

  void _openTeacherProfileOptions() {
    if (_isProfileDialogOpen) return;
    _isProfileDialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 32,
        ),
        child: ProfileScreen(
          isDialog: true,
          initialProfile: _teacherProfileData,
          initialProfilePhoto: _teacherProfilePhoto,
          onProfileUpdated: () => unawaited(_loadTeacherProfile()),
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    ).whenComplete(() {
      _isProfileDialogOpen = false;
    });
  }

  void _goBackToHome() {
    final navigator = Navigator.of(context);
    var homeExists = false;

    navigator.popUntil((route) {
      if (route is HomeScreen) {
        homeExists = true;
        return true;
      }
      return false;
    });

    if (!homeExists) {
      navigator.pushAndRemoveUntil(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    unawaited(_analyticsSubscription?.cancel());
    unawaited(_attemptHistorySubscription?.cancel());
    unawaited(_attemptCountSubscription?.cancel());
    unawaited(_progressSubscription?.cancel());
    unawaited(_gameModeAttemptSubscription?.cancel());
    unawaited(_authStateSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MathBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                  child: Container(color: Colors.transparent),
                ),
              ),
              Column(
                children: [
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        if (widget.isTeacherDashboard)
                          IconButton(
                            tooltip: 'Refresh student data',
                            onPressed: _requestInProgress
                                ? null
                                : () => _loadAnalytics(),
                            icon: const Icon(Icons.refresh),
                          ),
                        Expanded(
                          child: Text(
                            widget.isTeacherDashboard
                                ? 'Teacher Dashboard'
                                : 'My Progress',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: ui.Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                        ),
                        if (widget.isTeacherDashboard)
                          GestureDetector(
                            onTap: _openTeacherProfileOptions,
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: TeacherProfileAvatar(
                                gender: _teacherProfileData?['gender'],
                                photoBytes: _teacherProfilePhoto,
                                size: 54,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (_isLoading)
                            const Padding(
                              padding: EdgeInsets.all(28),
                              child: CircularProgressIndicator(),
                            )
                          else if (_loadError != null && students.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Text(
                                    _loadError!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  CustomButton(
                                    text: 'Retry',
                                    onPressed: _loadAnalytics,
                                  ),
                                ],
                              ),
                            )
                          else if (widget.isTeacherDashboard)
                            _buildTeacherDashboardContent()
                          else if (students.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                'No student data available',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 15),
                              child: Column(
                                children:
                                    students.map(_buildStudentCard).followedBy([
                                  _buildGameModeProgressHistory(),
                                  _buildGameModeAnswerHistory(),
                                  _buildClassroomQuestAttemptHistory(),
                                ]).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (!widget.isTeacherDashboard) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _goBackToHome,
                          borderRadius: BorderRadius.circular(12),
                          child: CustomButton(
                            text: 'Back',
                            onPressed: _goBackToHome,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherDashboardContent() {
    final progressRecordCount =
        students.where((student) => student.hasProgressRecord).length;
    final scoredStudents = students.where((student) => student.score != null);
    final totalScore = scoredStudents.fold<int>(
      0,
      (sum, student) => sum + student.score!,
    );
    final completedLevelCount = students.fold<int>(
      0,
      (sum, student) => sum + student.levelsCompleted,
    );
    final activeStudentCount = students
        .where((student) =>
            student.questAttempts > 0 ||
            student.gameModeFinalScores.isNotEmpty ||
            student.completedNpcQuestionCount > 0)
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Live progress updates are unavailable. ${_loadError!}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[800]),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildStatCard(
                title: 'Registered Students',
                value: students.length.toString(),
                color: Colors.blue,
              ),
              _buildStatCard(
                title: 'Progress Records',
                value: progressRecordCount.toString(),
                color: Colors.deepPurple,
              ),
              _buildStatCard(
                title: 'Combined Scores',
                value: students.any((student) => student.score != null)
                    ? '$totalScore (${scoredStudents.length} records)'
                    : 'Not recorded',
                color: Colors.orange,
              ),
              _buildStatCard(
                title: 'Stages Completed',
                value: completedLevelCount.toString(),
                color: Colors.green,
              ),
              _buildStatCard(
                title: 'Active Students',
                value: activeStudentCount.toString(),
                color: Colors.teal,
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            "Students' Progress",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          if (students.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No registered student accounts found.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
            )
          else
            ...students.map(_buildStudentCard),
        ],
      ),
    );
  }

  Widget _buildGameModeProgressHistory() {
    final progress = _currentUserProgress;
    final completedLevels = progress?.completedLevels.toList() ?? <int>[];
    completedLevels.sort();
    final scores = progress?.gameModeFinalScores ?? const <int, int>{};

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1D0AD),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Game Mode Stages and Scores',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          if (progress == null)
            const Center(child: CircularProgressIndicator())
          else if (completedLevels.isEmpty)
            const Text('No completed stages recorded yet.')
          else
            ...completedLevels.map((level) {
              final score = scores[level];
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Stage $level · '
                    '${score == null ? 'No Game Mode score recorded' : 'Final score: $score'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildGameModeAnswerHistory() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1D0AD),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Game Mode Answer History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          if (_isGameModeHistoryLoading)
            const Center(child: CircularProgressIndicator())
          else if (_gameModeHistoryError != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_gameModeHistoryError!),
                TextButton(
                  onPressed: _watchGameModeAnswerAttempts,
                  child: const Text('Retry'),
                ),
              ],
            )
          else if (_gameModeAnswerAttempts.isEmpty)
            const Text('No Game Mode answers recorded yet.')
          else
            ..._gameModeAnswerAttempts.map(
              (attempt) => GameModeAnswerHistoryEntry(attempt: attempt),
            ),
        ],
      ),
    );
  }

  Widget _buildClassroomQuestAttemptHistory() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1D0AD),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Classroom Quest Attempt History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          if (_isAttemptHistoryLoading)
            const Center(child: CircularProgressIndicator())
          else if (_attemptHistoryError != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_attemptHistoryError!),
                TextButton(
                  onPressed: _watchClassroomQuestAttempts,
                  child: const Text('Retry'),
                ),
              ],
            )
          else if (_classroomQuestAttempts.isEmpty)
            const Text('No Classroom Quest attempts recorded yet.')
          else
            ..._classroomQuestAttempts.map((attempt) {
              final attemptedAt = attempt.attemptedAt;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${attempt.questionNumber} · '
                        'Attempt ${attempt.attemptNumber} · '
                        '${displayStatusLabel(attempt.status)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Answer: ${attempt.timedOut ? 'Timed out' : attempt.answer} · '
                        'Score: ${attempt.score} · '
                        'Time: ${attempt.timeSpentSeconds}s',
                      ),
                      Text(
                        attemptedAt == null
                            ? 'Time: Syncing'
                            : 'Time: ${attemptedAt.toLocal()}',
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStudentCard(StudentAnalytics student) {
    double progressPercent = double.parse(student.levelProgress);
    Color progressColor = progressPercent >= 75
        ? Colors.green
        : progressPercent >= 50
            ? Colors.orange
            : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1D0AD),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 30, color: Colors.black87),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${student.name}${student.status.toLowerCase() == 'approved' ? '' : ' (${displayStatusLabel(student.status)})'}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Stage Progress',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '${student.levelProgress}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: progressColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progressPercent / 100,
                    minHeight: 12,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${student.levelsCompleted}/${student.totalLevels} stages completed',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.quiz,
                  size: 30,
                  color: Colors.blue,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Classroom Quest Attempts',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${student.questAttempts} attempt${student.questAttempts != 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Completion time: ${student.classroomQuestCompletionTimeSeconds == null ? 'Not completed' : _formatCompletionTime(student.classroomQuestCompletionTimeSeconds!)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          if (widget.isTeacherDashboard) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Activity Records',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Classroom Quest: ${student.classroomQuestScore == null ? 'No completion recorded' : '${student.classroomQuestCorrectAnswers}/${student.classroomQuestTotalQuestions} correct, ${student.classroomQuestScore} points'}',
                  ),
                  Text(
                    'Game Mode: ${student.gameModeFinalScores.length} completed stage${student.gameModeFinalScores.length == 1 ? '' : 's'}',
                  ),
                  Text(
                    'NPC questions completed: ${student.completedNpcQuestionCount}',
                  ),
                  Text(
                    'Completed Stages: ${student.completedLevelNumbers.isEmpty ? 'None' : student.completedLevelNumbers.join(', ')}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Wrap(
              alignment: WrapAlignment.spaceAround,
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildStatCard(
                  title: 'Score',
                  value: student.score?.toString() ?? 'Not recorded',
                  color: Colors.blue,
                ),
                _buildStatCard(
                  title: 'Status',
                  value: progressPercent >= 75
                      ? 'Excellent'
                      : progressPercent >= 50
                          ? 'Good'
                          : 'Needs Improvement',
                  color: progressColor,
                ),
                _buildStatCard(
                  title: 'Activity',
                  value: student.hasProgressRecord
                      ? (student.questAttempts > 0 ||
                              student.gameModeFinalScores.isNotEmpty ||
                              student.completedNpcQuestionCount > 0
                          ? 'Active'
                          : 'Progress saved')
                      : 'No activity yet',
                  color: student.hasProgressRecord ? Colors.green : Colors.grey,
                ),
              ],
            ),
          ] else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  title: 'Status',
                  value: progressPercent >= 75
                      ? '✓ Excellent'
                      : progressPercent >= 50
                          ? '⚠ Good'
                          : '✗ Needs Improvement',
                  color: progressColor,
                ),
                _buildStatCard(
                  title: 'Activity',
                  value: student.questAttempts > 0 ? '✓ Active' : '✗ Inactive',
                  color: student.questAttempts > 0 ? Colors.green : Colors.grey,
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatCompletionTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  Widget _buildStatCard(
      {required String title, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
