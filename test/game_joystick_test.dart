import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/widgets/game_joystick.dart';

void main() {
  testWidgets('floating joystick follows drag and hides on release',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    final directions = <Offset>[];
    var endCount = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FloatingGameJoystick(
          size: 120,
          onJoystickChanged: directions.add,
          onJoystickEnd: () => endCount++,
          child: const ColoredBox(color: Colors.green),
        ),
      ),
    ));
    await tester.pump();

    final gesture = await tester.startGesture(const Offset(180, 300));
    await tester.pump();

    var joystick =
        tester.getRect(find.byKey(const ValueKey('floating-joystick')));
    expect(joystick.center, const Offset(180, 300));
    expect(endCount, 0);

    await gesture.moveTo(const Offset(180, 240));
    await tester.pump();
    expect(directions.last.dy, closeTo(-1, 0.01));
    expect(directions.last.dx, closeTo(0, 0.01));

    await gesture.up();
    await tester.pump();
    expect(find.byKey(const ValueKey('floating-joystick')), findsNothing);
    expect(endCount, 1);

    final nextGesture = await tester.startGesture(const Offset(90, 500));
    await tester.pump();
    joystick = tester.getRect(find.byKey(const ValueKey('floating-joystick')));
    expect(joystick.center, const Offset(90, 500));
    await nextGesture.cancel();
    await tester.pump();
    expect(endCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ignores secondary touches while the joystick is held',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    final directions = <Offset>[];
    var endCount = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FloatingGameJoystick(
          onJoystickChanged: directions.add,
          onJoystickEnd: () => endCount++,
          child: const ColoredBox(color: Colors.green),
        ),
      ),
    ));

    final primary = await tester.startGesture(const Offset(100, 200));
    final secondary = await tester.startGesture(
      const Offset(300, 400),
      pointer: 2,
    );
    await tester.pump();
    await secondary.moveTo(const Offset(330, 400));
    await tester.pump();
    expect(directions, [Offset.zero]);
    await secondary.up();
    expect(endCount, 0);
    await primary.moveTo(const Offset(100, 140));
    await tester.pump();
    expect(directions.last.dy, closeTo(-1, 0.01));
    await primary.up();
    await tester.pump();
    expect(endCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('floats at touch position on phone and landscape tablet',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final size in [
      const Size(360, 800),
      const Size(1024, 768),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FloatingGameJoystick(
            onJoystickChanged: (_) {},
            onJoystickEnd: () {},
            child: const ColoredBox(color: Colors.green),
          ),
        ),
      ));

      final touchPosition = Offset(size.width * 0.65, size.height * 0.55);
      final gesture = await tester.startGesture(touchPosition);
      await tester.pump();
      expect(
        tester.getRect(find.byKey(const ValueKey('floating-joystick'))).center,
        touchPosition,
      );
      await gesture.cancel();
      await tester.pump();
      expect(find.byKey(const ValueKey('floating-joystick')), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('interactive controls above the game do not start joystick',
      (tester) async {
    var moveCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: FloatingGameJoystick(
                onJoystickChanged: (_) => moveCount++,
                onJoystickEnd: () {},
                child: const ColoredBox(color: Colors.green),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Menu'),
              ),
            ),
          ],
        ),
      ),
    ));

    await tester.tap(find.text('Menu'));
    await tester.pump();
    expect(moveCount, 0);
    expect(find.byKey(const ValueKey('floating-joystick')), findsNothing);
  });
}
