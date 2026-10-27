import 'dart:async';

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_progress_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/math_background.dart';
import '../worksheet_lesson_data.dart';

class ModuleLessonScreen extends StatefulWidget {
  final Map<String, String> module;
  final WorksheetModuleAccessLoader? loadModuleAccess;

  const ModuleLessonScreen({
    super.key,
    required this.module,
    this.loadModuleAccess,
  });

  @override
  State<ModuleLessonScreen> createState() => _ModuleLessonScreenState();
}

class _ModuleLessonScreenState extends State<ModuleLessonScreen>
    with WidgetsBindingObserver {
  bool _isCheckingAccess = true;
  bool _isUnlocked = false;
  bool _accessCheckFailed = false;
  int _accessRequest = 0;
  StreamSubscription<void>? _sessionInvalidationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionInvalidationSubscription =
        AuthService.sessionInvalidations.listen((_) {
      _accessRequest++;
      if (!mounted) return;
      setState(() {
        _isUnlocked = false;
        _accessCheckFailed = true;
        _isCheckingAccess = false;
      });
    });
    final moduleId = widget.module['id'];
    final moduleIndex =
        moduleId == null ? -1 : worksheetModuleIds.indexOf(moduleId);
    if (moduleIndex < 0) {
      _isCheckingAccess = false;
    } else {
      _verifyAccess(moduleIndex);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final moduleId = widget.module['id'];
      final moduleIndex =
          moduleId == null ? -1 : worksheetModuleIds.indexOf(moduleId);
      if (moduleIndex >= 0) {
        _verifyAccess(moduleIndex, refreshFromServer: true);
      }
    }
  }

  Future<void> _verifyAccess(
    int moduleIndex, {
    bool refreshFromServer = false,
  }) async {
    final request = ++_accessRequest;
    if (refreshFromServer && mounted) {
      setState(() => _isCheckingAccess = true);
    }
    try {
      final loadAccess = widget.loadModuleAccess ??
          UserProgressService.getWorksheetModuleAccess;
      final access = await loadAccess(
        refreshFromServer: refreshFromServer,
      );
      if (!mounted || request != _accessRequest) return;
      setState(() {
        _isUnlocked = access.canOpenModule(moduleIndex + 1);
        _accessCheckFailed = !access.sessionVerified;
        _isCheckingAccess = false;
      });
    } catch (error, stackTrace) {
      if (request != _accessRequest) return;
      debugPrint('Unable to verify module access: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _accessCheckFailed = true;
        _isCheckingAccess = false;
      });
    }
  }

  @override
  void dispose() {
    _accessRequest++;
    unawaited(_sessionInvalidationSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess) {
      return Scaffold(
        body: MathBackground(
          child: SafeArea(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );
    }
    if (!_isUnlocked) {
      return Scaffold(
        body: MathBackground(
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, color: Colors.white, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _accessCheckFailed
                          ? 'Could not verify module access. Please try again.'
                          : 'This module is locked. Complete the required stages first.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 20),
                    CustomButton(
                      text: 'Back',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final lessons = worksheetLessons
        .where((lesson) => lesson.moduleId == widget.module['id'])
        .toList(growable: false);

    return Scaffold(
      body: MathBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 48),
                    Expanded(
                      child: Text(
                        widget.module['name']!,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final lesson in lessons)
                          _LessonPanel(
                            title: lesson.title,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lesson.objective,
                                  textAlign: TextAlign.justify,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  lesson.explanation,
                                  textAlign: TextAlign.justify,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Worked Example',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lesson.example,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2B3B5A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lesson.solution,
                                  textAlign: TextAlign.justify,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Practice',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lesson.practice,
                                  textAlign: TextAlign.justify,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: CustomButton(
                    text: 'Back',
                    width: double.infinity,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LessonPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _LessonPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3D5AA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          DefaultTextStyle(
            style: const TextStyle(
              color: Color(0xFF5F6670),
              fontSize: 15,
              height: 1.4,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}
