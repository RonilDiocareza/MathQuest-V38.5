import 'package:flutter/material.dart';

/// Service to manage dialog state and prevent multiple dialogs from appearing simultaneously
class DialogService {
  static final DialogService _instance = DialogService._internal();

  factory DialogService() {
    return _instance;
  }

  DialogService._internal();

  bool _isDialogOpen = false;

  /// Check if a dialog is currently open
  bool get isDialogOpen => _isDialogOpen;

  /// Show a dialog safely - only if no dialog is currently open
  Future<T?> showSafeDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) async {
    if (_isDialogOpen) {
      return null; // Ignore if dialog already open
    }

    _isDialogOpen = true;

    try {
      final result = await showDialog<T>(
        context: context,
        builder: builder,
        barrierDismissible: barrierDismissible,
      );
      return result;
    } finally {
      _isDialogOpen = false;
    }
  }

  /// Reset dialog state (useful for error recovery)
  void reset() {
    _isDialogOpen = false;
  }
}
