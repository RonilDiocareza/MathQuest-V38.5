import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/main.dart';
import 'package:flutter_mathquest/screens/home_screen.dart';
import 'package:flutter_mathquest/screens/landing_screen.dart';
import 'package:flutter_mathquest/screens/login_screen.dart';

void main() {
  testWidgets(
      'app fails closed when startup session verification is unavailable',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Could not verify your saved sign-in session. '
        'Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(LandingScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landing screen adapts to phone, tablet, and wide layouts',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final size in [
      const Size(320, 568),
      const Size(768, 1024),
      const Size(1510, 900),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        const MaterialApp(home: LandingScreen(role: 'student')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Play'), findsOneWidget);
      expect(find.text('About Us'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final label in ['Play', 'About Us']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
      }
    }
  });

  testWidgets('Play opens the existing Home Screen', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LandingScreen(role: 'student')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('student-only actions are hidden for other and missing roles',
      (tester) async {
    for (final role in <String?>[
      'teacher',
      'admin',
      null,
      'unrecognized',
    ]) {
      await tester.pumpWidget(
        MaterialApp(home: LandingScreen(role: role)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Play'), findsNothing, reason: 'role=$role');
      expect(find.text('About Us'), findsNothing, reason: 'role=$role');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Home icon returns to the post-login landing screen',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    final icon = find.byKey(const ValueKey('home-navigation'));
    expect(icon, findsOneWidget);
    final iconRect = tester.getRect(icon);
    final logoRect = tester
        .getRect(find.image(const AssetImage('assets/images/Icon/Icon2.png')));
    final profileRect = tester
        .getRect(find.image(const AssetImage('assets/images/player/boy.png')));
    expect(iconRect.center.dy, closeTo(logoRect.center.dy, 1));
    expect(iconRect.right, lessThan(logoRect.left));
    expect(logoRect.right, lessThan(profileRect.left));

    await tester.tap(icon);
    await tester.pumpAndSettle();

    expect(find.byType(LandingScreen), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('About Us'), findsOneWidget);
  });

  testWidgets('About Us explains the game and Back returns to landing',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);

    await tester.pumpWidget(
      const MaterialApp(home: LandingScreen(role: 'student')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('About Us'));
    await tester.pumpAndSettle();

    expect(find.text('About MathQuest'), findsOneWidget);
    expect(find.text('MathQuest'), findsOneWidget);
    expect(find.text('About the App'), findsOneWidget);
    expect(find.text('Purpose of MathQuest'), findsOneWidget);
    const purposeText =
        'MathQuest aims to make learning mathematics more engaging and enjoyable through interactive gameplay, questions, and challenges. It helps students improve their mathematical knowledge, accuracy, and problem-solving skills while combining education and entertainment in a game-based learning experience. MathQuest is primarily designed for Grade 7 students who want to practice and improve their mathematics skills, and teachers can also use it as a supplementary learning activity.';
    expect(find.text('Who Is the Game For?'), findsNothing);
    expect(find.text(purposeText), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(purposeText)).textAlign,
      TextAlign.justify,
    );
    expect(find.text('How to Use MathQuest'), findsOneWidget);
    expect(find.text('Developers'), findsOneWidget);
    expect(find.text('Rhodney F. Nano'), findsOneWidget);
    expect(find.text('Jeziel A. Gabac'), findsOneWidget);
    expect(find.text('Ronil F. Diocareza'), findsOneWidget);
    expect(find.text('Thesis Adviser'), findsOneWidget);
    expect(find.text('Mr. Jomari Launio'), findsOneWidget);
    expect(find.text('Technical Critic'), findsOneWidget);
    expect(find.text('Ms. Dezza Anne A. Peregrina'), findsOneWidget);
    expect(find.textContaining('Grade 7 students'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(
      find.textContaining('Review scores and learning progress'),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final avatars = find.byType(CircleAvatar);
    expect(avatars, findsNWidgets(5));
    const profileImages = [
      'assets/about_us/Rhodney.jfif',
      'assets/about_us/Jeziel.jfif',
      'assets/about_us/Ronil.png',
      'assets/about_us/Jomari.jpg',
      'assets/about_us/Dezza.jpg',
    ];
    for (var index = 0; index < profileImages.length; index++) {
      final avatar = tester.widget<CircleAvatar>(avatars.at(index));
      expect(avatar.backgroundImage, isA<AssetImage>());
      expect(
        (avatar.backgroundImage! as AssetImage).assetName,
        profileImages[index],
      );
    }
    expect(tester.getRect(avatars.at(0)).width, greaterThan(0));
    expect(
      tester.getRect(avatars.at(0)).center.dx,
      lessThan(tester.getRect(avatars.at(1)).center.dx),
    );
    expect(
      tester.getRect(avatars.at(1)).center.dx,
      lessThan(tester.getRect(avatars.at(2)).center.dx),
    );
    expect(
      tester.getRect(avatars.at(3)).center.dy,
      closeTo(tester.getRect(avatars.at(4)).center.dy, 1),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('about-back')));
    await tester.pumpAndSettle();

    expect(find.text('Play'), findsOneWidget);
    expect(find.text('About Us'), findsOneWidget);
    expect(find.byType(AboutUsScreen), findsNothing);
  });

  testWidgets('About Us profile images load across screen sizes',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    const profileImages = [
      'assets/about_us/Rhodney.jfif',
      'assets/about_us/Jeziel.jfif',
      'assets/about_us/Ronil.png',
      'assets/about_us/Jomari.jpg',
      'assets/about_us/Dezza.jpg',
    ];

    for (final size in [
      const Size(320, 568),
      const Size(768, 1024),
      const Size(1510, 900),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(const MaterialApp(home: AboutUsScreen()));
      await tester.pumpAndSettle();

      final avatars = find.byType(CircleAvatar);
      expect(avatars, findsNWidgets(profileImages.length));
      for (var index = 0; index < profileImages.length; index++) {
        final avatar = tester.widget<CircleAvatar>(avatars.at(index));
        expect(
          (avatar.backgroundImage! as AssetImage).assetName,
          profileImages[index],
        );
        expect(tester.getRect(avatars.at(index)).width, greaterThan(0));
      }
      expect(find.text('Institution'), findsOneWidget);
      expect(
        find.text(
          'Cavite State University Naic – BS Information Technology',
        ),
        findsOneWidget,
      );
      expect(find.text('Version 1.0.0'), findsOneWidget);
      expect(
          find.text('© 2026 MathQuest. All Rights Reserved.'), findsOneWidget);
      final logo = find.image(const AssetImage('assets/about_us/CVSU.png'));
      expect(logo, findsOneWidget);
      expect(tester.getSize(logo), const Size(36, 36));
      expect(tester.takeException(), isNull);
    }
  });
}
