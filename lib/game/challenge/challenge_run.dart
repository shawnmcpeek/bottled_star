import '../element_tier.dart';
import 'level_spec.dart';

enum ChallengeRunStatus { playing, won, lost }

/// Tracks Challenge goals and constraints for a single run.
///
/// Constraints are checked the instant they are violated (fusion / body
/// change). Goals use AND semantics and are evaluated at settle — except
/// [ProduceGoal], whose cumulative creation count is updated as creations
/// happen and then tested at settle.
class ChallengeRunTracker {
  ChallengeRunTracker(this.spec)
      : allowSameTierMerges = !spec.noSameTier,
        remnantsEnabled = spec.rules.remnants;

  final LevelSpec spec;

  /// Thread into [ElementTier.mergeResult] for this level only.
  final bool allowSameTierMerges;

  /// Whether [RemnantSystem] should be attached for this level.
  final bool remnantsEnabled;

  ChallengeRunStatus status = ChallengeRunStatus.playing;

  /// Cumulative creations this run (not simultaneous board occupancy).
  final Map<ElementTier, int> produced = {};

  int shotsFired = 0;

  /// Mid-run iron+iron supernovae this run. Fed by [onSupernova].
  int supernovaCount = 0;

  /// Latest live board composition, from the most recent [onBoardChanged].
  /// Backs [EliminateGoal] — current occupancy, not cumulative production.
  Map<ElementTier, int> _liveCounts = <ElementTier, int>{};

  /// Call at the moment a nucleus of [tier] is created (fusion product or
  /// inject). Checks [NeverProduceConstraint] immediately — even if a later
  /// step in the same chain would consume it.
  void onElementCreated(ElementTier tier) {
    if (status != ChallengeRunStatus.playing) return;
    produced[tier] = (produced[tier] ?? 0) + 1;

    for (final c in spec.constraints) {
      if (c is NeverProduceConstraint && c.element == tier) {
        status = ChallengeRunStatus.lost;
        return;
      }
      if (c is MaxTotalProducedConstraint &&
          c.element == tier &&
          produced[tier]! > c.value) {
        status = ChallengeRunStatus.lost;
        return;
      }
    }
  }

  /// Call whenever board occupancy changes (create or destroy).
  void onBoardChanged({
    required int totalBodies,
    required Map<ElementTier, int> countsByElement,
  }) {
    if (status != ChallengeRunStatus.playing) return;
    _liveCounts = countsByElement;

    for (final c in spec.constraints) {
      switch (c) {
        case MaxBodiesConstraint(:final value):
          if (totalBodies > value) {
            status = ChallengeRunStatus.lost;
            return;
          }
        case MaxOfElementConstraint(:final element, :final value):
          if ((countsByElement[element] ?? 0) > value) {
            status = ChallengeRunStatus.lost;
            return;
          }
        case NeverProduceConstraint():
        case NoSameTierConstraint():
        case MaxTotalProducedConstraint():
          break; // checked in onElementCreated (cumulative, not live count)
      }
    }
  }

  void restore({
    required Map<ElementTier, int> produced,
    required int shotsFired,
    required int supernovaCount,
  }) {
    this.produced
      ..clear()
      ..addAll(produced);
    this.shotsFired = shotsFired;
    this.supernovaCount = supernovaCount;
    status = ChallengeRunStatus.playing;
  }

  void onShotFired() {
    if (status != ChallengeRunStatus.playing) return;
    shotsFired++;
  }

  /// Call when a mid-run iron+iron supernova resolves.
  void onSupernova() {
    if (status != ChallengeRunStatus.playing) return;
    supernovaCount++;
  }

  /// Evaluate goals after the board settles following a shot.
  ///
  /// [boardBodies] is the simultaneous nucleus count at settle.
  /// Returns true if the run just transitioned to won/lost.
  bool evaluateAtSettle({required int boardBodies}) {
    if (status != ChallengeRunStatus.playing) return false;

    if (shotsFired >= spec.budgetShots && !_goalsSatisfied(boardBodies)) {
      status = ChallengeRunStatus.lost;
      return true;
    }

    if (_goalsSatisfied(boardBodies)) {
      status = ChallengeRunStatus.won;
      return true;
    }
    return false;
  }

  bool _goalsSatisfied(int boardBodies) {
    return spec.goals.every((g) => _goalMet(g, boardBodies));
  }

  bool _goalMet(LevelGoal goal, int boardBodies) {
    return switch (goal) {
      ProduceGoal(:final element, :final count) =>
        (produced[element] ?? 0) >= count,
      BoardUnderGoal(:final value) => boardBodies < value,
      SurviveGoal(:final shots) => shotsFired >= shots,
      EliminateGoal(:final element) => (_liveCounts[element] ?? 0) == 0,
      CauseSupernovaGoal(:final count) => supernovaCount >= count,
    };
  }

  /// Merge helper — keeps Classic callers on the default path.
  ElementTier? mergeResult(ElementTier a, ElementTier b) {
    return ElementTier.mergeResult(
      a,
      b,
      allowSameTier: allowSameTierMerges,
    );
  }
}

/// Whether a Challenge (or Collapse) board should attach [RemnantSystem].
///
/// Per-level for Challenge; Collapse always attaches. Classic never does.
bool shouldAttachRemnants({
  required bool isCollapse,
  LevelSpec? challengeLevel,
}) {
  if (isCollapse) return true;
  if (challengeLevel != null) return challengeLevel.rules.remnants;
  return false;
}
