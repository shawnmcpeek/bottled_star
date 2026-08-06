import 'dart:math' as math;

import 'package:bottled_star/game/constants.dart';
import 'package:bottled_star/game/systems/supernova_blast.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupernovaBlast lobe', () {
    test('peaks on blast axis and dips opposite', () {
      final origin = Vector2.zero();
      const axis = 0.0; // +X
      final strong = SupernovaBlast.lobe(Vector2(100, 0), origin, axis);
      final weak = SupernovaBlast.lobe(Vector2(-100, 0), origin, axis);
      expect(strong, closeTo(1.0 + GameConstants.kAsymmetry, 1e-9));
      expect(weak, closeTo(1.0 - GameConstants.kAsymmetry, 1e-9));
    });

    test('near-origin returns strong lobe', () {
      expect(
        SupernovaBlast.lobe(Vector2.zero(), Vector2.zero(), math.pi / 3),
        closeTo(1.0 + GameConstants.kAsymmetry, 1e-9),
      );
    });
  });

  group('SupernovaBlast classify', () {
    test('deep core always ejects', () {
      expect(
        SupernovaBlast.classify(dist: 10, lobeFactor: 1.0, softRoll: 0.99),
        'eject',
      );
    });

    test('beyond lobed blast is untouched', () {
      expect(
        SupernovaBlast.classify(
          dist: GameConstants.kBlastRadius * 1.2,
          lobeFactor: 1.0,
          softRoll: 0.0,
        ),
        'none',
      );
    });

    test('outer zone pushes', () {
      final vaporize = GameConstants.kVaporizeRadius;
      expect(
        SupernovaBlast.classify(
          dist: vaporize * 1.5,
          lobeFactor: 1.0,
          softRoll: 0.0,
        ),
        'push',
      );
    });

    test('soft edge favors eject near inner band', () {
      final vaporize = GameConstants.kVaporizeRadius;
      final soft = GameConstants.kSoftEdge;
      final dist = vaporize * (1 - soft) + 1;
      expect(
        SupernovaBlast.classify(dist: dist, lobeFactor: 1.0, softRoll: 0.99),
        'eject',
      );
      expect(
        SupernovaBlast.classify(dist: dist, lobeFactor: 1.0, softRoll: 0.0),
        'push',
      );
    });

    test('eject credit is a quarter of piece value', () {
      expect((100 * GameConstants.kEjectCredit).round(), 25);
      expect((45 * GameConstants.kEjectCredit).round(), 11);
      expect((1 * GameConstants.kEjectCredit).round(), 0);
    });
  });
}
