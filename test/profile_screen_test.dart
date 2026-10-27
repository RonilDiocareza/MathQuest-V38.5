import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/screens/profile_screen.dart';

void main() {
  testWidgets('pending email change and synchronization retry are restored',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(
          initialProfile: {
            'name': 'Student Name',
            'email': 'student@example.com',
            'role': 'student',
            'grade': 'Grade 7',
            'lrn': '001234567890',
            'address': 'School',
            'pendingEmailAddress': 'new-student@example.com',
            'emailSyncError':
                'Could not confirm and synchronize your pending email change. '
                    'Check your connection and retry.',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Verify the link sent to new-student@example.com to finish updating '
        'your email.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Could not confirm and synchronize'),
      findsOneWidget,
    );
    expect(find.text('Retry email sync'), findsOneWidget);
  });

  testWidgets('student profile edit exposes requested fields and cancel works',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(
          initialProfile: {
            'name': 'Student Name',
            'email': 'student@example.com',
            'role': 'student',
            'grade': 'Grade 7',
            'lrn': '001234567890',
            'address': 'School',
            'character': 'boy',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(4));
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('Grade 7'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).at(1),
      'not-an-email',
    );
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(
      find.text(
          'Check your name, address, email, and 12-digit LRN before saving.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byType(TextField).at(1),
      'student@example.com',
    );
    await tester.enterText(
      find.byType(TextField).at(2),
      '12345678901',
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(
      find.text(
          'Check your name, address, email, and 12-digit LRN before saving.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('student@example.com'), findsOneWidget);
    expect(find.text('001234567890'), findsOneWidget);
    expect(find.text('School'), findsOneWidget);
  });

  testWidgets(
      'password confirmation is safe on mobile and desktop profile dialogs',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final viewport in [const Size(400, 800), const Size(1280, 900)]) {
      tester.view.physicalSize = viewport;
      tester.view.viewInsets = FakeViewPadding.zero;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => Dialog(
                        child: ProfileScreen(
                          isDialog: true,
                          initialProfile: const {
                            'name': 'Student Name',
                            'email': 'student@example.com',
                            'role': 'student',
                            'grade': 'Grade 7',
                            'lrn': '001234567890',
                            'address': 'School',
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('Open profile'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open profile'));
      await tester.pumpAndSettle();

      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.tap(find.text('Edit Profile'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).at(1),
          'new-student@example.com',
        );
        if (viewport.width < 600) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          await tester.pump();
        }
        await tester.ensureVisible(find.text('Save Changes'));
        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();

        expect(find.text('Confirm It Is You'), findsOneWidget);
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Cancel').last);
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
      }

      await tester.ensureVisible(find.text('Close'));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
