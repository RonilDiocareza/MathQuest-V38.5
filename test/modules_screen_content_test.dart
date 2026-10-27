import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/services/auth_service.dart';
import 'package:flutter_mathquest/screens/module_lesson_screen.dart';
import 'package:flutter_mathquest/screens/modules_screen.dart';
import 'package:flutter_mathquest/screens/offline_practice_screen.dart';
import 'package:flutter_mathquest/services/user_progress_service.dart';
import 'package:flutter_mathquest/worksheet_lesson_data.dart';

UserProgress _progress(Set<int> completedLevels) => UserProgress(
      completedLevels: completedLevels.toList(),
      completedNpcQuestions: const [],
      unlockedLevels: 1,
      questAttempts: 0,
      maxUnlockedSubLevel: const {},
    );

WorksheetModuleAccess _moduleAccess({
  bool sessionVerified = true,
  Set<int> completedLevels = const {},
}) =>
    WorksheetModuleAccess(
      sessionVerified: sessionVerified,
      progress: _progress(completedLevels),
      usingCachedProgress: true,
    );

WorksheetModuleAccessLoader _moduleAccessLoader(
  WorksheetModuleAccess access,
) =>
    ({required refreshFromServer}) async => access;

void main() {
  testWidgets('Module 1 has one consistent state while access is checked',
      (tester) async {
    final accessCompleter = Completer<WorksheetModuleAccess>();
    await tester.pumpWidget(
      MaterialApp(
        home: ModulesScreen(
          loadModuleAccess: ({required refreshFromServer}) =>
              accessCompleter.future,
        ),
      ),
    );
    await tester.pump();

    final moduleOneCard = find.byKey(const ValueKey('module-card-1'));
    expect(
      find.descendant(
        of: moduleOneCard,
        matching: find.text('Checking access...'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: moduleOneCard, matching: find.text('Unlocked')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: moduleOneCard,
        matching: find.text('Locked — complete the required stages to unlock.'),
      ),
      findsNothing,
    );

    accessCompleter.complete(_moduleAccess());
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: moduleOneCard, matching: find.text('Unlocked')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: moduleOneCard,
        matching: find.text('Checking access...'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: moduleOneCard,
        matching: find.text('Locked — complete the required stages to unlock.'),
      ),
      findsNothing,
    );
  });

  testWidgets('verified module access survives a refresh using cached progress',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);

    var loadCount = 0;
    final serverRefresh = Completer<WorksheetModuleAccess>();
    final cachedAccess = _moduleAccess(completedLevels: {8});
    final refreshArguments = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ModulesScreen(
          loadModuleAccess: ({required refreshFromServer}) async {
            loadCount++;
            refreshArguments.add(refreshFromServer);
            if (refreshFromServer) return serverRefresh.future;
            return cachedAccess;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final moduleOneCard = find.byKey(const ValueKey('module-card-1'));
    expect(
      find.descendant(of: moduleOneCard, matching: find.text('Unlocked')),
      findsOneWidget,
    );
    expect(refreshArguments, [false]);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('module-card-2')),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(loadCount, greaterThanOrEqualTo(2));
    expect(refreshArguments, [false, true]);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('module-card-2')),
        matching: find.text('Unlocked'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Locked — complete the required stages to unlock.'),
      findsWidgets,
    );

    serverRefresh.complete(cachedAccess);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('module-card-2')),
        matching: find.text('Unlocked'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'verified module cache resolves initial access without server refresh',
      (tester) async {
    var observedRefreshFromServer = true;
    await tester.pumpWidget(
      MaterialApp(
        home: ModulesScreen(
          loadModuleAccess: ({required refreshFromServer}) async {
            observedRefreshFromServer = refreshFromServer;
            return _moduleAccess(completedLevels: {8});
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(observedRefreshFromServer, isFalse);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('module-card-1')),
        matching: find.text('Unlocked'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('module-card-2')),
        matching: find.text('Unlocked'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Practice to Modules navigation reuses verified access cache',
      (tester) async {
    final access = _moduleAccess(completedLevels: {8});
    final refreshArguments = <bool>[];
    Future<WorksheetModuleAccess> loadAccess({
      required bool refreshFromServer,
    }) async {
      refreshArguments.add(refreshFromServer);
      return access;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => OfflinePracticeScreen(
                          loadModuleAccess: loadAccess,
                        ),
                      ),
                    ),
                    child: const Text('Open Practice'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => ModulesScreen(
                          loadModuleAccess: loadAccess,
                        ),
                      ),
                    ),
                    child: const Text('Open Modules'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Practice'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('practice-topic-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Practice'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 10'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('practice-back-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Modules'));
    await tester.pumpAndSettle();

    expect(refreshArguments, [false, false]);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('module-card-1')),
        matching: find.text('Unlocked'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('module-card-2')),
        matching: find.text('Unlocked'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('module verification timeout exits checking without unlocking',
      (tester) async {
    final pendingAccess = Completer<WorksheetModuleAccess>();
    await tester.pumpWidget(
      MaterialApp(
        home: ModulesScreen(
          loadModuleAccess: ({required refreshFromServer}) =>
              pendingAccess.future,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Checking access...'), findsNWidgets(2));
    await tester.pump(const Duration(seconds: 21));

    expect(find.text('Checking access...'), findsNothing);
    expect(find.text('Access unavailable'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('module-card-1')),
        matching: find.text('Unlocked'),
      ),
      findsNothing,
    );
    pendingAccess.complete(_moduleAccess());
    await tester.pumpAndSettle();
  });

  testWidgets('confirmed session invalidation removes module access',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);

    await tester.pumpWidget(
      MaterialApp(
        home: ModulesScreen(
          loadModuleAccess: _moduleAccessLoader(
            _moduleAccess(completedLevels: {8}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('module-card-1')),
        matching: find.text('Unlocked'),
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('module-card-2')),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    AuthService.invalidateCurrentVerifiedSession();
    await tester.pumpAndSettle();

    for (final moduleNumber in [2, 1]) {
      if (moduleNumber == 1) {
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, 2000),
        );
        await tester.pumpAndSettle();
      }
      final card = find.byKey(ValueKey('module-card-$moduleNumber'));
      expect(
        find.descendant(of: card, matching: find.text('Unlocked')),
        findsNothing,
      );
      expect(
        find.descendant(of: card, matching: find.text('Access unavailable')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text('Module access could not be verified.'),
        ),
        findsOneWidget,
      );
    }
  });

  test('module access requires all sequential completion milestones', () {
    final newStudent = _progress({});
    expect(newStudent.isWorksheetModuleUnlocked(1), isTrue);
    expect(newStudent.worksheetModuleUnlockLabel(1), 'Unlocked');
    for (var module = 2; module <= 8; module++) {
      expect(newStudent.isWorksheetModuleUnlocked(module), isFalse);
    }
    expect(newStudent.worksheetModuleUnlockLabel(2), 'Complete Stage 1 - 8');
    expect(newStudent.worksheetModuleUnlockLabel(3), 'Complete Stage 1 - 15');
    expect(newStudent.worksheetModuleUnlockLabel(4), 'Complete Stage 1 - 20');
    expect(
      newStudent.worksheetModuleUnlockLabel(5),
      'Complete Stage 1',
    );
    expect(
      newStudent.worksheetModuleUnlockLabel(6),
      'Complete Stage 2 - 10',
    );
    expect(
      newStudent.worksheetModuleUnlockLabel(7),
      'Complete Stage 2 - 15',
    );
    expect(
      newStudent.worksheetModuleUnlockLabel(8),
      'Complete Stage 1 and Stage 2',
    );

    expect(_progress({7}).isWorksheetModuleUnlocked(2), isFalse);
    expect(_progress({8}).isWorksheetModuleUnlocked(2), isTrue);
    expect(_progress({15}).isWorksheetModuleUnlocked(3), isFalse);
    expect(_progress({8, 20}).isWorksheetModuleUnlocked(4), isFalse);
    expect(_progress({8}).isWorksheetModuleUnlocked(2), isTrue);
    expect(_progress({8, 15}).isWorksheetModuleUnlocked(3), isTrue);
    expect(_progress({8, 15, 20}).isWorksheetModuleUnlocked(4), isTrue);
    expect(_progress({8, 15, 20}).worksheetModuleUnlockLabel(4), 'Unlocked');
    expect(_progress({8, 15, 20}).isWorksheetModuleUnlocked(5), isFalse);
    expect(_progress({8, 15, 20, 25}).isWorksheetModuleUnlocked(5), isTrue);
    expect(
      _progress({8, 15, 20, 25}).isWorksheetModuleUnlocked(6),
      isFalse,
    );
    expect(
      _progress({8, 15, 20, 25, 30}).isWorksheetModuleUnlocked(6),
      isTrue,
    );
    expect(
      _progress({8, 15, 20, 25, 30}).isWorksheetModuleUnlocked(7),
      isFalse,
    );
    expect(
      _progress({8, 15, 20, 25, 30, 35}).isWorksheetModuleUnlocked(7),
      isTrue,
    );

    final throughModuleSeven = {8, 15, 20, 25, 30, 35};
    expect(
      _progress({...throughModuleSeven, 41}).isWorksheetModuleUnlocked(8),
      isFalse,
    );
    expect(
      _progress({...throughModuleSeven, 42}).isWorksheetModuleUnlocked(8),
      isFalse,
    );
    expect(
      _progress({...throughModuleSeven, 41, 42}).isWorksheetModuleUnlocked(8),
      isTrue,
    );
    expect(
      _progress({...throughModuleSeven, 41, 42}).worksheetModuleUnlockLabel(8),
      'Unlocked',
    );
    expect(
        _progress({8, 15, 20, 25, 30, 35, 41, 42}).isWorksheetModuleUnlocked(8),
        isTrue);
    expect(newStudent.isWorksheetModuleUnlocked(0), isFalse);
    expect(newStudent.isWorksheetModuleUnlocked(9), isFalse);
  });

  testWidgets('locked modules cannot be opened from the Modules screen',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);

    expect(worksheetTitles, hasLength(67));
    expect(
      worksheetTitles.take(3),
      [
        'Adding Similar Fractions',
        'Subtracting Similar Fractions',
        'Adding and Subtracting Mixed Numbers',
      ],
    );
    expect(worksheetTitles.last, 'Dividing Integers');
    for (var moduleIndex = 0;
        moduleIndex < worksheetModuleIds.length;
        moduleIndex++) {
      final moduleLessons = worksheetLessons
          .where((lesson) => lesson.moduleId == worksheetModuleIds[moduleIndex])
          .toList();
      expect(moduleLessons, isNotEmpty);
      expect(
        moduleLessons.every(
          (lesson) => worksheetModuleIndex(lesson.number) == moduleIndex,
        ),
        isTrue,
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: ModulesScreen(
          loadModuleAccess: _moduleAccessLoader(_moduleAccess()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unlocked'), findsOneWidget);

    for (var moduleIndex = 1;
        moduleIndex < worksheetModuleNames.length;
        moduleIndex++) {
      final moduleName = worksheetModuleNames[moduleIndex];
      await tester.scrollUntilVisible(
        find.text(moduleName),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(moduleName));
      await tester.pumpAndSettle();
      expect(find.byType(ModulesScreen), findsOneWidget);
      expect(find.text('Locked — complete the required stages to unlock.'),
          findsWidgets);
      expect(
        find.text(
          UserProgress.worksheetModuleRequirementLabel(moduleIndex + 1),
        ),
        findsOneWidget,
      );
    }
    final navigator = Navigator.of(tester.element(find.byType(ModulesScreen)));
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ModuleLessonScreen(
            module: {
              'id': worksheetModuleIds[1],
              'name': worksheetModuleNames[1],
            },
            loadModuleAccess: _moduleAccessLoader(_moduleAccess()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('This module is locked. Complete the required stages first.'),
      findsOneWidget,
    );
    expect(find.text('Worked Example'), findsNothing);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.tap(find.text(worksheetModuleNames.first));
    await tester.pumpAndSettle();
    expect(find.byType(ModuleLessonScreen), findsOneWidget);
    expect(find.text(worksheetLessons.first.title), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('previously unlocked local module content remains accessible',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);

    await tester.pumpWidget(
      MaterialApp(
        home: ModulesScreen(
          loadModuleAccess: _moduleAccessLoader(
            _moduleAccess(completedLevels: {8}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(worksheetModuleNames[1]));
    await tester.tap(find.text(worksheetModuleNames[1]));
    await tester.pumpAndSettle();

    expect(find.byType(ModuleLessonScreen), findsOneWidget);
    expect(
      find.text(
        worksheetLessons
            .firstWhere((lesson) => lesson.moduleId == worksheetModuleIds[1])
            .title,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('unverified sessions cannot open even Module 1', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);

    await tester.pumpWidget(
      MaterialApp(
        home: ModulesScreen(
          loadModuleAccess: _moduleAccessLoader(
            _moduleAccess(sessionVerified: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(worksheetModuleNames.first));
    await tester.tap(find.text(worksheetModuleNames.first));
    await tester.pumpAndSettle();

    expect(find.byType(ModuleLessonScreen), findsNothing);
  });

  testWidgets('direct module route also denies an unverified session',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ModuleLessonScreen(
          module: {
            'id': worksheetModuleIds.first,
            'name': worksheetModuleNames.first,
          },
          loadModuleAccess: _moduleAccessLoader(
            _moduleAccess(sessionVerified: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Worked Example'), findsNothing);
    expect(
      find.text('Could not verify module access. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('open lesson closes when the verified session is invalidated',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ModuleLessonScreen(
          module: {
            'id': worksheetModuleIds.first,
            'name': worksheetModuleNames.first,
          },
          loadModuleAccess: _moduleAccessLoader(_moduleAccess()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Worked Example'), findsWidgets);

    AuthService.invalidateCurrentVerifiedSession();
    await tester.pumpAndSettle();

    expect(find.text('Worked Example'), findsNothing);
    expect(
      find.text('Could not verify module access. Please try again.'),
      findsOneWidget,
    );
  });

  test('module access requires a verified session before checking unlocks', () {
    final access = _moduleAccess(
      sessionVerified: false,
      completedLevels: {8},
    );
    expect(access.canOpenModule(1), isFalse);
    expect(access.canOpenModule(2), isFalse);
  });
}
