import 'dart:async';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/leaderboard_service.dart';
import '../services/verified_display_cache.dart';
import '../widgets/connectivity_status_indicator.dart';
import '../widgets/custom_button.dart';
import '../widgets/math_background.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with WidgetsBindingObserver {
  StreamSubscription<LeaderboardEntriesSnapshot>? _topSubscription;
  StreamSubscription<void>? _sessionInvalidationSubscription;
  StreamSubscription<User?>? _authStateSubscription;

  List<LeaderboardEntry> _entries = const [];

  LeaderboardEntry? _currentEntry;

  Object? _streamError;

  Object? _rankError;

  int? _currentRank;

  bool _stale = false;
  bool _needsAuthorizationRefresh = false;
  bool _wasCacheSnapshot = false;
  bool _checkingReachability = false;
  bool _initializing = false;
  Timer? _initialLoadTimer;
  String? _screenUid;
  String? _sessionKey;
  int _request = 0;

  bool _loading = true;

  bool _rankLoading = true;

  String? get _uid => AuthService.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionInvalidationSubscription =
        AuthService.sessionInvalidations.listen((_) {
      _clearPrivateLeaderboard();
    });
    try {
      _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen(
        (user) {
          if (_screenUid != null && user?.uid != _screenUid) {
            _clearPrivateLeaderboard();
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Unable to observe leaderboard auth changes: $error');
          debugPrintStack(stackTrace: stackTrace);
          _clearPrivateLeaderboard();
        },
      );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('Unable to start leaderboard auth listener: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    _start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _start();
  }

  void _start() {
    if (_initializing) return;
    _initializing = true;
    _initialLoadTimer?.cancel();
    final request = ++_request;
    unawaited(_topSubscription?.cancel());
    setState(() {
      _loading = _entries.isEmpty;
      _rankLoading = _entries.isEmpty;
      _streamError = null;
      _rankError = null;
      _stale = _entries.isNotEmpty;
    });
    unawaited(_initializeLeaderboard(request));
  }

  Future<void> _initializeLeaderboard(int request) async {
    try {
      final session = await VerifiedDisplayCache.verifyCurrentSession();
      if (!mounted || request != _request) return;
      if (session == null) {
        _clearPrivateLeaderboard();
        return;
      }

      final cached = VerifiedDisplayCache.get<List<LeaderboardEntry>>(
        session.uid,
        session.sessionKey,
        'leaderboard',
      );
      _sessionKey = session.sessionKey;
      _screenUid = session.uid;
      _needsAuthorizationRefresh = session.authorization ==
          DisplayAuthorizationResult.temporarilyUnavailable;
      _wasCacheSnapshot = false;
      if (cached != null) _applyEntries(cached);
      if (mounted) {
        setState(() {
          _loading = cached == null &&
              session.authorization == DisplayAuthorizationResult.authorized;
          _rankLoading = _loading;
          _stale = cached != null;
          _streamError = cached == null &&
                  session.authorization ==
                      DisplayAuthorizationResult.temporarilyUnavailable
              ? StateError('Leaderboard unavailable.')
              : null;
        });
      }

      await _topSubscription?.cancel();
      if (!mounted || request != _request) return;
      _topSubscription = LeaderboardService.watchTopEntriesWithSource().listen(
        (snapshot) {
          if (snapshot.isFromCache) {
            if (!_wasCacheSnapshot &&
                VerifiedDisplayCache.currentReachability ==
                    FirebaseReachability.online) {
              unawaited(_checkServerReachability(request));
            }
            _wasCacheSnapshot = true;
            return;
          }
          _wasCacheSnapshot = false;
          unawaited(_acceptServerEntries(snapshot.entries, request));
        },
        onError: (Object error, StackTrace stackTrace) {
          _handleLeaderboardError(error, stackTrace, request);
        },
      );
      if (cached == null &&
          session.authorization == DisplayAuthorizationResult.authorized) {
        _initialLoadTimer = Timer(const Duration(seconds: 10), () {
          if (!mounted || request != _request || _entries.isNotEmpty) return;
          setState(() {
            _loading = false;
            _rankLoading = false;
            _streamError = StateError('Leaderboard unavailable.');
          });
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to load leaderboard: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _rankLoading = false;
        _stale = _entries.isNotEmpty;
        if (_entries.isEmpty) _streamError = error;
      });
      if (_isTemporaryFailure(error) && _uid != null && _sessionKey != null) {
        VerifiedDisplayCache.setReachability(
          _uid!,
          _sessionKey!,
          FirebaseReachability.unavailable,
        );
      } else {
        _clearPrivateLeaderboard();
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
      final uid = _screenUid;
      final sessionKey = _sessionKey;
      if (session == null ||
          session.uid != uid ||
          session.sessionKey != sessionKey) {
        _clearPrivateLeaderboard();
        return;
      }
      if (session.authorization ==
          DisplayAuthorizationResult.temporarilyUnavailable) {
        _needsAuthorizationRefresh = true;
        setState(() {
          _stale = _entries.isNotEmpty;
          _loading = false;
          _rankLoading = false;
        });
      } else {
        _needsAuthorizationRefresh = false;
        setState(() => _stale = false);
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Unable to verify Firebase reachability for leaderboard: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (_isAuthorizationFailure(error)) {
        AuthService.invalidateCurrentVerifiedSession();
        _clearPrivateLeaderboard();
        return;
      }
      if (!_isTemporaryFailure(error)) {
        _clearPrivateLeaderboard();
        return;
      }
      if (mounted && request == _request && _screenUid != null) {
        final uid = _screenUid!;
        final sessionKey = _sessionKey;
        if (sessionKey != null) {
          VerifiedDisplayCache.setReachability(
            uid,
            sessionKey,
            FirebaseReachability.unavailable,
          );
        }
        setState(() {
          _needsAuthorizationRefresh = true;
          _stale = _entries.isNotEmpty;
          _loading = false;
          _rankLoading = false;
        });
      }
    } finally {
      _checkingReachability = false;
    }
  }

  Future<void> _acceptServerEntries(
    List<LeaderboardEntry> entries,
    int request,
  ) async {
    final uid = _screenUid;
    final sessionKey = _sessionKey;
    if (uid == null ||
        sessionKey == null ||
        request != _request ||
        AuthService.currentUser?.uid != uid) {
      return;
    }

    if (_needsAuthorizationRefresh) {
      final session = await VerifiedDisplayCache.verifyCurrentSession();
      if (!mounted || request != _request) return;
      if (session == null ||
          session.uid != uid ||
          session.sessionKey != sessionKey) {
        _clearPrivateLeaderboard();
        return;
      }
      if (session.authorization != DisplayAuthorizationResult.authorized) {
        setState(() {
          _loading = false;
          _rankLoading = false;
          _stale = _entries.isNotEmpty;
          if (_entries.isEmpty) {
            _streamError = StateError('Leaderboard unavailable.');
          }
        });
        return;
      }
      _needsAuthorizationRefresh = false;
    }

    final safeEntries = List<LeaderboardEntry>.unmodifiable(entries);
    await VerifiedDisplayCache.putForVerifiedSession(
      uid,
      sessionKey,
      'leaderboard',
      safeEntries,
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
      _applyEntries(safeEntries);
      _loading = false;
      _rankLoading = false;
      _stale = false;
      _streamError = null;
      _rankError = null;
    });
  }

  void _applyEntries(List<LeaderboardEntry> entries) {
    _entries = entries;
    final uid = _uid;
    final sortedEntries = LeaderboardService.sortEntries(entries);
    final currentIndex = uid == null
        ? -1
        : sortedEntries.indexWhere((entry) => entry.uid == uid);
    _currentEntry = currentIndex < 0 ? null : sortedEntries[currentIndex];
    _currentRank = currentIndex < 0 ? null : currentIndex + 1;
  }

  void _handleLeaderboardError(
    Object error,
    StackTrace stackTrace,
    int request,
  ) {
    debugPrint('Unable to watch leaderboard updates: $error');
    debugPrintStack(stackTrace: stackTrace);
    if (!mounted || request != _request) return;
    if (_isAuthorizationFailure(error)) {
      AuthService.invalidateCurrentVerifiedSession();
      _clearPrivateLeaderboard();
      return;
    }
    if (_isTemporaryFailure(error)) {
      if (_uid != null && _sessionKey != null) {
        VerifiedDisplayCache.setReachability(
          _uid!,
          _sessionKey!,
          FirebaseReachability.unavailable,
        );
      }
      _needsAuthorizationRefresh = true;
      setState(() {
        _loading = false;
        _rankLoading = false;
        _stale = _entries.isNotEmpty;
        if (_entries.isEmpty) _streamError = error;
      });
      return;
    }
    setState(() {
      _loading = false;
      _rankLoading = false;
      _stale = _entries.isNotEmpty;
      if (_entries.isEmpty) _streamError = error;
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

  void _clearPrivateLeaderboard() {
    _request++;
    _initialLoadTimer?.cancel();
    _wasCacheSnapshot = false;
    _checkingReachability = false;
    unawaited(_topSubscription?.cancel());
    _topSubscription = null;
    if (!mounted) return;
    setState(() {
      _screenUid = null;
      _sessionKey = null;
      _entries = const [];
      _currentEntry = null;
      _currentRank = null;
      _loading = false;
      _rankLoading = false;
      _stale = false;
      _streamError = StateError('Verified student session unavailable.');
      _rankError = null;
    });
  }

  Future<void> _retry() async {
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _request++;
    _initialLoadTimer?.cancel();
    unawaited(_topSubscription?.cancel());
    unawaited(_sessionInvalidationSubscription?.cancel());
    unawaited(_authStateSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    final displayEntries = LeaderboardService.sortEntries([
      ..._entries.where((entry) => entry.uid != _currentEntry?.uid),
      if (_currentEntry != null) _currentEntry!,
    ]);

    final displayName = _currentEntry?.displayName ?? 'Not ranked yet';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const SizedBox(width: 56),
        title: const Text(
          'Leaderboard',
          style: TextStyle(color: Colors.black),
        ),
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
                  if (_stale && _entries.isNotEmpty)
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Rankings may be outdated',
                          style: TextStyle(
                            color: Color(0xFF785333),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: _streamError != null
                        ? _buildError()
                        : _loading
                            ? const Center(
                                child: CircularProgressIndicator(),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildCurrentSummary(displayName),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      8,
                                      20,
                                      12,
                                    ),
                                    child: const Text(
                                      'All Players',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: displayEntries.isEmpty
                                        ? const Center(
                                            child: Text('No scores yet.'),
                                          )
                                        : ListView.builder(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              0,
                                              16,
                                              16,
                                            ),
                                            itemCount: displayEntries.length,
                                            itemBuilder: (context, index) {
                                              final entry =
                                                  displayEntries[index];
                                              return _buildEntryRow(
                                                entry,
                                                index + 1,
                                                isCurrent: entry.uid == uid,
                                              );
                                            },
                                          ),
                                  ),
                                  Transform.translate(
                                    offset: const Offset(0, -35),
                                    child: Center(
                                      child: CustomButton(
                                        text: 'Back',
                                        onPressed: () {
                                          if (Navigator.canPop(context)) {
                                            Navigator.pop(context);
                                          } else {
                                            Navigator.pushReplacementNamed(
                                                context, '/home');
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSummary(
    String displayName,
  ) {
    return Card(
      margin: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        8,
      ),
      color: const Color(0xFFFFE4BC),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFD09F5C),
              child: Icon(
                Icons.person,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_rankLabel),
                ],
              ),
            ),
            Text(
              _formatScore(
                _currentEntry?.totalScore ?? 0,
              ),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF744411),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _rankLabel {
    if (_rankLoading) {
      return 'Your Rank: loading...';
    }

    if (_rankError != null) {
      return 'Your Rank: unavailable';
    }

    return 'Your Rank: '
        '${_currentRank == null ? '—' : '#$_currentRank'}';
  }

  Widget _buildEntryRow(
    LeaderboardEntry entry,
    int? rank, {
    required bool isCurrent,
  }) {
    final rankLabel = rank == null ? '—' : '$rank';

    final medal = switch (rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => null,
    };

    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: 4,
      ),
      color: isCurrent ? const Color(0xFFF4DDB8) : const Color(0xFFFFF8EB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
          color: Color(0xFF785333),
          width: 1.3,
        ),
      ),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 55,
              child: Text(
                medal == null ? rankLabel : '$medal $rankLabel',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Text(
                entry.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _formatScore(
                entry.totalScore,
              ),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 48,
              color: Color(0xFF785333),
            ),
            const SizedBox(height: 12),
            const Text(
              'Could not load the leaderboard.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _friendlyError(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _retry,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyError() {
    final error = _streamError;

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Firebase denied access to the leaderboard. Check Firestore rules.';
        case 'failed-precondition':
          return 'Firestore requires an index for the leaderboard query.';
        case 'unauthenticated':
          return 'Your Firebase session is no longer authenticated.';
        case 'unavailable':
          return 'Firebase is temporarily unavailable. Check your internet connection.';
        case 'not-found':
          return 'The leaderboard data could not be found.';
        default:
          return 'Firebase error: ${error.code}';
      }
    }

    return 'The leaderboard is temporarily unavailable. Please try again.';
  }

  String _formatScore(int score) {
    return score.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => ',',
        );
  }
}
