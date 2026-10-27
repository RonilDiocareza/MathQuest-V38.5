import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

enum FirebaseReachability { unknown, online, unavailable }

enum DisplayAuthorizationResult { authorized, temporarilyUnavailable, denied }

class VerifiedDisplaySession {
  const VerifiedDisplaySession({
    required this.uid,
    required this.sessionKey,
    required this.authorization,
  });

  final String uid;
  final String sessionKey;
  final DisplayAuthorizationResult authorization;
}

class VerifiedDisplayCacheStore {
  final Map<String, Object> _snapshots = {};

  String _key(String uid, String sessionKey, String feature) =>
      '$uid|$sessionKey|$feature';

  T? get<T extends Object>(String uid, String sessionKey, String feature) {
    final snapshot = _snapshots[_key(uid, sessionKey, feature)];
    return snapshot is T ? snapshot : null;
  }

  void put<T extends Object>(
    String uid,
    String sessionKey,
    String feature,
    T value,
  ) {
    _snapshots[_key(uid, sessionKey, feature)] = value;
  }

  void clear() => _snapshots.clear();

  void clearUid(String uid) {
    _snapshots.removeWhere((key, _) => key.startsWith('$uid|'));
  }
}

class VerifiedDisplayCache {
  VerifiedDisplayCache._();

  static final VerifiedDisplayCacheStore _store = VerifiedDisplayCacheStore();
  static final ValueNotifier<FirebaseReachability> reachability =
      ValueNotifier(FirebaseReachability.unknown);

  static StreamSubscription<void>? _invalidationSubscription;
  static StreamSubscription<User?>? _authSubscription;
  static String? _observedUid;
  static String? _statusUid;
  static String? _statusSessionKey;

  static void _ensureListeners() {
    _invalidationSubscription ??= AuthService.sessionInvalidations.listen((_) {
      _store.clear();
      _setReachability(
        null,
        null,
        FirebaseReachability.unknown,
      );
    });
    try {
      _authSubscription ??= FirebaseAuth.instance.authStateChanges().listen(
        (user) {
          final uid = user?.uid;
          if (_observedUid != uid) {
            _store.clear();
            _setReachability(null, null, FirebaseReachability.unknown);
            _observedUid = uid;
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint(
              'Unable to observe auth changes for display cache: $error');
          debugPrintStack(stackTrace: stackTrace);
          _store.clear();
          _setReachability(null, null, FirebaseReachability.unknown);
        },
      );
    } on FirebaseException {
      return;
    } catch (error, stackTrace) {
      debugPrint('Unable to start display-cache auth listener: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static T? get<T extends Object>(
      String uid, String sessionKey, String feature) {
    _ensureListeners();
    if (AuthService.currentUser?.uid != uid) return null;
    return _store.get<T>(uid, sessionKey, feature);
  }

  static Future<void> putForVerifiedSession<T extends Object>(
    String uid,
    String sessionKey,
    String feature,
    T value,
  ) async {
    _ensureListeners();
    if (AuthService.currentUser?.uid != uid) return;
    final activeSessionKey = await AuthService.currentVerifiedSessionCacheKey();
    if (activeSessionKey != sessionKey || AuthService.currentUser?.uid != uid) {
      return;
    }
    _store.put(uid, sessionKey, feature, value);
  }

  static Future<VerifiedDisplaySession?> verifyCurrentSession() async {
    _ensureListeners();
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return null;

    final sessionKey = await AuthService.currentVerifiedSessionCacheKey();
    if (sessionKey == null || AuthService.currentUser?.uid != uid) return null;

    SaveAuthorizationStatus authorization;
    try {
      authorization = await AuthService.checkCurrentSaveAuthorizationStatus()
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      authorization = SaveAuthorizationStatus.temporarilyUnableToVerify;
    }

    if (AuthService.currentUser?.uid != uid ||
        await AuthService.currentVerifiedSessionCacheKey() != sessionKey) {
      return null;
    }

    final result = switch (authorization) {
      SaveAuthorizationStatus.authorized =>
        DisplayAuthorizationResult.authorized,
      SaveAuthorizationStatus.temporarilyUnableToVerify =>
        DisplayAuthorizationResult.temporarilyUnavailable,
      _ => DisplayAuthorizationResult.denied,
    };
    setReachability(
      uid,
      sessionKey,
      result == DisplayAuthorizationResult.authorized
          ? FirebaseReachability.online
          : result == DisplayAuthorizationResult.temporarilyUnavailable
              ? FirebaseReachability.unavailable
              : FirebaseReachability.unknown,
    );
    return result == DisplayAuthorizationResult.denied
        ? null
        : VerifiedDisplaySession(
            uid: uid,
            sessionKey: sessionKey,
            authorization: result,
          );
  }

  static void setReachability(
    String uid,
    String sessionKey,
    FirebaseReachability status,
  ) {
    _ensureListeners();
    if (AuthService.currentUser?.uid != uid) return;
    _setReachability(uid, sessionKey, status);
  }

  static FirebaseReachability get currentReachability {
    _ensureListeners();
    if (AuthService.currentUser?.uid != _statusUid) {
      return FirebaseReachability.unknown;
    }
    if (_statusSessionKey == null) return FirebaseReachability.unknown;
    return reachability.value;
  }

  static void _setReachability(
    String? uid,
    String? sessionKey,
    FirebaseReachability status,
  ) {
    _statusUid = uid;
    _statusSessionKey = sessionKey;
    reachability.value = status;
  }
}
