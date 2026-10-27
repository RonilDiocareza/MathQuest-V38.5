import 'dart:async';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/user_progress_service.dart';
import '../services/verified_display_cache.dart';
import '../widgets/connectivity_status_indicator.dart';
import '../widgets/custom_button.dart';
import '../widgets/math_background.dart';

class BadgeInfo {
  final String id;
  final String title;
  final String description;
  final String lockedHint;
  final IconData icon;
  final Color color;
  final int target;
  final int Function(BadgeProgress) value;
  final bool Function(BadgeProgress) unlockCondition;

  const BadgeInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.lockedHint,
    required this.icon,
    required this.color,
    required this.target,
    required this.value,
    required this.unlockCondition,
  });
}

class BadgeProgress {
  final int completedLevels;
  final int unlockedLevels;
  final int questAttempts;
  final int npcQuestionsAnswered;
  final int npcRoundsCompleted;

  const BadgeProgress({
    required this.completedLevels,
    required this.unlockedLevels,
    required this.questAttempts,
    required this.npcQuestionsAnswered,
    required this.npcRoundsCompleted,
  });

  factory BadgeProgress.fromUserProgress(UserProgress progress) =>
      BadgeProgress(
        completedLevels: progress.completedCount,
        unlockedLevels: progress.unlockedLevels,
        questAttempts: progress.questAttempts,
        npcQuestionsAnswered: progress.completedNpcQuestionCount,
        npcRoundsCompleted: progress.completedNpcRoundCount,
      );
}

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  late BadgeProgress _progress;
  bool _hasProgress = false;
  bool _stale = false;
  bool _needsAuthorizationRefresh = false;
  bool _wasCacheSnapshot = false;
  bool _checkingReachability = false;
  bool _initializing = false;
  Timer? _initialLoadTimer;
  int _request = 0;
  String? _uid;
  String? _sessionKey;
  StreamSubscription<(UserProgress, bool)>? _progressSubscription;
  StreamSubscription<void>? _sessionInvalidationSubscription;
  StreamSubscription<User?>? _authStateSubscription;

  static const List<BadgeInfo> _badges = [
    BadgeInfo(
      id: 'first_victory',
      title: 'First Victory',
      description: 'Complete your first math quiz stage.',
      lockedHint: 'Finish one quiz stage to earn this badge.',
      icon: Icons.flag_rounded,
      color: Color(0xFF19A7A1),
      target: 1,
      value: _completedLevels,
      unlockCondition: _completedAtLeastOneLevel,
    ),
    BadgeInfo(
      id: 'quiz_scout',
      title: 'Quiz Scout',
      description: 'Complete five math quiz stages.',
      lockedHint: 'Complete five quiz stages.',
      icon: Icons.quiz_rounded,
      color: Color(0xFF5188F5),
      target: 5,
      value: _completedLevels,
      unlockCondition: _completedFiveLevels,
    ),
    BadgeInfo(
      id: 'chapter_scholar',
      title: 'Quiz Scholar',
      description: 'Complete 20 math quiz stages.',
      lockedHint: 'Complete 20 quiz stages.',
      icon: Icons.auto_stories_rounded,
      color: Color(0xFF8A63D2),
      target: 20,
      value: _completedLevels,
      unlockCondition: _completedTwentyLevels,
    ),
    BadgeInfo(
      id: 'quest_starter',
      title: 'Quest Starter',
      description: 'Take part in your first Classroom Quest.',
      lockedHint: 'Submit an answer in a Classroom Quest.',
      icon: Icons.explore_rounded,
      color: Color(0xFFEF8C3A),
      target: 1,
      value: _questAttempts,
      unlockCondition: _attemptedAQuest,
    ),
    BadgeInfo(
      id: 'quest_regular',
      title: 'Quest Regular',
      description: 'Build your skills with 10 quest answers.',
      lockedHint: 'Submit 10 answers in Classroom Quests.',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFE65F56),
      target: 10,
      value: _questAttempts,
      unlockCondition: _attemptedTenQuests,
    ),
    BadgeInfo(
      id: 'npc_helper',
      title: 'NPC Helper',
      description: 'Answer all six characters in one game round.',
      lockedHint: 'Answer all six NPC questions in one stage.',
      icon: Icons.forum_rounded,
      color: Color(0xFF2BAA78),
      target: 1,
      value: _npcRounds,
      unlockCondition: _completedNpcRound,
    ),
    BadgeInfo(
      id: 'question_keeper',
      title: 'Question Keeper',
      description: 'Correctly answer 30 character questions.',
      lockedHint: 'Answer 30 NPC questions across your game rounds.',
      icon: Icons.psychology_alt_rounded,
      color: Color(0xFF26A6C8),
      target: 30,
      value: _npcQuestions,
      unlockCondition: _answeredThirtyNpcQuestions,
    ),
    BadgeInfo(
      id: 'chapter_unlocked',
      title: 'New Horizons',
      description: 'Unlock the next chapter in your math journey.',
      lockedHint: 'Complete the final stage of a chapter.',
      icon: Icons.rocket_launch_rounded,
      color: Color(0xFFFFB52E),
      target: 2,
      value: _unlockedChapters,
      unlockCondition: _unlockedNextChapter,
    ),
    BadgeInfo(
      id: 'well_rounded',
      title: 'Well Rounded',
      description: 'Try a quest, finish a quiz stage, and help an NPC.',
      lockedHint:
          'Complete one quiz stage, answer one quest question, and finish one NPC round.',
      icon: Icons.workspace_premium_rounded,
      color: Color(0xFFD66BA0),
      target: 3,
      value: _wellRoundedMilestones,
      unlockCondition: _completedAllMilestones,
    ),
  ];

  static int _completedLevels(BadgeProgress progress) =>
      progress.completedLevels;
  static int _questAttempts(BadgeProgress progress) => progress.questAttempts;
  static int _npcRounds(BadgeProgress progress) => progress.npcRoundsCompleted;
  static int _npcQuestions(BadgeProgress progress) =>
      progress.npcQuestionsAnswered;
  static int _unlockedChapters(BadgeProgress progress) =>
      progress.unlockedLevels;

  static int _wellRoundedMilestones(BadgeProgress progress) =>
      (progress.completedLevels > 0 ? 1 : 0) +
      (progress.questAttempts > 0 ? 1 : 0) +
      (progress.npcRoundsCompleted > 0 ? 1 : 0);

  static bool _completedAtLeastOneLevel(BadgeProgress progress) =>
      progress.completedLevels >= 1;
  static bool _completedFiveLevels(BadgeProgress progress) =>
      progress.completedLevels >= 5;
  static bool _completedTwentyLevels(BadgeProgress progress) =>
      progress.completedLevels >= 20;
  static bool _attemptedAQuest(BadgeProgress progress) =>
      progress.questAttempts >= 1;
  static bool _attemptedTenQuests(BadgeProgress progress) =>
      progress.questAttempts >= 10;
  static bool _completedNpcRound(BadgeProgress progress) =>
      progress.npcRoundsCompleted >= 1;
  static bool _answeredThirtyNpcQuestions(BadgeProgress progress) =>
      progress.npcQuestionsAnswered >= 30;
  static bool _unlockedNextChapter(BadgeProgress progress) =>
      progress.unlockedLevels >= 2;
  static bool _completedAllMilestones(BadgeProgress progress) =>
      _wellRoundedMilestones(progress) >= 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionInvalidationSubscription =
        AuthService.sessionInvalidations.listen((_) {
      _clearPrivateProgress();
    });
    try {
      _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen(
        (user) {
          if (_uid != null && user?.uid != _uid) _clearPrivateProgress();
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Unable to observe badge-screen auth changes: $error');
          debugPrintStack(stackTrace: stackTrace);
          _clearPrivateProgress();
        },
      );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('Unable to start badge-screen auth listener: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    _watchBadgeProgress();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _watchBadgeProgress();
  }

  void _watchBadgeProgress() {
    if (_initializing) return;
    final request = ++_request;
    _initializing = true;
    _initialLoadTimer?.cancel();
    unawaited(_progressSubscription?.cancel());
    if (mounted) {
      setState(() {
        _loading = !_hasProgress;
        _stale = _hasProgress;
      });
    }
    unawaited(_initializeBadgeProgress(request));
  }

  Future<void> _initializeBadgeProgress(int request) async {
    try {
      final session = await VerifiedDisplayCache.verifyCurrentSession();
      if (!mounted || request != _request) return;
      if (session == null) {
        setState(() {
          _uid = null;
          _sessionKey = null;
          _hasProgress = false;
          _loading = false;
        });
        return;
      }

      final cached = VerifiedDisplayCache.get<BadgeProgress>(
        session.uid,
        session.sessionKey,
        'my-progress-badges',
      );
      _uid = session.uid;
      _sessionKey = session.sessionKey;
      _needsAuthorizationRefresh = session.authorization ==
          DisplayAuthorizationResult.temporarilyUnavailable;
      _wasCacheSnapshot = false;
      if (cached != null) {
        _progress = cached;
        _hasProgress = true;
      }
      if (mounted) {
        setState(() {
          _loading = cached == null &&
              session.authorization == DisplayAuthorizationResult.authorized;
          _stale = cached != null;
        });
      }

      await _progressSubscription?.cancel();
      if (!mounted || request != _request) return;
      _progressSubscription =
          UserProgressService.watchCurrentUserProgressWithSource().listen(
        (snapshot) {
          if (snapshot.$2) {
            if (!_wasCacheSnapshot &&
                VerifiedDisplayCache.currentReachability ==
                    FirebaseReachability.online) {
              unawaited(_checkServerReachability(request));
            }
            _wasCacheSnapshot = true;
            return;
          }
          _wasCacheSnapshot = false;
          unawaited(_acceptServerProgress(snapshot.$1, request));
        },
        onError: (Object error, StackTrace stackTrace) {
          _handleProgressError(error, stackTrace, request);
        },
      );
      if (cached == null &&
          session.authorization == DisplayAuthorizationResult.authorized) {
        _initialLoadTimer = Timer(const Duration(seconds: 10), () {
          if (!mounted || request != _request || _hasProgress) return;
          setState(() => _loading = false);
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to load My Progress: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _stale = _hasProgress;
      });
      if (_isTemporaryFailure(error) && _uid != null && _sessionKey != null) {
        VerifiedDisplayCache.setReachability(
          _uid!,
          _sessionKey!,
          FirebaseReachability.unavailable,
        );
      } else {
        _clearPrivateProgress();
      }
    } finally {
      _initializing = false;
    }
  }

  Future<void> _checkServerReachability(int request) async {
    if (_checkingReachability || request != _request) return;
    _checkingReachability = true;
    try {
      final session = await VerifiedDisplayCache.verifyCurrentSession();
      if (!mounted || request != _request) return;
      final uid = _uid;
      final sessionKey = _sessionKey;
      if (session == null ||
          session.uid != uid ||
          session.sessionKey != sessionKey) {
        _clearPrivateProgress();
        return;
      }
      if (session.authorization ==
          DisplayAuthorizationResult.temporarilyUnavailable) {
        _needsAuthorizationRefresh = true;
        setState(() {
          _stale = _hasProgress;
          _loading = false;
        });
      } else {
        _needsAuthorizationRefresh = false;
        setState(() => _stale = false);
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to verify Firebase reachability for progress: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (_isAuthorizationFailure(error)) {
        AuthService.invalidateCurrentVerifiedSession();
        _clearPrivateProgress();
        return;
      }
      if (!_isTemporaryFailure(error)) {
        _clearPrivateProgress();
        return;
      }
      if (mounted &&
          request == _request &&
          _uid != null &&
          _sessionKey != null) {
        VerifiedDisplayCache.setReachability(
          _uid!,
          _sessionKey!,
          FirebaseReachability.unavailable,
        );
        setState(() {
          _needsAuthorizationRefresh = true;
          _stale = _hasProgress;
          _loading = false;
        });
      }
    } finally {
      _checkingReachability = false;
    }
  }

  Future<void> _acceptServerProgress(UserProgress progress, int request) async {
    final uid = _uid;
    final sessionKey = _sessionKey;
    if (uid == null || sessionKey == null || request != _request) return;

    if (_needsAuthorizationRefresh) {
      final session = await VerifiedDisplayCache.verifyCurrentSession();
      if (!mounted || request != _request) return;
      if (session == null ||
          session.uid != uid ||
          session.sessionKey != sessionKey) {
        _clearPrivateProgress();
        return;
      }
      if (session.authorization != DisplayAuthorizationResult.authorized) {
        setState(() {
          _loading = false;
          _stale = _hasProgress;
        });
        return;
      }
      _needsAuthorizationRefresh = false;
    }

    final displayProgress = BadgeProgress.fromUserProgress(progress);
    await VerifiedDisplayCache.putForVerifiedSession(
      uid,
      sessionKey,
      'my-progress-badges',
      displayProgress,
    );
    if (!mounted ||
        request != _request ||
        AuthService.currentUser?.uid != uid ||
        await AuthService.currentVerifiedSessionCacheKey() != sessionKey) {
      return;
    }
    VerifiedDisplayCache.setReachability(
      uid,
      sessionKey,
      FirebaseReachability.online,
    );
    setState(() {
      _initialLoadTimer?.cancel();
      _wasCacheSnapshot = false;
      _progress = displayProgress;
      _hasProgress = true;
      _loading = false;
      _stale = false;
    });
  }

  void _handleProgressError(
    Object error,
    StackTrace stackTrace,
    int request,
  ) {
    debugPrint('Unable to watch My Progress updates: $error');
    debugPrintStack(stackTrace: stackTrace);
    if (!mounted || request != _request) return;
    if (_isAuthorizationFailure(error)) {
      AuthService.invalidateCurrentVerifiedSession();
      _clearPrivateProgress();
      return;
    }
    if (_isTemporaryFailure(error) && _uid != null && _sessionKey != null) {
      VerifiedDisplayCache.setReachability(
        _uid!,
        _sessionKey!,
        FirebaseReachability.unavailable,
      );
      _needsAuthorizationRefresh = true;
      setState(() {
        _loading = false;
        _stale = _hasProgress;
      });
      return;
    }
    setState(() {
      _loading = false;
      _stale = _hasProgress;
    });
  }

  bool _isTemporaryFailure(Object error) =>
      error is TimeoutException ||
      error is FirebaseException &&
          const {
            'deadline-exceeded',
            'network-request-failed',
            'unavailable',
          }.contains(error.code);

  bool _isAuthorizationFailure(Object error) =>
      error is FirebaseException &&
      const {'permission-denied', 'unauthenticated'}.contains(error.code);

  void _clearPrivateProgress() {
    _request++;
    _initialLoadTimer?.cancel();
    _wasCacheSnapshot = false;
    _checkingReachability = false;
    unawaited(_progressSubscription?.cancel());
    _progressSubscription = null;
    if (!mounted) return;
    setState(() {
      _uid = null;
      _sessionKey = null;
      _hasProgress = false;
      _loading = false;
      _stale = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _request++;
    _initialLoadTimer?.cancel();
    unawaited(_progressSubscription?.cancel());
    unawaited(_sessionInvalidationSubscription?.cancel());
    unawaited(_authStateSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unlockedCount = _loading || !_hasProgress
        ? 0
        : _badges.where((badge) => badge.unlockCondition(_progress)).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFD09F5C),
        foregroundColor: const Color(0xFF24344B),
        automaticallyImplyLeading: false,
        leading: const SizedBox(width: 56),
        title: const Text(
          'Badge Hall',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: MathBackground(
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                child: Container(color: Colors.transparent),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const ConnectivityStatusIndicator(),
                  if (_stale && _hasProgress) _buildCachedLabel(),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : !_hasProgress
                            ? _buildErrorState()
                            : _buildCollection(unlockedCount),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomButton(
              text: 'Back',
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildCachedLabel() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Saved progress may be outdated',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );

  Widget _buildErrorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  color: Colors.white70, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Could not load your badge progress.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 17),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _watchBadgeProgress,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );

  Widget _buildCollection(int unlockedCount) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 760 ? 3 : 2;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                sliver: SliverToBoxAdapter(
                  child: _buildCollectionHeader(unlockedCount),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildBadgeCard(_badges[index]),
                    childCount: _badges.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: columns == 3
                        ? 0.95
                        : constraints.maxWidth >= 500
                            ? 0.78
                            : 0.62,
                  ),
                ),
              ),
            ],
          );
        },
      );

  Widget _buildCollectionHeader(int unlockedCount) {
    final completion = unlockedCount / _badges.length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF263F60), Color(0xFF172C48)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD36A).withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFFFD36A),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MathQuest Achievements',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Quests, quizzes, and character questions',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '$unlockedCount/${_badges.length}',
                style: const TextStyle(
                  color: Color(0xFFFFD36A),
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: completion,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFFFD36A)),
            ),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statChip(Icons.check_circle_rounded,
                  '${_progress.completedLevels} quiz stages'),
              _statChip(Icons.forum_rounded,
                  '${_progress.npcQuestionsAnswered} NPC answers'),
              _statChip(Icons.explore_rounded,
                  '${_progress.questAttempts} quest answers'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFFD36A), size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  Widget _buildBadgeCard(BadgeInfo badge) {
    final unlocked = badge.unlockCondition(_progress);
    final current = badge.value(_progress).clamp(0, badge.target);
    final fraction = badge.target == 0 ? 1.0 : current / badge.target;
    return Semantics(
      label:
          '${badge.title}, ${unlocked ? 'unlocked' : 'locked'}, ${unlocked ? badge.description : badge.lockedHint}',
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: unlocked
                ? [Colors.white, const Color(0xFFF2F6FC)]
                : [const Color(0xFFE5EAF0), const Color(0xFFD5DDE7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                unlocked ? badge.color.withValues(alpha: 0.35) : Colors.white,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _medalIcon(badge, unlocked),
                const Spacer(),
                Icon(
                  unlocked ? Icons.verified_rounded : Icons.lock_rounded,
                  color: unlocked ? const Color(0xFF21966B) : Colors.blueGrey,
                  size: 19,
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              badge.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF24344B),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                unlocked ? badge.description : badge.lockedHint,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF536276),
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: fraction.toDouble(),
                      minHeight: 6,
                      backgroundColor: const Color(0xFFDCE3EA),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        unlocked ? const Color(0xFF28A779) : badge.color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  '$current/${badge.target}',
                  style: const TextStyle(
                    color: Color(0xFF536276),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              unlocked ? 'Earned' : 'In Progress',
              style: TextStyle(
                color: unlocked
                    ? const Color(0xFF16835D)
                    : const Color(0xFF607086),
                fontSize: 9,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _medalIcon(BadgeInfo badge, bool unlocked) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: unlocked
                ? [badge.color, badge.color.withValues(alpha: 0.72)]
                : [const Color(0xFF9BA7B4), const Color(0xFF7F8C9B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: unlocked
              ? [
                  BoxShadow(
                    color: badge.color.withValues(alpha: 0.26),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Icon(
          unlocked ? badge.icon : Icons.lock_rounded,
          color: Colors.white,
          size: 25,
        ),
      );
}
