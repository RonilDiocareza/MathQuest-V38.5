import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

Future<T> runFirestoreTransactionWithRetry<T>(
  FirebaseFirestore firestore,
  Future<T> Function(Transaction transaction) transactionHandler, {
  int maxAttempts = 3,
}) async {
  for (var attempt = 1;; attempt++) {
    try {
      return await firestore.runTransaction<T>(transactionHandler);
    } on FirebaseException catch (error) {
      final retryable = const {
        'aborted',
        'deadline-exceeded',
        'resource-exhausted',
        'unavailable',
      }.contains(error.code);
      if (!retryable || attempt >= maxAttempts) rethrow;
      await Future<void>.delayed(
        Duration(milliseconds: 250 * (1 << (attempt - 1))),
      );
    }
  }
}
