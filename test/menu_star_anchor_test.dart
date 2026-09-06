import 'package:bottled_star/ui/menu/menu_atmosphere.dart';
import 'package:bottled_star/ui/menu/star_anchored_scroller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MenuStarGeometry', () {
    test('places the core at 50% x, 42% y', () {
      const size = Size(400, 800);
      final geo = MenuStarGeometry.of(size);
      expect(geo.center.dx, 200);
      expect(geo.center.dy, 336);
      expect(geo.rimRadius, closeTo(400 * 0.28, 0.001));
      expect(geo.coreRadius, closeTo(400 * 0.38, 0.001));
    });
  });

  group('StarAnchoredScroller', () {
    testWidgets('centers the child on the bottled-star core', (tester) async {
      const size = Size(400, 800);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      const childKey = Key('mode-block');
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: size),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: StarAnchoredScroller(
              padding: EdgeInsets.zero,
              child: SizedBox(key: childKey, height: 200, width: 100),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final box = tester.renderObject<RenderBox>(find.byKey(childKey));
      final offset = box.localToGlobal(Offset.zero);
      final geo = MenuStarGeometry.of(size);
      expect(offset.dy + 100, closeTo(geo.center.dy, 1.5));
    });

    testWidgets('keeps the same core anchor on a taller tablet', (
      tester,
    ) async {
      const size = Size(800, 1200);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      const childKey = Key('mode-block');
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: size),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: StarAnchoredScroller(
              padding: EdgeInsets.zero,
              child: SizedBox(key: childKey, height: 200, width: 100),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final box = tester.renderObject<RenderBox>(find.byKey(childKey));
      final offset = box.localToGlobal(Offset.zero);
      final geo = MenuStarGeometry.of(size);
      expect(offset.dy + 100, closeTo(geo.center.dy, 1.5));
    });
  });
}
