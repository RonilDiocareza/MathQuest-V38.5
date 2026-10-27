import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class TutorialService {
  static const Duration _statusReadTimeout = Duration(seconds: 8);

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

  static Future<bool?> shouldShowFirstTimeTutorial(String uid) async {
    final user = _authOrNull?.currentUser;
    debugPrint(
      '[TutorialService] Checking tutorial state: '
      'authCurrentUser=${user != null}, authUid=${user?.uid ?? '(none)'}, '
      'requestedUid=$uid, document=users/$uid, '
      'fields=tutorialEligible,tutorialCompleted.',
    );
    if (user == null || user.uid != uid) {
      throw StateError(
        'The authenticated user does not match the tutorial account.',
      );
    }

    try {
      final snapshot = await _users
          .doc(uid)
          .get(const GetOptions(source: Source.server))
          .timeout(_statusReadTimeout);
      debugPrint(
        '[TutorialService] Tutorial state read completed: '
        'document=users/$uid, exists=${snapshot.exists}.',
      );
      if (!snapshot.exists) return false;
      _verifyUserDocument(uid, snapshot);
      final data = snapshot.data();
      final eligible = data?['tutorialEligible'];
      final completed = data?['tutorialCompleted'];
      debugPrint(
        '[TutorialService] Tutorial state values: '
        'tutorialEligible=$eligible '
        '(${eligible?.runtimeType ?? 'null'}), '
        'tutorialCompleted=$completed '
        '(${completed?.runtimeType ?? 'null'}).',
      );
      return snapshot.exists && eligible == true && completed != true;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        '[TutorialService] Tutorial state read failed: '
        'plugin=${error.plugin}, code=${error.code}, '
        'message=${error.message ?? '(none)'}.',
      );
      if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
      if (_isTemporaryNetworkFailure(error.code)) return null;
      rethrow;
    } on TimeoutException catch (error, stackTrace) {
      debugPrint(
        '[TutorialService] Tutorial state read timed out after '
        '${_statusReadTimeout.inSeconds} seconds: $error.',
      );
      if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
      return null;
    } catch (error, stackTrace) {
      debugPrint(
        '[TutorialService] Tutorial state check failed: '
        'type=${error.runtimeType}, message=$error.',
      );
      if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  static bool _isTemporaryNetworkFailure(String code) => const {
        'deadline-exceeded',
        'network-request-failed',
        'unavailable',
      }.contains(code);

  static Future<void> completeFirstTimeTutorial() async {
    final user = _authOrNull?.currentUser;
    if (user == null) {
      throw StateError('Sign in before saving tutorial progress.');
    }
    if (user.uid.isEmpty) {
      throw StateError('The signed-in account has no user ID.');
    }

    final documentPath = 'users/${user.uid}';
    final userReference = _users.doc(user.uid);
    var stage = 'reading saved completion status';
    var writeAttempted = false;
    debugPrint(
      '[TutorialService] Verifying tutorial completion: '
      'authCurrentUser=true, authUid=${user.uid}, document=$documentPath, '
      'authenticatedUidMatchesDocumentId=true.',
    );
    try {
      var snapshot = await userReference.get(
        const GetOptions(source: Source.server),
      );
      _verifyUserDocument(user.uid, snapshot);
      if (snapshot.data()?['tutorialCompleted'] == true) {
        debugPrint(
          '[TutorialService] Server confirms tutorial already completed: '
          'document=$documentPath, field=tutorialCompleted, value=true.',
        );
        return;
      }

      stage = 'writing tutorial completion';
      writeAttempted = true;
      await userReference.update({'tutorialCompleted': true});

      stage = 'verifying saved tutorial completion';
      snapshot = await userReference.get(
        const GetOptions(source: Source.server),
      );
      _verifyUserDocument(user.uid, snapshot);
      if (snapshot.data()?['tutorialCompleted'] != true) {
        throw StateError(
          'Firestore did not confirm tutorial completion for $documentPath.',
        );
      }
      debugPrint(
        '[TutorialService] Firestore completion verified: '
        'document=$documentPath, field=tutorialCompleted, value=true.',
      );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        '[TutorialService] Tutorial completion failed while $stage: '
        'authCurrentUser=${_authOrNull?.currentUser != null}, '
        'authUid=${_authOrNull?.currentUser?.uid ?? '(none)'}, '
        'document=$documentPath, field=tutorialCompleted, value=true, '
        'plugin=${error.plugin}, code=${error.code}, '
        'message=${error.message ?? '(none)'}.',
      );
      if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
      if (!writeAttempted) {
        Error.throwWithStackTrace(error, stackTrace);
      }

      try {
        final confirmedSnapshot = await userReference.get(
          const GetOptions(source: Source.server),
        );
        _verifyUserDocument(user.uid, confirmedSnapshot);
        if (confirmedSnapshot.data()?['tutorialCompleted'] == true) {
          debugPrint(
            '[TutorialService] Server confirms completion despite the '
            'write response error: document=$documentPath.',
          );
          return;
        }
      } catch (verificationError, verificationStackTrace) {
        debugPrint(
          '[TutorialService] Completion reconciliation failed: '
          'document=$documentPath, '
          'type=${verificationError.runtimeType}, '
          'message=$verificationError.',
        );
        if (verificationError is FirebaseException) {
          debugPrint(
            '[TutorialService] Reconciliation Firebase error: '
            'plugin=${verificationError.plugin}, '
            'code=${verificationError.code}, '
            'message=${verificationError.message ?? '(none)'}.',
          );
        }
        if (kDebugMode) {
          debugPrintStack(stackTrace: verificationStackTrace);
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    } catch (error, stackTrace) {
      debugPrint(
        '[TutorialService] Tutorial completion failed while $stage: '
        'authCurrentUser=${_authOrNull?.currentUser != null}, '
        'authUid=${_authOrNull?.currentUser?.uid ?? '(none)'}, '
        'document=$documentPath, field=tutorialCompleted, value=true, '
        'type=${error.runtimeType}, message=$error.',
      );
      if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  static void _verifyUserDocument(
    String uid,
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final storedUid = snapshot.data()?['uid'];
    if (storedUid != null && storedUid != uid) {
      throw StateError(
        'The account UID in users/$uid does not match the authenticated user.',
      );
    }
  }
}
