import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/screens/login_screen.dart';

void main() {
  testWidgets('Forgot Password opens and closes student instructions',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    expect(find.text('Forgot Your Password?'), findsOneWidget);
    expect(
      find.text(
        'Please ask your teacher or school administrator for help resetting your password. A password reset link can be sent to your registered email address.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Got It'));
    await tester.pumpAndSettle();

    expect(find.text('Forgot Your Password?'), findsNothing);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });
}
