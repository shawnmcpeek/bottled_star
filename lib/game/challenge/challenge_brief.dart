import 'level_spec.dart';

/// Player-facing goal line. HUD, level select, and fail copy use this.
String describeChallengeGoal(LevelGoal goal) {
  return switch (goal) {
    ProduceGoal(:final element, :final count) =>
      'Produce $count× ${element.symbol}',
    BoardUnderGoal(:final value) => 'Fewer than $value nuclei',
    SurviveGoal(:final shots) => 'Fire all $shots shots',
    EliminateGoal(:final element) => 'Eliminate all ${element.symbol}',
    CauseSupernovaGoal(:final count) => 'Cause $count× supernova',
  };
}

/// Player-facing constraint line. [MaxBodiesConstraint] is a pile seatbelt
/// unless [includeSeatbelts] is true (fail card).
String describeChallengeConstraint(
  LevelConstraint constraint, {
  bool includeSeatbelts = false,
}) {
  return switch (constraint) {
    NeverProduceConstraint(:final element) => 'Never produce ${element.symbol}',
    MaxOfElementConstraint(:final element, :final value) =>
      'At most $value ${element.symbol} on the board',
    MaxTotalProducedConstraint(:final element, :final value) =>
      'At most $value ${element.symbol} produced',
    NoSameTierConstraint() => 'Heavy twins do not merge',
    MaxBodiesConstraint(:final value) =>
      includeSeatbelts ? 'At most $value nuclei' : '',
  };
}

List<String> playerFacingConstraintLines(LevelSpec level) {
  return [
    for (final c in level.constraints)
      describeChallengeConstraint(c),
  ].where((line) => line.isNotEmpty).toList();
}

String challengeLevelSummary(LevelSpec level) {
  final rules = playerFacingConstraintLines(level);
  return [
    ...level.goals.map(describeChallengeGoal),
    ...rules,
  ].join(' · ');
}
