import 'dart:async';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/math_background.dart';
import '../services/auth_service.dart';
import '../services/leaderboard_service.dart';
import '../services/profile_service.dart';
import '../services/tutorial_service.dart';
import '../services/user_progress_service.dart';
import '../services/verified_display_cache.dart';
import '../widgets/first_time_tutorial_overlay.dart';
import 'badges_screen.dart';
import 'story_levels_screen.dart';
import 'classroom_quest_screen.dart';
import 'teacher_analytics_screen.dart';
import 'profile_screen.dart';
import 'modules_screen.dart';
import 'offline_practice_screen.dart';
import 'leaderboard_screen.dart';
import 'landing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.tutorialStatusCheck,
  });

  final Future<bool?> Function()? tutorialStatusCheck;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static int _initializationCount = 0;
  static const Duration _initialTutorialRetryDelay = Duration(seconds: 30);
  static const Duration _maximumTutorialRetryDelay = Duration(minutes: 5);
  late ProfileService _profileService;
  Uint8List? _profilePhoto;
  Map<String, String>? _profileData;
  String _userCharacter = 'boy';
  bool _isDialogOpen = false;
  bool _showFirstTimeTutorial = false;
  bool _checkingTutorial = false;
  bool _tutorialStatusDeferred = false;
  bool _tutorialStatusResolved = false;
  bool _tutorialSessionInvalidated = false;
  int _tutorialRequest = 0;
  Duration _tutorialRetryDelay = _initialTutorialRetryDelay;
  Timer? _tutorialRetryTimer;
  StreamSubscription<void>? _tutorialSessionInvalidationSubscription;
  final GlobalKey _profileTutorialKey = GlobalKey();
  final GlobalKey _moduleTutorialKey = GlobalKey();
  final GlobalKey _levelsTutorialKey = GlobalKey();
  final GlobalKey _classroomTutorialKey = GlobalKey();
  final GlobalKey _progressTutorialKey = GlobalKey();
  final GlobalKey _badgesTutorialKey = GlobalKey();
  final GlobalKey _leaderboardTutorialKey = GlobalKey();
  int? _currentRank;
  bool _currentRankIsStale = false;
  Timer? _rankPopupTimer;
  Timer? _helpPopupTimer;
  int _rankRequest = 0;
  bool _rankLoadInFlight = false;
  bool _showRankPopup = false;
  bool _showHelpPopup = false;
  late final int _initializationId;

  List<FirstTimeTutorialStep> get _tutorialSteps => [
        const FirstTimeTutorialStep(
          title: 'Welcome to MathQuest!',
          message:
              'I’m Teacher Joan, your guide. I’ll show you the main places to explore. Press Next to learn about each one. The highlighted item will not open until you select it.',
        ),
        FirstTimeTutorialStep(
          title: 'Your Profile',
          message:
              'Tap your profile picture to view your account details, update your profile, or log out.',
          targetKey: _profileTutorialKey,
        ),
        FirstTimeTutorialStep(
          title: 'Modules',
          message:
              'Open Modules to explore lessons and practice the math topics available in the game.',
          targetKey: _moduleTutorialKey,
        ),
        FirstTimeTutorialStep(
          title: 'Stages',
          message:
              'Choose Stages to explore the story map, visit question NPCs, and progress through the available stages.',
          targetKey: _levelsTutorialKey,
        ),
        const FirstTimeTutorialStep(
          title: 'Stage Questions & Game Mode',
          message:
              'Answer the problem shown for a stage to unlock its Play Game Mode option. In that mode, move around and collect the number requested by the problem.',
        ),
        const FirstTimeTutorialStep(
          title: 'Score, Health & Game Controls',
          message:
              'During play, the HUD shows your score and health hearts. Correct NPC answers and collected number items each add 10 points. Music toggles the soundtrack, Menu lets you resume or quit, and Back leaves the stage.',
        ),
        FirstTimeTutorialStep(
          title: 'Classroom Quests',
          message:
              'Open Classroom Quests to view and take part in quests assigned for your classroom.',
          targetKey: _classroomTutorialKey,
        ),
        FirstTimeTutorialStep(
          title: 'My Progress',
          message:
              'My Progress shows your learning activity and progress so you can see how far you have come.',
          targetKey: _progressTutorialKey,
          guideAtTop: true,
        ),
        FirstTimeTutorialStep(
          title: 'Badges',
          message:
              'Visit Badges to view the achievements you have earned while playing.',
          targetKey: _badgesTutorialKey,
          guideAtTop: true,
        ),
        FirstTimeTutorialStep(
          title: 'Leaderboard',
          message:
              'The Leaderboard compares players’ scores. Your current rank is also shown near your profile at the top of this screen.',
          targetKey: _leaderboardTutorialKey,
          guideAtTop: true,
        ),
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tutorialSessionInvalidationSubscription =
        AuthService.sessionInvalidations.listen((_) {
      _tutorialRequest++;
      _tutorialRetryTimer?.cancel();
      _tutorialRetryTimer = null;
      _tutorialStatusDeferred = false;
      _tutorialSessionInvalidated = true;
      _rankRequest++;
      _rankPopupTimer?.cancel();
      _rankPopupTimer = null;
      if (mounted) {
        setState(() {
          _currentRank = null;
          _currentRankIsStale = false;
          _showRankPopup = false;
        });
      }
    });
    _initializationId = ++_initializationCount;
    if (kDebugMode) {
      debugPrint('[HomeScreen] Initialization #$_initializationId started.');
    }
    _profileService = ProfileService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showHelpPopupForHomeEntry();
    });
    _checkFirstTimeTutorial();
    _showRankPopupWhenReady();
    _loadProfileData();
    _warmProgressData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _retryDeferredTutorialStatus();
      _showRankPopupWhenReady();
    }
  }

  void _startHelpPopupTimer() {
    _helpPopupTimer?.cancel();
    _helpPopupTimer = Timer(const Duration(seconds: 20), () {
      _helpPopupTimer = null;
      if (mounted) setState(() => _showHelpPopup = false);
    });
  }

  void _showHelpPopupForHomeEntry() {
    if (!mounted) return;
    setState(() => _showHelpPopup = true);
    _startHelpPopupTimer();
  }

  Future<void> _checkFirstTimeTutorial() async {
    final user = AuthService.currentUser;
    final tutorialStatusCheck = widget.tutorialStatusCheck;
    if ((user == null && tutorialStatusCheck == null) ||
        _checkingTutorial ||
        _tutorialStatusResolved ||
        _tutorialSessionInvalidated) {
      return;
    }
    _tutorialRetryTimer?.cancel();
    _tutorialRetryTimer = null;
    _checkingTutorial = true;
    final request = ++_tutorialRequest;
    final timer = Stopwatch()..start();
    try {
      final shouldShow = tutorialStatusCheck != null
          ? await tutorialStatusCheck()
          : await TutorialService.shouldShowFirstTimeTutorial(user!.uid);
      if (!mounted || request != _tutorialRequest) return;
      if (user != null && AuthService.currentUser?.uid != user.uid) return;
      if (shouldShow == null) {
        _tutorialStatusDeferred = true;
        _scheduleTutorialStatusRetry();
        return;
      }

      _tutorialStatusDeferred = false;
      _tutorialStatusResolved = true;
      _tutorialRetryDelay = _initialTutorialRetryDelay;
      if (!_showFirstTimeTutorial) {
        setState(() => _showFirstTimeTutorial = shouldShow);
      }
    } catch (error, stackTrace) {
      if (request != _tutorialRequest) return;
      _tutorialStatusDeferred = false;
      debugPrint('Unable to check first-time tutorial status: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not check the tutorial status.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _checkFirstTimeTutorial,
            ),
          ),
        );
      }
    } finally {
      _checkingTutorial = false;
      if (kDebugMode) {
        debugPrint(
          '[HomeScreen] Tutorial check for initialization '
          '#$_initializationId finished in ${timer.elapsedMilliseconds} ms.',
        );
      }
    }
  }

  void _scheduleTutorialStatusRetry() {
    if (!mounted ||
        !_tutorialStatusDeferred ||
        _tutorialRetryTimer != null ||
        _tutorialSessionInvalidated) {
      return;
    }

    final delay = _tutorialRetryDelay;
    _tutorialRetryDelay = Duration(
      seconds: (_tutorialRetryDelay.inSeconds * 2).clamp(
        _initialTutorialRetryDelay.inSeconds,
        _maximumTutorialRetryDelay.inSeconds,
      ),
    );
    _tutorialRetryTimer = Timer(delay, () {
      _tutorialRetryTimer = null;
      unawaited(_checkFirstTimeTutorial());
    });
  }

  void _retryDeferredTutorialStatus() {
    if (!_tutorialStatusDeferred || _tutorialSessionInvalidated) return;
    _tutorialRetryTimer?.cancel();
    _tutorialRetryTimer = null;
    unawaited(_checkFirstTimeTutorial());
  }

  Future<void> _completeFirstTimeTutorial() async {
    final user = AuthService.currentUser;
    debugPrint(
      '[HomeScreen] Finish pressed: authCurrentUser=${user != null}, '
      'authUid=${user?.uid ?? '(none)'}.',
    );
    debugPrint('[HomeScreen] Awaiting tutorial completion save.');
    await TutorialService.completeFirstTimeTutorial();
    debugPrint('[HomeScreen] Tutorial completion save returned successfully.');
    _tutorialStatusResolved = true;
    _tutorialStatusDeferred = false;
    _tutorialRetryTimer?.cancel();
    _tutorialRetryTimer = null;
    if (!mounted) {
      debugPrint(
        '[HomeScreen] Widget unmounted after save; no route navigation needed.',
      );
      return;
    }
    debugPrint(
      '[HomeScreen] Dismissing instruction overlay; Home remains the active route.',
    );
    setState(() => _showFirstTimeTutorial = false);
  }

  void _showTutorialAgain() {
    if (!mounted || _showFirstTimeTutorial) return;
    setState(() => _showFirstTimeTutorial = true);
  }

  void _onHelpIconTapped() {
    _helpPopupTimer?.cancel();
    _helpPopupTimer = null;
    if (_showHelpPopup) setState(() => _showHelpPopup = false);
    _showTutorialAgain();
  }

  Future<void> _focusTutorialStep(int index) async {
    final step = _tutorialSteps[index];
    final targetKey = step.targetKey;
    final targetContext = targetKey?.currentContext;
    if (targetContext != null) {
      await Scrollable.ensureVisible(
        targetContext,
        alignment: step.guideAtTop ? 0.72 : 0.25,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showRankPopupWhenReady() {
    if (_rankLoadInFlight) return;
    _rankPopupTimer?.cancel();
    final request = ++_rankRequest;
    setState(() {
      _currentRankIsStale = _currentRank != null;
      _showRankPopup = _currentRank != null;
    });
    unawaited(_loadCurrentRank(request));
  }

  Future<void> _loadCurrentRank(int request) async {
    _rankLoadInFlight = true;
    final timer = Stopwatch()..start();
    String? sessionUid;
    String? sessionKey;
    try {
      final session = await VerifiedDisplayCache.verifyCurrentSession();
      if (!mounted || request != _rankRequest || session == null) return;
      sessionUid = session.uid;
      sessionKey = session.sessionKey;
      final cachedEntries = VerifiedDisplayCache.get<List<LeaderboardEntry>>(
        session.uid,
        session.sessionKey,
        'leaderboard',
      );
      final cachedRank = _rankFromEntries(cachedEntries, session.uid);
      if (cachedRank != null && mounted && request == _rankRequest) {
        setState(() {
          _currentRank = cachedRank;
          _currentRankIsStale = true;
          _showRankPopup = true;
        });
      }
      if (session.authorization ==
          DisplayAuthorizationResult.temporarilyUnavailable) {
        return;
      }

      final entries = await LeaderboardService.getEntriesFromServer()
          .timeout(const Duration(seconds: 10));
      if (!mounted ||
          request != _rankRequest ||
          AuthService.currentUser?.uid != session.uid ||
          await AuthService.currentVerifiedSessionCacheKey() !=
              session.sessionKey) {
        return;
      }
      final safeEntries = List<LeaderboardEntry>.unmodifiable(entries);
      await VerifiedDisplayCache.putForVerifiedSession(
        session.uid,
        session.sessionKey,
        'leaderboard',
        safeEntries,
      );
      if (await AuthService.currentVerifiedSessionCacheKey() !=
          session.sessionKey) {
        return;
      }
      final rank = _rankFromEntries(safeEntries, session.uid);
      if (!mounted || request != _rankRequest) return;

      setState(() {
        _currentRank = rank;
        _currentRankIsStale = false;
        _showRankPopup = rank != null;
      });
      if (rank != null) {
        _rankPopupTimer = Timer(const Duration(seconds: 30), () {
          if (!mounted || request != _rankRequest) return;
          setState(() => _showRankPopup = false);
        });
      }
      if (kDebugMode) {
        debugPrint(
          '[HomeScreen] Rank load for initialization '
          '#$_initializationId completed in ${timer.elapsedMilliseconds} ms.',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to retrieve current leaderboard rank: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (error is TimeoutException &&
          sessionUid != null &&
          sessionKey != null) {
        VerifiedDisplayCache.setReachability(
          sessionUid,
          sessionKey,
          FirebaseReachability.unavailable,
        );
      }
      if (error is FirebaseException) {
        if (const {'permission-denied', 'unauthenticated'}
            .contains(error.code)) {
          AuthService.invalidateCurrentVerifiedSession();
        } else if (const {
          'deadline-exceeded',
          'network-request-failed',
          'unavailable',
        }.contains(error.code)) {
          if (sessionUid != null && sessionKey != null) {
            VerifiedDisplayCache.setReachability(
              sessionUid,
              sessionKey,
              FirebaseReachability.unavailable,
            );
          }
        }
      }
    } finally {
      _rankLoadInFlight = false;
      if (kDebugMode) {
        debugPrint(
          '[HomeScreen] Rank request for initialization '
          '#$_initializationId finished in ${timer.elapsedMilliseconds} ms.',
        );
      }
    }
  }

  int? _rankFromEntries(List<LeaderboardEntry>? entries, String uid) {
    if (entries == null) return null;
    final sortedEntries = LeaderboardService.sortEntries(entries);
    final index = sortedEntries.indexWhere((entry) => entry.uid == uid);
    return index < 0 ? null : index + 1;
  }

  void _showCachedRankPopup() {
    final rank = _currentRank;
    if (!mounted || rank == null) return;
    final request = _rankRequest;
    setState(() => _showRankPopup = true);
    _rankPopupTimer?.cancel();
    _rankPopupTimer = Timer(const Duration(seconds: 30), () {
      if (!mounted || request != _rankRequest) return;
      setState(() => _showRankPopup = false);
    });
  }

  void _hideRankPopup() {
    _rankPopupTimer?.cancel();
    _rankPopupTimer = null;
    _rankRequest++;
    if (_showRankPopup) {
      setState(() => _showRankPopup = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tutorialRetryTimer?.cancel();
    unawaited(_tutorialSessionInvalidationSubscription?.cancel());
    _rankPopupTimer?.cancel();
    _helpPopupTimer?.cancel();
    _rankRequest++;
    super.dispose();
  }

  void _openPracticePanel() {
    if (_isDialogOpen) return;
    _isDialogOpen = true;
    _hideRankPopup();
    _helpPopupTimer?.cancel();
    _helpPopupTimer = null;
    if (_showHelpPopup) setState(() => _showHelpPopup = false);

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close Practice Mode',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                key: const ValueKey('practice-modal-backdrop'),
                filter: ui.ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                child: Container(color: Colors.transparent),
              ),
            ),
            SafeArea(
              child: Center(
                child: Dialog(
                  clipBehavior: Clip.antiAlias,
                  insetPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: LayoutBuilder(
                    builder: (context, constraints) => SizedBox(
                      width:
                          constraints.maxWidth.clamp(0.0, 720.0).toDouble(),
                      height:
                          constraints.maxHeight.clamp(0.0, 760.0).toDouble(),
                      child: const OfflinePracticeScreen(isModalPanel: true),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final transition = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: transition,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(transition),
            child: child,
          ),
        );
      },
    ).then((_) {
      _isDialogOpen = false;
      if (!mounted) return;
      _showCachedRankPopup();
      _showHelpPopupForHomeEntry();
      _retryDeferredTutorialStatus();
    });
  }

  Future<void> _warmProgressData() async {
    final timer = Stopwatch()..start();
    try {
      await UserProgressService.preloadCurrentUserProgress();
    } catch (error, stackTrace) {
      debugPrint('Unable to preload home progress data: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (kDebugMode) {
        debugPrint(
          '[HomeScreen] Progress preload for initialization '
          '#$_initializationId finished in ${timer.elapsedMilliseconds} ms.',
        );
      }
    }
  }

  void _openScreen(
    Widget screen, {
    bool refreshRankOnReturn = false,
  }) {
    _hideRankPopup();
    _helpPopupTimer?.cancel();
    _helpPopupTimer = null;
    if (_showHelpPopup) setState(() => _showHelpPopup = false);
    unawaited(
      Navigator.of(context)
          .push(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) => screen,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      )
          .then((_) {
        if (mounted) {
          if (refreshRankOnReturn) {
            _showRankPopupWhenReady();
          } else {
            _showCachedRankPopup();
          }
          _showHelpPopupForHomeEntry();
          _retryDeferredTutorialStatus();
        }
      }),
    );
  }

  Future<void> _loadProfileData() async {
    final timer = Stopwatch()..start();
    try {
      final profile = await _profileService.loadProfile();
      if (!mounted) return;
      setState(() {
        _profileData = profile;
        _userCharacter = profile['character'] == 'girl' ? 'girl' : 'boy';
      });

      Uint8List? photoFile;
      final photoTimer = Stopwatch()..start();
      try {
        photoFile = await _profileService.getProfilePhoto(
          profilePhotoUrl: profile['profilePhotoUrl'],
        );
      } catch (error, stackTrace) {
        debugPrint('Unable to load optional home profile photo: $error');
        debugPrintStack(stackTrace: stackTrace);
      } finally {
        if (kDebugMode) {
          debugPrint(
            '[HomeScreen] Optional profile photo load for initialization '
            '#$_initializationId finished in '
            '${photoTimer.elapsedMilliseconds} ms.',
          );
        }
      }
      if (!mounted) return;
      setState(() => _profilePhoto = photoFile);
    } catch (error, stackTrace) {
      debugPrint('Unable to load optional home profile data: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (kDebugMode) {
        debugPrint(
          '[HomeScreen] Profile load for initialization '
          '#$_initializationId finished in ${timer.elapsedMilliseconds} ms.',
        );
      }
    }
  }

  void _returnToLanding() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LandingScreen(role: 'student'),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MathBackground(
        child: SafeArea(
          child: Stack(
            children: [
              _buildHomeContent(context),
              Positioned(
                top: 56,
                left: 16,
                right: 16,
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      Material(
                        color: const Color(0xFFFFF3D8),
                        shape: const CircleBorder(
                          side: BorderSide(
                            color: Color(0xFF8F5C2D),
                            width: 1.5,
                          ),
                        ),
                        child: InkWell(
                          key: const ValueKey('home-navigation'),
                          onTap: _returnToLanding,
                          customBorder: const CircleBorder(),
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(
                              Icons.home_rounded,
                              size: 25,
                              color: Color(0xFF5A3620),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Image.asset(
                          'assets/images/Icon/Icon2.png',
                          height: 56,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _openProfileDialog(context),
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
                          key: _profileTutorialKey,
                          child: _profilePhoto != null
                              ? ClipOval(
                                  child: Image.memory(
                                    _profilePhoto!,
                                    fit: BoxFit.cover,
                                    width: 54,
                                    height: 54,
                                  ),
                                )
                              : CircleAvatar(
                                  backgroundColor: const Color(0xFFD09F5C),
                                  child: ClipOval(
                                    child: Image.asset(
                                      _userCharacter == 'girl'
                                          ? 'assets/images/player/girl.png'
                                          : 'assets/images/player/boy.png',
                                      fit: BoxFit.cover,
                                      width: 54,
                                      height: 54,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showRankPopup && _currentRank != null)
                Positioned(
                  top: 114,
                  right: 18,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1E7D4),
                      border: Border.all(color: const Color(0xFF7E4A23)),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      "You're currently Rank #$_currentRank"
                      '${_currentRankIsStale ? ' (may be outdated)' : ''}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF744411),
                      ),
                    ),
                  ),
                ),
              if (_showFirstTimeTutorial)
                Positioned.fill(
                  child: FirstTimeTutorialOverlay(
                    title: "Adventurer's Guide",
                    steps: _tutorialSteps,
                    onComplete: _completeFirstTimeTutorial,
                    onStepChanged: _focusTutorialStep,
                  ),
                ),
              Positioned(
                top: 6,
                right: 18,
                child: Material(
                  color: const Color(0xFFFFF3D8),
                  shape: const CircleBorder(
                    side: BorderSide(
                      color: Color(0xFF8F5C2D),
                      width: 1.5,
                    ),
                  ),
                  child: InkWell(
                    key: const ValueKey('home-help-button'),
                    onTap: _onHelpIconTapped,
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 38,
                      height: 38,
                      child: Icon(
                        Icons.question_mark_rounded,
                        size: 22,
                        color: Color(0xFF5A3620),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 12,
                right: 62,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _showHelpPopup ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: AnimatedScale(
                      scale: _showHelpPopup ? 1 : 0.96,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      alignment: Alignment.centerRight,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width - 86,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1E7D4),
                            border: Border.all(color: const Color(0xFF7E4A23)),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            "Adventurer's Guide",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF744411),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openProfileDialog(BuildContext context) {
    if (_isDialogOpen) return; // Prevent multiple dialogs

    _isDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide.none,
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ProfileScreen(
          isDialog: true,
          initialProfile: _profileData,
          initialProfilePhoto: _profilePhoto,
          onProfileUpdated: () => unawaited(_loadProfileData()),
          onClose: () {
            Navigator.pop(context);
          },
        ),
      ),
    ).then((_) {
      _isDialogOpen = false;
    });
  }

  Widget _buildHomeContent(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 72, 20, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 84).clamp(
              0.0,
              double.infinity,
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  menuCard(
                    context,
                    Icons.view_module,
                    'Module',
                    tutorialKey: _moduleTutorialKey,
                    onTap: () => _openScreen(const ModulesScreen()),
                  ),
                  menuCard(
                    context,
                    Icons.menu_book,
                    'Stages',
                    tutorialKey: _levelsTutorialKey,
                    onTap: () => _openScreen(
                      const StoryLevelsScreen(),
                      refreshRankOnReturn: true,
                    ),
                  ),
                  menuCard(
                    context,
                    Icons.assignment_rounded,
                    'Classroom Quests',
                    tutorialKey: _classroomTutorialKey,
                    onTap: () => _openScreen(
                      const ClassroomQuestScreen(),
                      refreshRankOnReturn: true,
                    ),
                  ),
                  menuCard(
                    context,
                    Icons.bar_chart,
                    'My Progress',
                    tutorialKey: _progressTutorialKey,
                    onTap: () => _openScreen(const TeacherAnalyticsScreen()),
                  ),
                  menuCard(
                    context,
                    Icons.workspace_premium_rounded,
                    'Badges',
                    tutorialKey: _badgesTutorialKey,
                    onTap: () => _openScreen(const BadgesScreen()),
                  ),
                  menuCard(
                    context,
                    Icons.emoji_events,
                    'Leaderboard',
                    tutorialKey: _leaderboardTutorialKey,
                    onTap: () => _openScreen(const LeaderboardScreen()),
                  ),
                  menuCard(
                    context,
                    Icons.quiz_outlined,
                    'Practice Mode',
                    onTap: _openPracticePanel,
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget menuCard(
    BuildContext context,
    IconData icon,
    String text, {
    VoidCallback? onTap,
    GlobalKey? tutorialKey,
  }) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final colors = [
      const Color(0xFF348BC4),
      const Color(0xFF57906A),
      const Color(0xFFEF9829),
      const Color(0xFF875DD0),
      const Color(0xFFD94D4A),
      const Color(0xFFE8A02E),
      const Color(0xFF57906A),
    ];

    final index = [
      'Module',
      'Stages',
      'Classroom Quests',
      'My Progress',
      'Badges',
      'Leaderboard',
      'Practice Mode',
    ].indexOf(text);
    final tileColor = colors[index.clamp(0, colors.length - 1)];

    double cardWidth = screenWidth * 0.78;

    if (cardWidth > 690) cardWidth = 690;
    if (cardWidth < 320) cardWidth = screenWidth - 26;

    return GestureDetector(
      key: tutorialKey,
      onTap: onTap,
      child: RepaintBoundary(
        child: Container(
          key: ValueKey('home-menu-$text'),
          width: cardWidth,
          height: 68,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: CustomPaint(
            painter: _PaperMenuCardPainter(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  PhysicalShape(
                    clipper: _MenuIconClipper(),
                    color: tileColor,
                    elevation: 3,
                    shadowColor: Colors.black.withValues(alpha: 0.32),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2E210C),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    const Icon(
                      Icons.chevron_right,
                      color: Color(0xFF4C3118),
                      size: 30,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuIconClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width * 0.2, 0)
    ..lineTo(size.width * 0.8, 0)
    ..lineTo(size.width, size.height * 0.2)
    ..lineTo(size.width, size.height * 0.8)
    ..lineTo(size.width * 0.8, size.height)
    ..lineTo(size.width * 0.2, size.height)
    ..lineTo(0, size.height * 0.8)
    ..lineTo(0, size.height * 0.2)
    ..close();

  @override
  bool shouldReclip(_MenuIconClipper oldClipper) => false;
}

class _PaperMenuCardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final card = RRect.fromRectAndRadius(rect, const Radius.circular(15));

    canvas.drawShadow(Path()..addRRect(card), const Color(0xFF2B1B10), 7, true);
    canvas.drawRRect(
      card,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF8EB), Color(0xFFF0E2CA)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      card,
      Paint()
        ..color = const Color(0xFF57371F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    final fold = Path()
      ..moveTo(size.width - 23, 2)
      ..lineTo(size.width - 3, 2)
      ..lineTo(size.width - 3, 22)
      ..quadraticBezierTo(size.width - 12, 14, size.width - 23, 2)
      ..close();
    canvas.drawPath(
      fold,
      Paint()..color = const Color(0xFFE5CBA2).withValues(alpha: 0.62),
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - 23, 2)
        ..quadraticBezierTo(size.width - 14, 14, size.width - 3, 22),
      Paint()
        ..color = const Color(0xFFC69A64).withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_PaperMenuCardPainter oldDelegate) => false;
}
