import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/screens/register_screen.dart';

Future<void> _enterValidRegistration(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  expect(fields, findsNWidgets(6));
  await tester.enterText(fields.at(0), '123456789012');
  await tester.enterText(fields.at(1), 'Student Name');
  await tester.enterText(fields.at(2), 'School Address');
  await tester.enterText(fields.at(3), 'student@example.com');
  await tester.enterText(fields.at(4), 'password123');
  await tester.enterText(fields.at(5), 'password123');
}

Widget _registrationApp({
  required StudentRegistrationHandler onRegister,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RegisterScreen(onRegister: onRegister),
              ),
            ),
            child: const Text('Open Registration'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('registration fields have persistent labels on phone and desktop',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final size in [const Size(320, 568), const Size(1510, 768)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
            home: RegisterScreen(
                onRegister: ({
          required email,
          required password,
          required name,
          required address,
          required lrn,
          required character,
        }) async {})),
      );
      await tester.pumpAndSettle();

      for (final label in [
        'LRN',
        'Name',
        'Address',
        'Email',
        'Password',
        'Confirm Password',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        find.text(
          'Please use an email address that you or your parent/guardian can access. This will help you recover your account if you forget your password.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('submits all registration details and selected character',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 900);

    Map<String, String>? submitted;
    await tester.pumpWidget(_registrationApp(
      onRegister: ({
        required email,
        required password,
        required name,
        required address,
        required lrn,
        required character,
      }) async {
        submitted = {
          'email': email,
          'password': password,
          'name': name,
          'address': address,
          'lrn': lrn,
          'character': character,
        };
      },
    ));
    await tester.tap(find.text('Open Registration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Girl'));
    await _enterValidRegistration(tester);
    final submitButton = find.text('Create Account').last;
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(submitted, {
      'email': 'student@example.com',
      'password': 'password123',
      'name': 'Student Name',
      'address': 'School Address',
      'lrn': '123456789012',
      'character': 'girl',
    });
    expect(
      find.textContaining('Account created. Wait for admin approval.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'shows actual Firebase Auth code and message on registration error',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 900);

    await tester.pumpWidget(_registrationApp(
      onRegister: ({
        required email,
        required password,
        required name,
        required address,
        required lrn,
        required character,
      }) async {
        throw FirebaseAuthException(
          code: 'operation-not-allowed',
          message: 'Email sign-in is disabled.',
        );
      },
    ));
    await tester.tap(find.text('Open Registration'));
    await tester.pumpAndSettle();
    await _enterValidRegistration(tester);
    final submitButton = find.text('Create Account').last;
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Registration failed (operation-not-allowed): Email sign-in is disabled.',
      ),
      findsOneWidget,
    );
    expect(find.text('Create Account'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows actual Firestore code and message on profile write error',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 900);

    await tester.pumpWidget(_registrationApp(
      onRegister: ({
        required email,
        required password,
        required name,
        required address,
        required lrn,
        required character,
      }) async {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'The registration profile failed rule validation.',
        );
      },
    ));
    await tester.tap(find.text('Open Registration'));
    await tester.pumpAndSettle();
    await _enterValidRegistration(tester);
    final submitButton = find.text('Create Account').last;
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Firestore denied profile creation (permission-denied): The registration profile failed rule validation.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
