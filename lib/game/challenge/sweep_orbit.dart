import 'dart:math' as math;

/// Kinematic pendulum on a fixed radius. Not a 360° orbit — the body sweeps
/// [halfSweepRad] either side of [centerRad] and returns.
///
/// Angle convention matches the injector: 0 = +X, counter-clockwise.
class SweepOrbit {
  SweepOrbit({
    required this.radius,
    required this.centerRad,
    required this.halfSweepRad,
    required this.periodSeconds,
    this.phaseRad = 0,
    this.elapsed = 0,
  });

  final double radius;
  final double centerRad;
  final double halfSweepRad;
  final double periodSeconds;
  final double phaseRad;
  double elapsed;

  double get _omega => (2 * math.pi) / periodSeconds;

  /// Default ([phaseRad] 0): starts at the sweep center. A phase of π/2
  /// starts at the +end.
  double angleAt(double t) =>
      centerRad + halfSweepRad * math.sin(_omega * t + phaseRad);

  double angularVelocityAt(double t) =>
      halfSweepRad * _omega * math.cos(_omega * t + phaseRad);

  double get angle => angleAt(elapsed);

  double get angularVelocity => angularVelocityAt(elapsed);

  math.Point<double> positionAt(double t) {
    final a = angleAt(t);
    return math.Point(math.cos(a) * radius, math.sin(a) * radius);
  }

  void advance(double dt) {
    elapsed += dt;
  }

  SweepOrbit copy() => SweepOrbit(
        radius: radius,
        centerRad: centerRad,
        halfSweepRad: halfSweepRad,
        periodSeconds: periodSeconds,
        phaseRad: phaseRad,
        elapsed: elapsed,
      );

  Map<String, dynamic> toJson() => {
        'r': radius,
        'c': centerRad,
        'h': halfSweepRad,
        'p': periodSeconds,
        't': elapsed,
        if (phaseRad != 0) 'ph': phaseRad,
      };

  static SweepOrbit? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final radius = _asDouble(map['r']);
    final center = _asDouble(map['c']);
    final half = _asDouble(map['h']);
    final period = _asDouble(map['p']);
    if (radius == null || center == null || half == null || period == null) {
      return null;
    }
    if (radius <= 0 || half <= 0 || period <= 0) return null;
    return SweepOrbit(
      radius: radius,
      centerRad: center,
      halfSweepRad: half,
      periodSeconds: period,
      phaseRad: _asDouble(map['ph']) ?? 0,
      elapsed: _asDouble(map['t']) ?? 0,
    );
  }

  static double? _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return null;
  }
}

/// Pack JSON `orbit` on a point seed. [sweepDeg] is the full pendulum width.
class SeedOrbitSpec {
  const SeedOrbitSpec({
    required this.sweepDeg,
    required this.periodSeconds,
    this.phaseDeg = 0,
  });

  final double sweepDeg;
  final double periodSeconds;
  final double phaseDeg;
}
