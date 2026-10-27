import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/screens/profile_screen.dart';
import 'package:flutter_mathquest/widgets/teacher_profile_avatar.dart';

void main() {
  test('maps only explicit supported genders to teacher avatar assets', () {
    expect(
      teacherAvatarAssetForGender('Female'),
      'assets/images/teacher/female_teacher.png',
    );
    expect(
      teacherAvatarAssetForGender(' male '),
      'assets/images/teacher/male_teacher.png',
    );
    expect(teacherAvatarAssetForGender(null), isNull);
    expect(teacherAvatarAssetForGender('unspecified'), isNull);
  });

  testWidgets('uses neutral avatar when gender is missing', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: TeacherProfileAvatar(gender: ''),
      ),
    ));

    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
  });

  testWidgets('renders the supplied avatar for an explicit gender',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: TeacherProfileAvatar(gender: 'Female'),
      ),
    ));

    final avatarImage = tester.widget<Image>(find.byType(Image));
    expect(
      avatarImage.image,
      isA<AssetImage>().having(
        (image) => image.assetName,
        'assetName',
        'assets/images/teacher/female_teacher.png',
      ),
    );
  });

  testWidgets('renders both registered gender avatars on phone and desktop',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final size in [const Size(360, 800), const Size(1440, 900)]) {
      tester.view.physicalSize = size;
      for (final entry in {
        'Female': 'assets/images/teacher/female_teacher.png',
        'Male': 'assets/images/teacher/male_teacher.png',
      }.entries) {
        final asset = await rootBundle.load(entry.value);
        expect(asset.lengthInBytes, greaterThan(0));

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Center(
              child: TeacherProfileAvatar(
                gender: entry.key,
                size: 54,
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        final avatarImage = tester.widget<Image>(find.byType(Image));
        expect(
          avatarImage.image,
          isA<AssetImage>().having(
            (image) => image.assetName,
            'assetName',
            entry.value,
          ),
        );
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('custom profile photo takes priority over gender avatar',
      (tester) async {
    final data = await rootBundle.load('assets/images/Icon/Icon.png');
    final customPhoto = data.buffer.asUint8List();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TeacherProfileAvatar(
          gender: 'Male',
          photoBytes: customPhoto,
        ),
      ),
    ));

    final avatarImage = tester.widget<Image>(find.byType(Image));
    expect(avatarImage.image, isA<MemoryImage>());
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('teacher profile popup shows gender avatar and teacher role',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProfileScreen(
          isDialog: true,
          initialProfile: const {
            'name': 'Math Teacher',
            'email': 'teacher@example.com',
            'role': 'teacher',
            'gender': 'Male',
            'profilePhotoUrl': '',
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final avatarImage = tester.widget<Image>(find.byType(Image));
    expect(
      avatarImage.image,
      isA<AssetImage>().having(
        (image) => image.assetName,
        'assetName',
        'assets/images/teacher/male_teacher.png',
      ),
    );
    expect(find.text('Role'), findsOneWidget);
    expect(find.text('Teacher'), findsOneWidget);
    expect(find.text('Grade'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
