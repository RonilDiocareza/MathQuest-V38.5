import 'dart:convert';
import 'dart:math';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_account.dart';
import 'leaderboard_service.dart';

enum SaveAuthorizationStatus {
  signedOut,
  sessionExpired,
  accountNotApproved,
  authorized,
  temporarilyUnableToVerify,
  securityVerificationFailed,
  unableToVerify,
}

class AuthService {
  static const String firestoreProfilePhotoUrl = 'firestore://profile-photo';
  static const String _pendingEmailChangeKeyPrefix =
      'pending_profile_email_change_';

  static FirebaseAuth get _auth {
    try {
      return FirebaseAuth.instance;
    } on FirebaseException {
      throw StateError(
          'Firebase Auth is not available because Firebase is not initialized.');
    } catch (_) {
      throw StateError(
          'Firebase Auth is not available because Firebase is not initialized.');
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

  static DocumentReference<Map<String, dynamic>> _profilePhotoDocument(
    String uid,
  ) =>
      _users.doc(uid).collection('profileData').doc('photo');

  static Future<void> _logProfileSaveContext(
    String uid, {
    String? requestedName,
    String? requestedAddress,
    String? requestedPhotoDataUrl,
  }) async {
    try {
      final userSnapshot = await _users.doc(uid).get(
            const GetOptions(source: Source.server),
          );
      final account = userSnapshot.data();
      final sessionSnapshot = await _sessions.doc(uid).get(
            const GetOptions(source: Source.server),
          );
      final photoSnapshot = await _profilePhotoDocument(uid).get(
        const GetOptions(source: Source.server),
      );
      final storedName = account?['name'];
      final storedAddress = account?['address'];
      final photoDataIsValid = requestedPhotoDataUrl == null ||
          (requestedPhotoDataUrl.length <= 830000 &&
              RegExp(
                r'^data:image/(jpeg|png|webp);base64,[A-Za-z0-9+/]+={0,2}$',
              ).hasMatch(requestedPhotoDataUrl));
      debugPrint(
        'Profile save context: project=${FirebaseFirestore.instance.app.options.projectId}, '
        'authUidMatchesTarget=${currentUser?.uid == uid}, '
        'userDocumentExists=${userSnapshot.exists}, '
        'storedUidMatches=${account?['uid'] == null || account?['uid'] == uid}, '
        'role=${account?['role'] ?? '(missing)'}, '
        'status=${account?['status'] ?? '(missing)'}, '
        'activeSessionExists=${sessionSnapshot.exists}, '
        'lrnPresent=${account?.containsKey('lrn') ?? false}, '
        'storedNameValid=${storedName is String && storedName.isNotEmpty && storedName.length <= 100}, '
        'storedAddressValid=${storedAddress is String && storedAddress.length <= 300}, '
        'requestedNameValid=${requestedName == null || (requestedName.isNotEmpty && requestedName.length <= 100)}, '
        'requestedAddressValid=${requestedAddress == null || requestedAddress.length <= 300}, '
        'photoDocumentExists=${photoSnapshot.exists}, '
        'photoDataShapeValid=$photoDataIsValid.',
      );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Unable to read profile-save authorization context '
        '(uid=$uid, plugin=${error.plugin}, code=${error.code}, '
        'message=${error.message ?? '(none)'}).',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static CollectionReference<Map<String, dynamic>> get _sessions {
    try {
      return FirebaseFirestore.instance.collection('activeSessions');
    } on FirebaseException {
      throw StateError(
          'Firebase Firestore is not available because Firebase is not initialized.');
    } catch (_) {
      throw StateError(
          'Firebase Firestore is not available because Firebase is not initialized.');
    }
  }

  static const _deviceIdKey = 'mathquest_device_id';
  static const _sessionIdKeyPrefix = 'mathquest_session_id_';
  static String? _verifiedSessionUid;
  static String? _verifiedSessionCacheKey;
  static final StreamController<void> _sessionInvalidations =
      StreamController<void>.broadcast(sync: true);

  static Stream<void> get sessionInvalidations => _sessionInvalidations.stream;

  static bool _isTemporaryNetworkFailure(String code) => const {
        'deadline-exceeded',
        'network-request-failed',
        'unavailable',
      }.contains(code);

  static void invalidateCurrentVerifiedSession() {
    _verifiedSessionUid = null;
    _verifiedSessionCacheKey = null;
    _sessionInvalidations.add(null);
  }

  static void _rememberVerifiedSession(
    String uid,
    String deviceId,
    String sessionId,
  ) {
    _verifiedSessionUid = uid;
    _verifiedSessionCacheKey = '$uid:$deviceId:$sessionId';
  }

  static Future<String?> currentVerifiedSessionCacheKey() async {
    final user = currentUser;
    if (user == null || _verifiedSessionUid != user.uid) return null;

    final preferences = await SharedPreferences.getInstance();
    final deviceId = preferences.getString(_deviceIdKey);
    final sessionId = preferences.getString('$_sessionIdKeyPrefix${user.uid}');
    if (deviceId == null ||
        deviceId.length < 16 ||
        sessionId == null ||
        sessionId.isEmpty) {
      return null;
    }

    final cacheKey = '${user.uid}:$deviceId:$sessionId';
    return cacheKey == _verifiedSessionCacheKey ? cacheKey : null;
  }

  static User? get currentUser {
    try {
      return FirebaseAuth.instance.currentUser;
    } on FirebaseException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<SaveAuthorizationStatus>
      checkCurrentSaveAuthorizationStatus() async {
    final user = currentUser;
    if (user == null) {
      invalidateCurrentVerifiedSession();
      return SaveAuthorizationStatus.signedOut;
    }

    try {
      final preferences = await SharedPreferences.getInstance();
      final deviceId = preferences.getString(_deviceIdKey);
      final cachedSessionId =
          preferences.getString('$_sessionIdKeyPrefix${user.uid}');
      if (deviceId == null ||
          deviceId.length < 16 ||
          cachedSessionId == null ||
          cachedSessionId.isEmpty) {
        invalidateCurrentVerifiedSession();
        return SaveAuthorizationStatus.sessionExpired;
      }

      final sessionSnapshot = await _sessions.doc(user.uid).get(
            const GetOptions(source: Source.server),
          );
      final session = sessionSnapshot.data();
      if (!sessionSnapshot.exists ||
          session?['deviceId'] != deviceId ||
          session?['sessionId'] != cachedSessionId) {
        invalidateCurrentVerifiedSession();
        return SaveAuthorizationStatus.sessionExpired;
      }

      final accountSnapshot = await _users.doc(user.uid).get(
            const GetOptions(source: Source.server),
          );
      final account = accountSnapshot.data();
      if (account == null ||
          account['role']?.toString().toLowerCase() != 'student' ||
          account['status']?.toString().toLowerCase() != 'approved') {
        invalidateCurrentVerifiedSession();
        return SaveAuthorizationStatus.accountNotApproved;
      }
      if (currentUser?.uid != user.uid) {
        invalidateCurrentVerifiedSession();
        return SaveAuthorizationStatus.signedOut;
      }
      return SaveAuthorizationStatus.authorized;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Unable to verify save authorization after permission denial: '
        'plugin=${error.plugin}, code=${error.code}, '
        'message=${error.message}.',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (error.code == 'unauthenticated') {
        invalidateCurrentVerifiedSession();
        return SaveAuthorizationStatus.signedOut;
      }
      if (error.code == 'permission-denied') {
        invalidateCurrentVerifiedSession();
        return SaveAuthorizationStatus.securityVerificationFailed;
      }
      if (_isTemporaryNetworkFailure(error.code)) {
        return SaveAuthorizationStatus.temporarilyUnableToVerify;
      }
      return SaveAuthorizationStatus.unableToVerify;
    } catch (error, stackTrace) {
      debugPrint(
        'Unable to verify save authorization after permission denial: '
        'exceptionType=${error.runtimeType}, message=$error.',
      );
      debugPrintStack(stackTrace: stackTrace);
      return SaveAuthorizationStatus.unableToVerify;
    }
  }

  static Future<String> savePermissionDeniedMessage(String feature) async {
    final status = await checkCurrentSaveAuthorizationStatus();
    return switch (status) {
      SaveAuthorizationStatus.signedOut =>
        'You have been signed out. Sign in again before saving $feature.',
      SaveAuthorizationStatus.sessionExpired =>
        'Your active session is no longer valid. Sign in again before saving $feature.',
      SaveAuthorizationStatus.accountNotApproved =>
        'Your student account is not approved for saving $feature. Contact your teacher or administrator.',
      SaveAuthorizationStatus.authorized =>
        'Firestore denied this $feature save even though your active student session is valid. Contact support.',
      SaveAuthorizationStatus.temporarilyUnableToVerify =>
        'Firestore denied this $feature save, but the session could not be verified. Check your connection and sign in again if needed.',
      SaveAuthorizationStatus.securityVerificationFailed =>
        'Firestore denied this $feature save because the account or session could not be authorized. Sign in again or contact support.',
      SaveAuthorizationStatus.unableToVerify =>
        'Firestore denied this $feature save, but the session could not be verified. Check your connection and sign in again if needed.',
    };
  }

  static Future<UserAccount?> restoreSignedInAccount() async {
    final restoreTimer = Stopwatch()..start();
    invalidateCurrentVerifiedSession();
    final user = _auth.currentUser;
    if (user == null) return null;

    final uid = user.uid;
    final preferences = await SharedPreferences.getInstance();
    final deviceId = preferences.getString(_deviceIdKey);
    final cachedSessionId = preferences.getString('$_sessionIdKeyPrefix$uid');
    if (deviceId == null ||
        deviceId.length < 16 ||
        cachedSessionId == null ||
        cachedSessionId.isEmpty) {
      await _discardLocalSession(uid);
      return null;
    }

    final firestoreReadTimer = Stopwatch()..start();
    final snapshots = await Future.wait([
      _sessions.doc(uid).get(const GetOptions(source: Source.server)),
      _users.doc(uid).get(const GetOptions(source: Source.server)),
    ]);
    final sessionSnapshot = snapshots[0];
    final accountSnapshot = snapshots[1];
    if (kDebugMode) {
      debugPrint(
        '[AuthService] Startup session/account server reads completed in '
        '${firestoreReadTimer.elapsedMilliseconds} ms.',
      );
    }
    final session = sessionSnapshot.data();
    if (!sessionSnapshot.exists ||
        session?['deviceId'] != deviceId ||
        session?['sessionId'] != cachedSessionId) {
      debugPrint(
        '[AuthService] Persisted Firebase user has no matching active device '
        'session: uid=$uid, sessionExists=${sessionSnapshot.exists}, '
        'deviceMatches=${session?['deviceId'] == deviceId}, '
        'sessionMatches=${session?['sessionId'] == cachedSessionId}.',
      );
      await _discardLocalSession(uid);
      return null;
    }

    final accountData = accountSnapshot.data();
    final account = accountData == null
        ? null
        : UserAccount.fromJson({...accountData, 'uid': accountSnapshot.id});
    final storedUid = accountData?['uid'];
    final validAccount = account != null &&
        (storedUid == null || storedUid == uid) &&
        account.isApproved &&
        (account.role.toLowerCase() == 'student' ||
            account.isTeacher ||
            account.isAdmin);
    if (!validAccount) {
      debugPrint(
        '[AuthService] Persisted Firebase user has no valid approved account: '
        'uid=$uid, accountExists=${accountSnapshot.exists}, '
        'storedUid=${storedUid ?? '(none)'}, '
        'role=${account?.role ?? '(none)'}, '
        'status=${account?.status ?? '(none)'}.',
      );
      await _releaseLoginSession(uid, deviceId, cachedSessionId);
      await _discardLocalSession(uid);
      return null;
    }

    await preferences.setString('current_user_email', account.email);
    await preferences.setString('current_user_name', account.name);
    await preferences.setString('current_user_role', account.role);
    await preferences.setString('current_user_lrn', account.lrn);
    await preferences.setString('current_user_address', account.address);
    _rememberVerifiedSession(uid, deviceId, cachedSessionId);
    if (kDebugMode) {
      debugPrint(
        '[AuthService] Session restore completed in '
        '${restoreTimer.elapsedMilliseconds} ms.',
      );
    }
    return account;
  }

  static Future<void> _discardLocalSession(String uid) async {
    invalidateCurrentVerifiedSession();
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('$_sessionIdKeyPrefix$uid');
    await _auth.signOut();
  }

  static Future<UserAccount> signIn(String email, String password) async {
    invalidateCurrentVerifiedSession();
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final uid = credential.user!.uid;
    String? sessionId;
    String? deviceId;
    try {
      deviceId = await _getDeviceId();
      sessionId = await _claimLoginSession(uid, deviceId);

      final account = await getAccount(uid);
      if (account == null) {
        throw StateError(
          'Your account profile is missing for UID $uid. '
          'Create the users document with this exact ID in the same Firebase project.',
        );
      }
      if (!account.isApproved) {
        throw StateError('Account pending admin approval.');
      }
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        '$_sessionIdKeyPrefix$uid',
        sessionId,
      );
      _rememberVerifiedSession(uid, deviceId, sessionId);
      return account;
    } catch (_) {
      var failedSessionId = sessionId;
      failedSessionId ??= sessionId;
      if (failedSessionId != null && deviceId != null) {
        try {
          await _releaseLoginSession(uid, deviceId, failedSessionId);
        } catch (error, stackTrace) {
          debugPrint('Unable to release failed login session: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
      await _auth.signOut();
      rethrow;
    }
  }

  static Future<UserAccount> register({
    required String email,
    required String password,
    required String name,
    required String address,
    required String lrn,
    required String character,
  }) async {
    final normalizedLrn = lrn.trim();
    if (!RegExp(r'^\d{12}$').hasMatch(normalizedLrn)) {
      throw ArgumentError('LRN must contain exactly 12 digits.');
    }

    final normalizedEmail = email.trim().toLowerCase();
    UserCredential credential;
    var createdAuthUser = false;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      createdAuthUser = true;
    } on FirebaseAuthException catch (error) {
      if (error.code != 'email-already-in-use') rethrow;
      credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
    }

    final authUser = credential.user!;
    final account = UserAccount(
      uid: authUser.uid,
      email: normalizedEmail,
      role: 'student',
      status: 'pending',
      name: name.trim(),
      address: address.trim(),
      lrn: normalizedLrn,
      character: character == 'girl' ? 'girl' : 'boy',
    );
    try {
      await _createStudentProfile(
        uid: authUser.uid,
        email: normalizedEmail,
        name: name.trim(),
        address: address.trim(),
        lrn: normalizedLrn,
        character: character,
      );

      try {
        await LeaderboardService.createRegistrationEntry(
          uid: authUser.uid,
          displayName: name,
        );
      } catch (error, stackTrace) {
        debugPrint(
            'Unable to initialize pending student leaderboard entry: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    } catch (error, stackTrace) {
      if (createdAuthUser) {
        await _removeAuthUserIfProfileWasNotCreated(
          authUser: authUser,
          email: normalizedEmail,
          lrn: normalizedLrn,
        );
      }
      if (error is FirebaseException) {
        debugPrint(
          'Student profile registration failed: plugin=${error.plugin}, '
          'code=${error.code}, message=${error.message ?? '(none)'}.',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      rethrow;
    } finally {
      try {
        await _auth.signOut();
      } catch (error, stackTrace) {
        debugPrint('Unable to sign out after registration: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    return account;
  }

  static Future<void> _removeAuthUserIfProfileWasNotCreated({
    required User authUser,
    required String email,
    required String lrn,
  }) async {
    try {
      final profileSnapshot = await _users.doc(authUser.uid).get();
      final profile = profileSnapshot.data();
      if (profileSnapshot.exists &&
          profile?['email'] == email &&
          profile?['lrn'] == lrn &&
          profile?['role'] == 'student') {
        return;
      }
      if (!profileSnapshot.exists) {
        await authUser.delete();
        return;
      }
      debugPrint(
        'Retaining newly created Auth user ${authUser.uid}: a user profile '
        'exists but does not match the attempted registration.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Unable to verify or clean up incomplete registration for '
        '${authUser.uid}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> _createStudentProfile({
    required String uid,
    required String email,
    required String name,
    required String address,
    required String lrn,
    required String character,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = _users.doc(uid);
    final indexCollection = firestore.collection('lrnIndexes');
    final legacyIndexRef = indexCollection.doc(lrn);
    final hashedIndexRef =
        indexCollection.doc(sha256.convert(utf8.encode(lrn)).toString());

    await firestore.runTransaction<void>((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      if (userSnapshot.exists) {
        final existing = userSnapshot.data()!;
        if (existing['email'] == email &&
            existing['lrn'] == lrn &&
            existing['role'] == 'student') {
          return;
        }
        throw StateError('This account is already registered.');
      }

      late final DocumentSnapshot<Map<String, dynamic>> hashedIndexSnapshot;
      late final DocumentSnapshot<Map<String, dynamic>> legacyIndexSnapshot;
      try {
        hashedIndexSnapshot = await transaction.get(hashedIndexRef);
        legacyIndexSnapshot = await transaction.get(legacyIndexRef);
      } on FirebaseException catch (error, stackTrace) {
        if (error.code == 'permission-denied') {
          debugPrint(
            'LRN index lookup denied: plugin=${error.plugin}, '
            'code=${error.code}, message=${error.message ?? '(none)'}, '
            'uid=$uid.',
          );
          debugPrintStack(stackTrace: stackTrace);
          throw StateError('This LRN is already registered.');
        }
        rethrow;
      }
      for (final snapshot in [hashedIndexSnapshot, legacyIndexSnapshot]) {
        if (snapshot.exists && snapshot.data()?['uid'] != uid) {
          throw StateError('This LRN is already registered.');
        }
      }

      if (!legacyIndexSnapshot.exists) {
        transaction.set(legacyIndexRef, {
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.set(userRef, {
        'uid': uid,
        'email': email,
        'role': 'student',
        'status': 'pending',
        'name': name,
        'address': address,
        'lrn': lrn,
        'character': character == 'girl' ? 'girl' : 'boy',
        'profilePhotoUrl': '',
        'tutorialEligible': true,
        'tutorialCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<UserAccount?> getAccount(String uid) async {
    final snapshot = await _users.doc(uid).get();
    if (!snapshot.exists) return null;
    return UserAccount.fromJson({...snapshot.data()!, 'uid': snapshot.id});
  }

  static Future<List<UserAccount>> loadAccounts() async {
    final snapshot = await _users.orderBy('name').get();
    return snapshot.docs
        .map((doc) => UserAccount.fromJson({...doc.data(), 'uid': doc.id}))
        .toList();
  }

  static Future<void> sendStudentPasswordResetEmail({
    required String studentUid,
    required String registeredEmail,
  }) async {
    final admin = currentUser;
    if (admin == null) {
      throw StateError('Sign in as an administrator before continuing.');
    }

    final preferences = await SharedPreferences.getInstance();
    final deviceId = preferences.getString(_deviceIdKey);
    final sessionId = preferences.getString('$_sessionIdKeyPrefix${admin.uid}');
    if (deviceId == null || sessionId == null || sessionId.isEmpty) {
      throw StateError('The administrator device session is not valid.');
    }

    final adminRef = _users.doc(admin.uid);
    final sessionRef = _sessions.doc(admin.uid);
    final studentRef = _users.doc(studentUid);
    final snapshots = await Future.wait([
      adminRef.get(const GetOptions(source: Source.server)),
      sessionRef.get(const GetOptions(source: Source.server)),
      studentRef.get(const GetOptions(source: Source.server)),
    ]);
    final adminData = snapshots[0].data();
    final sessionData = snapshots[1].data();
    final studentData = snapshots[2].data();
    if (currentUser?.uid != admin.uid ||
        adminData?['role']?.toString().toLowerCase() != 'admin' ||
        adminData?['status']?.toString().toLowerCase() != 'approved' ||
        sessionData?['deviceId'] != deviceId ||
        sessionData?['sessionId'] != sessionId) {
      throw StateError(
        'The current account does not have a valid administrator session.',
      );
    }

    final normalizedEmail = registeredEmail.trim().toLowerCase();
    if (studentData == null ||
        studentData['role']?.toString().toLowerCase() != 'student' ||
        studentData['email']?.toString().trim().toLowerCase() !=
            normalizedEmail) {
      throw StateError(
        'The selected student account or registered email has changed. '
        'Reload the student list and try again.',
      );
    }

    await _auth.sendPasswordResetEmail(email: normalizedEmail);
  }

  static Future<void> approveAccountAsTeacher(String uid) async {
    final targetUid = uid.trim();
    if (targetUid.isEmpty || targetUid.contains('/')) {
      throw ArgumentError.value(uid, 'uid');
    }

    final targetRef = _users.doc(targetUid);
    await FirebaseFirestore.instance.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(targetRef);
      if (!snapshot.exists) {
        throw StateError('The selected account no longer exists.');
      }

      final account = snapshot.data()!;
      final role = account['role'];
      final status = account['status'];
      if (role == 'teacher' && status == 'approved') {
        return;
      }
      if (role != 'student' || (status != 'pending' && status != 'approved')) {
        throw StateError(
          'Only an existing student account can be approved as a teacher.',
        );
      }

      transaction.update(targetRef, {
        'role': 'teacher',
        'status': 'approved',
      });
    });
  }

  static Future<void> updateAccount(UserAccount account) {
    final currentLrn = account.lrn.trim();
    return _users.doc(account.uid).get().then((snapshot) {
      if (snapshot.data()?['lrn'] != currentLrn) {
        throw StateError('An account LRN cannot be changed.');
      }
      final data = account.toJson()..remove('uid');
      return _users.doc(account.uid).update(data);
    });
  }

  static Future<void> deleteAccount(UserAccount account) async {
    final lrnIndex =
        FirebaseFirestore.instance.collection('lrnIndexes').doc(account.lrn);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final indexSnapshot = await transaction.get(lrnIndex);
      transaction.delete(_users.doc(account.uid));
      if (indexSnapshot.data()?['uid'] == account.uid) {
        transaction.delete(lrnIndex);
      }
    });
  }

  static Future<void> updateCurrentProfile({
    required String name,
    required String address,
    String? grade,
    String? lrn,
  }) async {
    final user = currentUser;
    if (user == null) throw StateError('Not signed in.');
    final userDocument = _users.doc(user.uid);
    final firestore = FirebaseFirestore.instance;
    final requestedLrn = lrn?.trim();
    final requestedGrade = grade?.trim();

    if (requestedLrn != null && !RegExp(r'^\d{12}$').hasMatch(requestedLrn)) {
      throw ArgumentError('LRN must contain exactly 12 digits.');
    }

    late final DocumentSnapshot<Map<String, dynamic>> initialSnapshot;
    try {
      initialSnapshot = await userDocument.get();
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Firestore profile preflight read failed '
        '(uid=${user.uid}, path=${userDocument.path}, '
        'plugin=${error.plugin}, code=${error.code}, '
        'message=${error.message ?? '(none)'}).',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
    final initialData = initialSnapshot.data();
    final existingLrn = initialData?['lrn']?.toString() ?? '';

    if (requestedLrn != null &&
        initialSnapshot.exists &&
        requestedLrn != existingLrn) {
      if (kDebugMode) {
        debugPrint(
          'Firestore profile transaction started '
          '(uid=${user.uid}, path=${userDocument.path}, '
          'fields=[name,address,grade,lrn], '
          'lrnChanged=true, role=${initialData?['role'] ?? '(missing)'}, '
          'status=${initialData?['status'] ?? '(missing)'}).',
        );
      }
      try {
        await firestore.runTransaction<void>((transaction) async {
          final userSnapshot = await transaction.get(userDocument);
          final userData = userSnapshot.data();
          if (!userSnapshot.exists || userData == null) {
            throw StateError('Student profile no longer exists.');
          }
          if (userData['role'] != 'student' ||
              userData['status'] != 'approved') {
            throw StateError('Only approved student profiles can be edited.');
          }

          final previousLrn = userData['lrn']?.toString() ?? '';
          final updates = <String, dynamic>{};
          if (userData['name'] != name) updates['name'] = name;
          if (userData['address'] != address) updates['address'] = address;
          if (requestedGrade != null && userData['grade'] != requestedGrade) {
            updates['grade'] = requestedGrade;
          }
          if (requestedLrn != previousLrn) updates['lrn'] = requestedLrn;
          DocumentReference<Map<String, dynamic>>? newIndex;
          DocumentReference<Map<String, dynamic>>? oldIndex;
          DocumentReference<Map<String, dynamic>>? oldHashedIndex;
          var oldIndexExists = false;
          var oldHashedIndexExists = false;
          var newIndexExists = false;
          if (requestedLrn != previousLrn) {
            if (!RegExp(r'^\d{12}$').hasMatch(previousLrn)) {
              throw StateError(
                'The saved LRN is invalid. Please contact your school administrator.',
              );
            }
            newIndex = firestore.collection('lrnIndexes').doc(requestedLrn);
            oldIndex = firestore.collection('lrnIndexes').doc(previousLrn);
            final hashedIndex = firestore.collection('lrnIndexes').doc(
                  sha256.convert(utf8.encode(requestedLrn)).toString(),
                );
            oldHashedIndex = firestore.collection('lrnIndexes').doc(
                  sha256.convert(utf8.encode(previousLrn)).toString(),
                );
            final newIndexSnapshot = await transaction.get(newIndex);
            final hashedIndexSnapshot = await transaction.get(hashedIndex);
            final oldIndexSnapshot = await transaction.get(oldIndex);
            final oldHashedIndexSnapshot =
                await transaction.get(oldHashedIndex);
            for (final snapshot in [
              newIndexSnapshot,
              hashedIndexSnapshot,
            ]) {
              if (snapshot.exists && snapshot.data()?['uid'] != user.uid) {
                throw StateError('This LRN is already assigned to a student.');
              }
            }
            if (oldIndexSnapshot.exists &&
                oldIndexSnapshot.data()?['uid'] != user.uid) {
              throw StateError('The current LRN index is inconsistent.');
            }
            if (oldHashedIndexSnapshot.exists &&
                oldHashedIndexSnapshot.data()?['uid'] != user.uid) {
              throw StateError('The current LRN index is inconsistent.');
            }
            oldIndexExists = oldIndexSnapshot.exists;
            oldHashedIndexExists = oldHashedIndexSnapshot.exists;
            newIndexExists = newIndexSnapshot.exists;
          }

          if (updates.isEmpty) return;
          if (updates.isNotEmpty) transaction.update(userDocument, updates);
          if (newIndex != null && oldIndex != null && oldHashedIndex != null) {
            if (!newIndexExists) {
              transaction.set(newIndex, {
                'uid': user.uid,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
            if (oldIndexExists) transaction.delete(oldIndex);
            if (oldHashedIndexExists) {
              transaction.delete(oldHashedIndex);
            }
          }
        });
      } on FirebaseException catch (error, stackTrace) {
        debugPrint(
          'Firestore profile transaction failed '
          '(uid=${user.uid}, path=${userDocument.path}, '
          'operation=profile-and-lrn-index-transaction, '
          'fields=[name,address,grade,lrn], plugin=${error.plugin}, '
          'code=${error.code}, message=${error.message ?? '(none)'}).',
        );
        debugPrintStack(stackTrace: stackTrace);
        rethrow;
      }
      return;
    }

    final updates = <String, dynamic>{'name': name, 'address': address};
    if (requestedGrade != null) updates['grade'] = requestedGrade;
    final currentData = initialData;
    if (currentData != null) {
      updates.removeWhere((key, value) => currentData[key] == value);
    }
    if (updates.isEmpty) return;

    try {
      await userDocument.update(updates);
      debugPrint(
        'Firestore profile fields update succeeded '
        '(uid=${user.uid}, fields=${updates.keys.toList()}).',
      );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Firestore profile fields update failed '
        '(uid=${user.uid}, path=${userDocument.path}, '
        'fields=${updates.keys.toList()}, '
        'plugin=${error.plugin}, code=${error.code}, '
        'message=${error.message ?? '(none)'}).',
      );
      debugPrintStack(stackTrace: stackTrace);
      await _logProfileSaveContext(
        user.uid,
        requestedName: name,
        requestedAddress: address,
      );
      rethrow;
    }
  }

  static Future<void> requestCurrentEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {
    final user = currentUser;
    if (user == null || user.email == null) throw StateError('Not signed in.');
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.verifyBeforeUpdateEmail(newEmail.trim());
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        '$_pendingEmailChangeKeyPrefix${user.uid}',
        newEmail.trim().toLowerCase(),
      );
    } catch (error, stackTrace) {
      debugPrint('Could not cache pending profile email change: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<String?> getPendingCurrentEmailChange() async {
    final user = currentUser;
    if (user == null) return null;
    final preferences = await SharedPreferences.getInstance();
    final pendingEmail = preferences.getString(
      '$_pendingEmailChangeKeyPrefix${user.uid}',
    );
    if (pendingEmail == null || pendingEmail.trim().isEmpty) return null;
    return pendingEmail.trim().toLowerCase();
  }

  static Future<void> syncVerifiedCurrentEmail() async {
    final user = currentUser;
    if (user == null) return;
    final preferences = await SharedPreferences.getInstance();
    final pendingEmail = preferences.getString(
      '$_pendingEmailChangeKeyPrefix${user.uid}',
    );
    if (pendingEmail == null || pendingEmail.isEmpty) return;
    await user.reload();
    final refreshedUser = currentUser;
    final email = refreshedUser?.email?.trim().toLowerCase();
    if (refreshedUser == null ||
        email == null ||
        email.isEmpty ||
        email != pendingEmail ||
        !refreshedUser.emailVerified) {
      return;
    }
    await refreshedUser.getIdToken(true);
    try {
      await _users.doc(refreshedUser.uid).update({'email': email});
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Firestore verified-email synchronization failed '
        '(uid=${refreshedUser.uid}, '
        'path=users/${refreshedUser.uid}, operation=update, '
        'fields=[email], plugin=${error.plugin}, code=${error.code}, '
        'message=${error.message ?? '(none)'}).',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
    await preferences.remove(
      '$_pendingEmailChangeKeyPrefix${refreshedUser.uid}',
    );
  }

  static Future<String?> getCurrentProfilePhotoData() async {
    final user = currentUser;
    if (user == null) throw StateError('Not signed in.');
    final snapshot = await _profilePhotoDocument(user.uid).get();
    final data = snapshot.data()?['data'];
    return data is String ? data : null;
  }

  static Future<void> updateCurrentProfilePhotoData(
    String? photoDataUrl,
  ) async {
    final user = currentUser;
    if (user == null) throw StateError('Not signed in.');
    final firestore = FirebaseFirestore.instance;
    final userDocument = _users.doc(user.uid);
    final photoDocument = _profilePhotoDocument(user.uid);
    final profilePhotoUrl = photoDataUrl == null || photoDataUrl.isEmpty
        ? ''
        : firestoreProfilePhotoUrl;
    final operations = <String>[
      'read ${userDocument.path}',
    ];
    try {
      await firestore.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userDocument);
        if (!userSnapshot.exists) {
          throw StateError('The current user profile no longer exists.');
        }

        final photoSnapshot = profilePhotoUrl.isEmpty
            ? await transaction.get(photoDocument)
            : null;
        if (userSnapshot.data()?['profilePhotoUrl'] != profilePhotoUrl) {
          transaction.update(userDocument, {
            'profilePhotoUrl': profilePhotoUrl,
          });
          operations.add(
            'update ${userDocument.path} fields=[profilePhotoUrl]',
          );
        }
        if (profilePhotoUrl.isEmpty) {
          if (photoSnapshot?.exists == true) {
            transaction.delete(photoDocument);
            operations.add('delete ${photoDocument.path}');
          }
        } else {
          transaction.set(photoDocument, {'data': photoDataUrl});
          operations.add('set ${photoDocument.path} fields=[data]');
        }
      });
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Firestore profile photo transaction failed '
        '(uid=${user.uid}, operations=${operations.join('; ')}; '
        'plugin=${error.plugin}, code=${error.code}, '
        'message=${error.message ?? '(none)'}).',
      );
      debugPrintStack(stackTrace: stackTrace);
      await _logProfileSaveContext(
        user.uid,
        requestedPhotoDataUrl: photoDataUrl,
      );
      rethrow;
    }
  }

  static Future<String> _getDeviceId() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_deviceIdKey);
    if (existing != null && existing.length >= 16) return existing;

    final random = Random.secure();
    final deviceId = List<int>.generate(
      32,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    await preferences.setString(_deviceIdKey, deviceId);
    return deviceId;
  }

  static Future<String> _claimLoginSession(String uid, String deviceId) {
    final sessionRef = _sessions.doc(uid);
    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(sessionRef);
      if (snapshot.exists) {
        final data = snapshot.data()!;
        if (data['deviceId'] != deviceId) {
          throw StateError(
            'This account is already active on another device. '
            'Sign out there first, or ask an admin to clear its session.',
          );
        }
        final existingSessionId = data['sessionId'];
        if (existingSessionId is! String || existingSessionId.isEmpty) {
          throw StateError(
            'This device session is incomplete. Ask an administrator to clear it.',
          );
        }
        return existingSessionId;
      }

      final sessionId = _generateSessionId();
      transaction.set(sessionRef, {
        'deviceId': deviceId,
        'sessionId': sessionId,
        'claimedAt': FieldValue.serverTimestamp(),
      });
      return sessionId;
    });
  }

  static String _generateSessionId() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static Future<void> _releaseLoginSession(
    String uid,
    String deviceId,
    String sessionId,
  ) async {
    final sessionRef = _sessions.doc(uid);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(sessionRef);
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      if (data['deviceId'] == deviceId && data['sessionId'] == sessionId) {
        transaction.delete(sessionRef);
      }
    });
  }

  static Future<void> signOut() async {
    final currentUid = _auth.currentUser?.uid;
    final uid = currentUid;
    invalidateCurrentVerifiedSession();
    try {
      final preferences = await SharedPreferences.getInstance();
      String? sessionId = uid == null
          ? null
          : preferences.getString('$_sessionIdKeyPrefix$uid');
      if (uid != null && _auth.currentUser != null) {
        final deviceId = await _getDeviceId();
        if (sessionId == null) {
          final snapshot = await _sessions.doc(uid).get();
          final data = snapshot.data();
          if (data?['deviceId'] == deviceId && data?['sessionId'] is String) {
            sessionId = data!['sessionId'] as String;
          }
        }
        if (sessionId != null) {
          await _releaseLoginSession(uid, deviceId, sessionId);
        }
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Unable to release the server session during sign-out; '
        'signing out locally: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (uid != null) {
        try {
          final preferences = await SharedPreferences.getInstance();
          await preferences.remove('$_sessionIdKeyPrefix$uid');
        } catch (error, stackTrace) {
          debugPrint('Unable to clear the local session marker: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
      await _auth.signOut();
    }
  }

  static Future<void> clearAccountLoginSession(String uid) async {
    await _sessions.doc(uid).delete();
  }
}
