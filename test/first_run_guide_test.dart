import 'package:bottled_star/game/element_tier.dart';
import 'package:bottled_star/game/systems/first_run_guide.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirstRunGuide', () {
    test('advances inject → fuse → sink on shot and merge', () {
      var completed = 0;
      final guide = FirstRunGuide(onCompleted: () => completed++);

      expect(guide.step.value, FirstRunStep.inject);
      guide.onShotFired();
      expect(guide.step.value, FirstRunStep.fuse);
      guide.onMerge();
      expect(guide.step.value, FirstRunStep.sink);
      expect(completed, 0);

      guide.dispose();
    });

    test('silicon unlock moves sink → iron', () {
      final guide = FirstRunGuide(onCompleted: () {});
      guide
        ..onShotFired()
        ..onMerge()
        ..onTierReached(ElementTier.silicon);
      expect(guide.step.value, FirstRunStep.iron);
      guide.dispose();
    });

    test('rim pressure after iron shows containment', () {
      final guide = FirstRunGuide(onCompleted: () {});
      guide
        ..onShotFired()
        ..onMerge()
        ..onTierReached(ElementTier.silicon)
        ..onRimPressure(0.3);
      expect(guide.step.value, FirstRunStep.containment);
      guide.dispose();
    });

    test('skip finishes immediately', () {
      var completed = 0;
      final guide = FirstRunGuide(onCompleted: () => completed++);
      guide.skip();
      expect(guide.step.value, FirstRunStep.done);
      expect(guide.tipText.value, isNull);
      expect(completed, 1);
      guide.skip();
      expect(completed, 1);
      guide.dispose();
    });
  });
}
