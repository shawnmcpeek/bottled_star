import 'package:bottled_star/game/systems/first_run_guide.dart';
import 'package:bottled_star/ui/howto/how_to_play_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// iPhone SE 3 logical size (also SE 2). Status bar is 20pt, no home indicator.
const _seSize = Size(375, 667);
const _sePadding = EdgeInsets.only(top: 20);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: _seSize, padding: _sePadding),
        child: Scaffold(body: child),
      ),
    );
  }

  testWidgets('Skip is tappable on iPhone SE over an opaque game surface', (
    tester,
  ) async {
    tester.view.physicalSize = _seSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var skipped = 0;
    var gameTapped = 0;
    var leaveTapped = 0;
    final guide = FirstRunGuide(onCompleted: () {});

    await tester.pumpWidget(
      wrap(
        Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => gameTapped++,
                child: const ColoredBox(color: Color(0xFF050308)),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => leaveTapped++,
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            HowToPlayOverlay(guide: guide, onSkip: () => skipped++),
          ],
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(HowToPlayOverlay.skipButtonKey));
    await tester.pump();

    expect(skipped, 1);
    expect(gameTapped, 0);
    expect(leaveTapped, 0);

    guide.dispose();
  });

  testWidgets('Skip hit box is below the SE status bar', (tester) async {
    tester.view.physicalSize = _seSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var skipped = 0;
    final guide = FirstRunGuide(onCompleted: () {});

    await tester.pumpWidget(
      wrap(HowToPlayOverlay(guide: guide, onSkip: () => skipped++)),
    );
    await tester.pump();

    final box = tester.getRect(find.byKey(HowToPlayOverlay.skipButtonKey));
    expect(box.top, greaterThanOrEqualTo(28));
    expect(box.height, greaterThanOrEqualTo(HowToPlayOverlay.skipExtent));
    expect(box.width, greaterThanOrEqualTo(HowToPlayOverlay.skipExtent));
    expect(box.left, lessThan(_seSize.width / 2));

    await tester.tapAt(box.center);
    await tester.pump();
    expect(skipped, 1);

    guide.dispose();
  });

  testWidgets('taps on the tip caption pass through to the game', (
    tester,
  ) async {
    tester.view.physicalSize = _seSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var skipped = 0;
    var gameTapped = 0;
    final guide = FirstRunGuide(onCompleted: () {});

    await tester.pumpWidget(
      wrap(
        Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => gameTapped++,
                child: const ColoredBox(color: Color(0xFF050308)),
              ),
            ),
            HowToPlayOverlay(guide: guide, onSkip: () => skipped++),
          ],
        ),
      ),
    );
    await tester.pump();

    await tester.tapAt(const Offset(187.5, 400));
    await tester.pump();

    expect(gameTapped, 1);
    expect(skipped, 0);

    guide.dispose();
  });
}
