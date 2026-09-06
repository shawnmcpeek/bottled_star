import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';

import '../collapse/remnant_system.dart';
import '../challenge/challenge_run.dart';
import '../challenge/level_spec.dart';
import '../components/chamber.dart';
import '../components/effects.dart';
import '../components/injector.dart';
import '../components/nucleus.dart';
import '../constants.dart';
import '../element_tier.dart';
import '../element_tuning.dart';
import '../modes/game_mode.dart';
import '../modes/mode_rules.dart';
import 'ending_controller.dart';
import 'injection_queue.dart';
import 'injection_source.dart';
import 'merge_system.dart';
import 'haptics_controller.dart';
import 'run_snapshot.dart';
import 'sfx_controller.dart';
import 'supernova_blast.dart';
import 'achievement_hooks.dart';
import '../challenge/fixed_queue.dart';

typedef ScoreCallback = void Function(int delta, int total);
typedef GameOverCallback = void Function(RunEnding ending);
typedef TierCallback = void Function(ElementTier tier);
typedef QueueCallback = void Function(ElementTier current, ElementTier next);
typedef EndingCardCallback = void Function(RunEnding ending);
typedef FlashCallback = void Function(double seconds);
typedef ShakeCallback = void Function(double seconds, double intensity);
typedef VoidGameCallback = void Function();
typedef PressureCallback = void Function(double normalized01);
typedef ChallengeEndCallback = void Function(ChallengeRunStatus status);

class BottledStarWorld extends Forge2DWorld {
  BottledStarWorld({
    this.mode = GameMode.classic,
    this.challengeLevel,
    this.skipInitialChallengeSetup = false,
    ScoreCallback? onScore,
    GameOverCallback? onGameOver,
    TierCallback? onTierReached,
    QueueCallback? onQueueChanged,
    EndingCardCallback? onEndingCard,
    FlashCallback? onFlash,
    ShakeCallback? onShake,
    VoidGameCallback? onShotFired,
    VoidGameCallback? onMerge,
    PressureCallback? onRimPressure,
    ChallengeEndCallback? onChallengeEnd,
  })  : onScore = onScore ?? ((_, _) {}),
        onGameOver = onGameOver ?? ((_) {}),
        onTierReached = onTierReached ?? ((_) {}),
        onQueueChanged = onQueueChanged ?? ((_, _) {}),
        onEndingCard = onEndingCard ?? ((_) {}),
        onFlash = onFlash ?? ((_) {}),
        onShake = onShake ?? ((_, _) {}),
        onShotFired = onShotFired ?? (() {}),
        onMerge = onMerge ?? (() {}),
        onRimPressure = onRimPressure ?? ((_) {}),
        onChallengeEnd = onChallengeEnd ?? ((_) {}),
        allowSameTierMerges = !(challengeLevel?.noSameTier ?? false),
        injectionQueue = challengeLevel?.createQueue() ?? InjectionQueue(),
        super(gravity: Vector2.zero());

  final GameMode mode;

  /// Set for Challenge runs. Classic / Collapse leave this null.
  final LevelSpec? challengeLevel;

  /// When true, [onLoad] skips seeding the Challenge board so a saved run
  /// can be applied instead.
  final bool skipInitialChallengeSetup;

  /// When false, [ElementTier.sameTierMerges] is disabled for this world.
  /// Defaults true; Challenge `noSameTier` flips it for that level only.
  bool allowSameTierMerges;

  ScoreCallback onScore;
  GameOverCallback onGameOver;
  TierCallback onTierReached;
  QueueCallback onQueueChanged;
  EndingCardCallback onEndingCard;
  FlashCallback onFlash;
  ShakeCallback onShake;
  VoidGameCallback onShotFired;
  VoidGameCallback onMerge;
  PressureCallback onRimPressure;
  ChallengeEndCallback onChallengeEnd;

  late final MergeSystem mergeSystem;
  final InjectionSource injectionQueue;
  late final ChamberWall chamber;
  final Injector injector = Injector();
  late final ChamberBackdrop backdrop;
  RemnantSystem? remnantSystem;
  ChallengeRunTracker? challengeTracker;
  double _sinceLastChallengeShot = 0;

  final List<Nucleus> nuclei = [];
  final List<void Function()> _postStepOps = [];
  EndingController? endingController;
  final Set<int> tiersCreatedThisRun = {};

  int score = 0;
  int highestTier = 0;
  int shotCount = 0;
  bool gameOver = false;
  bool inputEnabled = true;
  bool physicsEnabled = true;
  bool rimPressureEnabled = true;
  bool voluntaryEnd = false;

  double _displayedPressure = 0;
  double _injectorLockout = 0;
  double _runElapsed = 0;
  Nucleus? _pendingSupernovaA;
  Nucleus? _pendingSupernovaB;
  RunEnding? activeEnding;

  static final Vector2 chamberCenter = Vector2.zero();

  bool get isCollapse => mode == GameMode.collapse;

  ModeRules get modeRules => ModeRules.forMode(mode);

  double get runElapsedSeconds => _runElapsed;

  double get totalOccupiedArea {
    var area = 0.0;
    for (final n in nuclei) {
      if (!n.isMounted || n.pendingDestroy) continue;
      final r = n.effectiveRadius;
      area += math.pi * r * r;
    }
    return area;
  }

  double get occupiedAreaFraction =>
      totalOccupiedArea /
      (math.pi * GameConstants.chamberRadius * GameConstants.chamberRadius);

  int countForTier(ElementTier tier) => nuclei
      .where((n) => n.isMounted && !n.pendingDestroy && n.tier == tier)
      .length;

  bool get canInject =>
      inputEnabled && !gameOver && _injectorLockout <= 0;

  int get kilonovaCount => remnantSystem?.kilonovaCount ?? 0;
  int get supernovaCount => remnantSystem?.supernovaCount ?? 0;

  void deferPostStep(void Function() op) => _postStepOps.add(op);

  void drainPostStep() {
    if (_postStepOps.isEmpty) return;
    final ops = List<void Function()>.from(_postStepOps);
    _postStepOps.clear();
    for (final op in ops) {
      op();
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    mergeSystem = MergeSystem(this);
    injectionQueue.reset();

    // Collapse packs heavy remnants against light nuclei — give the solver
    // more correction budget. Reset when Classic loads so shared settings
    // don't leak across modes.
    if (isCollapse) {
      positionIterations = 20;
      maxLinearCorrection = 0.45;
    } else {
      positionIterations = 10;
      maxLinearCorrection = 0.2;
    }

    backdrop = ChamberBackdrop();
    await add(backdrop);

    chamber = ChamberWall();
    await add(chamber);

    if (shouldAttachRemnants(
      isCollapse: isCollapse,
      challengeLevel: challengeLevel,
    )) {
      attachRemnantSystem();
    }

    injector.loadedTier = injectionQueue.current;
    await add(injector);
    _publishQueue();

    if (!skipInitialChallengeSetup) {
      setupChallenge();
    }

    mergeSystem.scanTouchingPairs();
    mergeSystem.resolve();
  }

  /// Seed starting nuclei, arm the goal/constraint tracker, and clamp the
  /// injector to `injectionArc` for a Challenge level. No-op otherwise.
  /// Called from [onLoad] and again from [resetRun] (retry re-seeds fresh).
  void setupChallenge() {
    final level = challengeLevel;
    if (level == null) return;

    challengeTracker = ChallengeRunTracker(level);
    _sinceLastChallengeShot = 0;

    for (final body in level.resolveSeed(
      chamberRadius: GameConstants.chamberRadius,
    )) {
      spawnNucleus(
        tier: body.element,
        position: Vector2(body.x, body.y),
        countsAsChallengeProduced: false,
      );
    }

    final arc = level.injectionArc;
    if (arc != null) {
      final centerDeg =
          arc.centerDeg > 180 ? arc.centerDeg - 360 : arc.centerDeg;
      final centerRad = centerDeg * math.pi / 180;
      final halfWidthRad = (arc.widthDeg / 2) * math.pi / 180;
      final min = centerRad - halfWidthRad;
      final max = centerRad + halfWidthRad;
      injector
        ..minOrbitAngle = min
        ..maxOrbitAngle = max
        ..orbitAngle = centerRad;
    } else {
      injector
        ..minOrbitAngle = null
        ..maxOrbitAngle = null;
    }
  }

  /// Attach remnants for Collapse, or for a Challenge level with
  /// `rules.remnants: true`. Classic never calls this.
  void attachRemnantSystem() {
    remnantSystem ??= RemnantSystem(this);
  }

  void resetRun() {
    endingController?.removeFromParent();
    endingController = null;
    activeEnding = null;

    gameOver = false;
    inputEnabled = true;
    physicsEnabled = true;
    rimPressureEnabled = true;
    voluntaryEnd = false;
    score = 0;
    highestTier = 0;
    shotCount = 0;
    mergeSystem.chainDepth = 0;
    injectionQueue.reset();
    tiersCreatedThisRun.clear();
    _displayedPressure = 0;
    _injectorLockout = 0;
    _runElapsed = 0;
    _pendingSupernovaA = null;
    _pendingSupernovaB = null;
    _postStepOps.clear();
    remnantSystem?.reset();

    for (final n in List<Nucleus>.from(nuclei)) {
      if (n.isMounted) n.removeFromParent();
    }
    nuclei.clear();

    children.whereType<SeedParticle>().toList().forEach((c) => c.removeFromParent());
    children.whereType<RemnantStar>().toList().forEach((c) => c.removeFromParent());
    children.whereType<ScreenFlash>().toList().forEach((c) => c.removeFromParent());
    children.whereType<SupernovaBlast>().toList().forEach((c) => c.removeFromParent());
    children.whereType<EjectStreak>().toList().forEach((c) => c.removeFromParent());
    children.whereType<KilonovaBurst>().toList().forEach((c) => c.removeFromParent());

    chamber
      ..displayedPressure = 0
      ..flare = 0
      ..broken = false
      ..breakProgress = 0;

    injector
      ..cancelCharge()
      ..cooldown = 0
      ..orbitAngle = -math.pi / 2
      ..loadedTier = injectionQueue.current;

    setupChallenge();

    _publishQueue();
  }

  void _publishQueue() {
    if (injectionQueue.isExhausted) {
      final queue = injectionQueue;
      if (queue is FixedInjectionQueue && queue.sequence.isNotEmpty) {
        injector.loadedTier = queue.sequence.last;
        onQueueChanged(queue.sequence.last, queue.sequence.last);
      }
      return;
    }
    injector.loadedTier = injectionQueue.current;
    onQueueChanged(injectionQueue.current, injectionQueue.next);
  }

  RunSnapshot captureSnapshot() {
    final queue = injectionQueue;
    final queueSnap = switch (queue) {
      InjectionQueue() => QueueSnapshot.weighted(
          current: queue.current.tier,
          next: queue.next.tier,
          unlockedThrough: queue.unlockedThrough,
        ),
      FixedInjectionQueue() => QueueSnapshot.fixed(
          current: queue.isExhausted
              ? (queue.sequence.isEmpty ? 0 : queue.sequence.last.tier)
              : queue.current.tier,
          next: queue.isExhausted
              ? (queue.sequence.isEmpty ? 0 : queue.sequence.last.tier)
              : queue.next.tier,
          index: queue.index,
        ),
      _ => QueueSnapshot.weighted(
          current: ElementTier.hydrogen.tier,
          next: ElementTier.hydrogen.tier,
          unlockedThrough: 0,
        ),
    };

    ChallengeTrackerSnapshot? challengeSnap;
    final tracker = challengeTracker;
    if (tracker != null) {
      challengeSnap = ChallengeTrackerSnapshot(
        produced: {
          for (final e in tracker.produced.entries) e.key.tier: e.value,
        },
        shotsFired: tracker.shotsFired,
        supernovaCount: tracker.supernovaCount,
      );
    }

    return RunSnapshot(
      mode: mode,
      levelId: challengeLevel?.id,
      score: score,
      highestTier: highestTier,
      shotCount: shotCount,
      kilonovaCount: kilonovaCount,
      supernovaCount: supernovaCount,
      injectorAngle: injector.orbitAngle,
      tiersCreated: Set<int>.from(tiersCreatedThisRun),
      queue: queueSnap,
      nuclei: [
        for (final n in nuclei)
          if (n.isMounted && !n.pendingDestroy)
            NucleusSnapshot(
              tier: n.tier.tier,
              rimPressure: n.rimPressure,
              body: BodySnapshot(
                x: n.body.position.x,
                y: n.body.position.y,
                vx: n.body.linearVelocity.x,
                vy: n.body.linearVelocity.y,
                angle: n.body.angle,
                angularVelocity: n.body.angularVelocity,
              ),
            ),
      ],
      remnants: [
        for (final r in remnantSystem?.remnants ?? const [])
          if (r.isMounted && !r.pendingDestroy)
            BodySnapshot(
              x: r.body.position.x,
              y: r.body.position.y,
              vx: r.body.linearVelocity.x,
              vy: r.body.linearVelocity.y,
              angle: r.body.angle,
              angularVelocity: r.body.angularVelocity,
            ),
      ],
      challengeSettleElapsed: _sinceLastChallengeShot,
      challenge: challengeSnap,
    );
  }

  void applySnapshot(RunSnapshot snap) {
    endingController?.removeFromParent();
    endingController = null;
    activeEnding = null;

    gameOver = false;
    inputEnabled = true;
    physicsEnabled = true;
    rimPressureEnabled = true;
    voluntaryEnd = false;
    score = snap.score;
    highestTier = snap.highestTier;
    shotCount = snap.shotCount;
    mergeSystem.chainDepth = 0;
    tiersCreatedThisRun
      ..clear()
      ..addAll(snap.tiersCreated);
    _displayedPressure = 0;
    _injectorLockout = 0;
    _runElapsed = 0;
    _pendingSupernovaA = null;
    _pendingSupernovaB = null;
    _postStepOps.clear();
    _sinceLastChallengeShot = snap.challengeSettleElapsed;

    remnantSystem?.reset();
    if (remnantSystem != null) {
      remnantSystem!.kilonovaCount = snap.kilonovaCount;
      remnantSystem!.supernovaCount = snap.supernovaCount;
    }

    for (final n in List<Nucleus>.from(nuclei)) {
      if (n.isMounted) n.removeFromParent();
    }
    nuclei.clear();

    children.whereType<SeedParticle>().toList().forEach((c) => c.removeFromParent());
    children.whereType<RemnantStar>().toList().forEach((c) => c.removeFromParent());
    children.whereType<ScreenFlash>().toList().forEach((c) => c.removeFromParent());
    children.whereType<SupernovaBlast>().toList().forEach((c) => c.removeFromParent());
    children.whereType<EjectStreak>().toList().forEach((c) => c.removeFromParent());
    children.whereType<KilonovaBurst>().toList().forEach((c) => c.removeFromParent());

    chamber
      ..displayedPressure = 0
      ..flare = 0
      ..broken = false
      ..breakProgress = 0;

    _restoreQueue(snap.queue);

    injector
      ..cancelCharge()
      ..cooldown = 0
      ..orbitAngle = snap.injectorAngle;

    if (challengeLevel != null) {
      challengeTracker = ChallengeRunTracker(challengeLevel!);
      final saved = snap.challenge;
      if (saved != null) {
        challengeTracker!.restore(
          produced: {
            for (final e in saved.produced.entries)
              ElementTier.fromTier(e.key): e.value,
          },
          shotsFired: saved.shotsFired,
          supernovaCount: saved.supernovaCount,
        );
      }
      final arc = challengeLevel!.injectionArc;
      if (arc != null) {
        final centerDeg =
            arc.centerDeg > 180 ? arc.centerDeg - 360 : arc.centerDeg;
        final centerRad = centerDeg * math.pi / 180;
        final halfWidthRad = (arc.widthDeg / 2) * math.pi / 180;
        injector
          ..minOrbitAngle = centerRad - halfWidthRad
          ..maxOrbitAngle = centerRad + halfWidthRad;
      }
    }

    for (final n in snap.nuclei) {
      spawnNucleus(
        tier: ElementTier.fromTier(n.tier),
        position: Vector2(n.body.x, n.body.y),
        velocity: Vector2(n.body.vx, n.body.vy),
        angle: n.body.angle,
        angularVelocity: n.body.angularVelocity,
        rimPressure: n.rimPressure,
        countsAsChallengeProduced: false,
      );
    }

    for (final r in snap.remnants) {
      remnantSystem?.restoreBody(
        position: Vector2(r.x, r.y),
        velocity: Vector2(r.vx, r.vy),
        angle: r.angle,
        angularVelocity: r.angularVelocity,
      );
    }

    _publishQueue();
    mergeSystem.scanTouchingPairs();
    mergeSystem.resolve();
  }

  void _restoreQueue(QueueSnapshot snap) {
    final queue = injectionQueue;
    if (queue is InjectionQueue && snap.kind == QueueKind.weighted) {
      queue.restore(
        current: ElementTier.fromTier(snap.current),
        next: ElementTier.fromTier(snap.next),
        unlockedThrough: snap.unlockedThrough,
      );
      return;
    }
    if (queue is FixedInjectionQueue && snap.kind == QueueKind.fixed) {
      queue.restoreAt(snap.index);
    }
  }

  Nucleus spawnNucleus({
    required ElementTier tier,
    required Vector2 position,
    bool freshFromMerge = false,
    bool asProjectile = false,
    Vector2? velocity,
    double angle = 0,
    double angularVelocity = 0,
    double rimPressure = 0,
    bool countsAsChallengeProduced = true,
  }) {
    late Nucleus nucleus;
    nucleus = Nucleus(
      tier: tier,
      spawnPosition: position,
      freshFromMerge: freshFromMerge,
      asProjectile: asProjectile,
      initialVelocity: velocity,
      initialAngle: angle,
      initialAngularVelocity: angularVelocity,
      onMergeRequest: (a, b) => mergeSystem.request(a, b),
    );
    nucleus.rimPressure = rimPressure;
    nuclei.add(nucleus);
    add(nucleus);
    _noteTierCreated(tier);

    if (countsAsChallengeProduced) {
      final tracker = challengeTracker;
      if (tracker != null) {
        tracker.onElementCreated(tier);
        if (tracker.status == ChallengeRunStatus.lost) {
          _endChallengeRun(ChallengeRunStatus.lost);
        }
      }
    }
    return nucleus;
  }

  void onElementCreated(ElementTier tier) {
    _noteTierCreated(tier);
    if (tier.tier > highestTier) {
      highestTier = tier.tier;
      injectionQueue.onHighestTier(highestTier);
      onTierReached(tier);
      _publishQueue();
    } else {
      injectionQueue.onHighestTier(highestTier);
    }
  }

  void _noteTierCreated(ElementTier tier) {
    tiersCreatedThisRun.add(tier.tier);
  }

  bool fireInjector() {
    if (!inputEnabled || gameOver || _injectorLockout > 0) return false;
    // Challenge's fixed queue throws on consume() once exhausted — the
    // settle delay leaves a window after the last budgeted shot where
    // input is technically still live. Block it here instead.
    if (injectionQueue.isExhausted) return false;
    final power01 = injector.releaseCharge();
    if (power01 == null) return false;

    final tier = injectionQueue.consume();
    _publishQueue();

    final dir = injector.fireDirection;
    final spawn = injector.tipPosition + dir * 8;
    final maxSpawn =
        GameConstants.chamberRadius - tier.radiusFor(mode) - 2;
    final spawnClamped = spawn.length > maxSpawn
        ? spawn.normalized() * maxSpawn
        : spawn;

    final impulse = injector.impulseForPower(power01) *
        ElementTuning.impulseScaleFor(mode);
    final speed = impulse * 0.28;
    final velocity = dir * speed;

    spawnNucleus(
      tier: tier,
      position: spawnClamped,
      asProjectile: tier.isHydrogen,
      velocity: velocity,
    );
    shotCount++;
    onShotFired();

    final tracker = challengeTracker;
    if (tracker != null) {
      tracker.onShotFired();
      _sinceLastChallengeShot = 0;
    }
    return true;
  }

  void trySkipEnding() {
    endingController?.trySkip();
  }

  /// Collapse voluntary end — bank kilonovas / shot tiebreaker.
  void requestQuietEnd() {
    if (!isCollapse || gameOver) return;
    voluntaryEnd = true;
    _beginRunEnding();
  }

  /// Mid-run Fe+Fe blast finished — spawn a remnant when the system is attached
  /// (Collapse, or Challenge with `rules.remnants: true`).
  void onSupernovaBlastResolved(Vector2 fusionPoint) {
    if (gameOver || remnantSystem == null) return;
    remnantSystem!.spawnAt(fusionPoint);
  }

  @override
  void update(double dt) {
    if (!gameOver) {
      _runElapsed += dt;
    }

    if (_injectorLockout > 0) {
      _injectorLockout = math.max(0, _injectorLockout - dt);
    }

    if (physicsEnabled && !gameOver) {
      for (final n in nuclei) {
        if (n.isMounted) n.applyRadialGravity();
      }
      if (remnantSystem != null) {
        remnantSystem!.applyGravity();
      }

      physicsWorld.stepDt(dt);
      mergeSystem.scanTouchingPairs();
      mergeSystem.resolve();
      drainPostStep();

      if (mergeSystem.scoreGainedThisStep > 0) {
        score += mergeSystem.scoreGainedThisStep;
        onScore(mergeSystem.scoreGainedThisStep, score);
        onMerge();
      }

      _scanSupernova();
      _resolveQueuedSupernova();
      drainPostStep();

      _updateRimPressure(dt);

      if (challengeTracker != null) {
        _checkChallengeConstraints();
        if (!gameOver) _updateChallengeSettle(dt);
      }
    }
  }

  /// Constraints ([MaxBodiesConstraint], [MaxOfElementConstraint]) are
  /// checked every tick — they must trip the instant they're violated, not
  /// wait for the board to settle.
  void _checkChallengeConstraints() {
    final tracker = challengeTracker;
    if (tracker == null || tracker.status != ChallengeRunStatus.playing) {
      return;
    }
    final counts = <ElementTier, int>{};
    var total = 0;
    for (final n in nuclei) {
      if (!n.isMounted || n.pendingDestroy) continue;
      total++;
      counts[n.tier] = (counts[n.tier] ?? 0) + 1;
    }
    tracker.onBoardChanged(totalBodies: total, countsByElement: counts);
    if (tracker.status != ChallengeRunStatus.playing) {
      _endChallengeRun(tracker.status);
    }
  }

  /// Goals ([ProduceGoal] etc.) and the budget-exhausted loss are only
  /// evaluated once the board has been quiet for
  /// [GameConstants.challengeSettleSeconds] — otherwise a shot still mid-air
  /// could be judged before it has a chance to land.
  void _updateChallengeSettle(double dt) {
    final tracker = challengeTracker;
    if (tracker == null || tracker.status != ChallengeRunStatus.playing) {
      return;
    }
    _sinceLastChallengeShot += dt;
    if (_sinceLastChallengeShot < GameConstants.challengeSettleSeconds) return;

    final boardBodies =
        nuclei.where((n) => n.isMounted && !n.pendingDestroy).length;
    tracker.evaluateAtSettle(boardBodies: boardBodies);
    if (tracker.status != ChallengeRunStatus.playing) {
      _endChallengeRun(tracker.status);
    }
  }

  void _endChallengeRun(ChallengeRunStatus status) {
    if (gameOver) return;
    gameOver = true;
    inputEnabled = false;
    physicsEnabled = false;
    rimPressureEnabled = false;
    injector.cancelCharge();
    for (final n in nuclei) {
      if (n.isMounted) n.body.linearVelocity.setZero();
    }
    onChallengeEnd(status);
  }

  void _updateRimPressure(double dt) {
    if (!rimPressureEnabled || gameOver) return;

    for (final n in List<Nucleus>.from(nuclei)) {
      if (!n.isMounted || n.pendingDestroy) continue;
      if (n.touchingRim(chamberCenter, GameConstants.chamberRadius)) {
        n.rimPressure += GameConstants.kRimFillRate * dt;
      } else {
        n.rimPressure -= GameConstants.kRimDrainRate * dt;
      }
      n.rimPressure =
          n.rimPressure.clamp(0.0, GameConstants.kRimPressureLimit);

      if (n.rimPressure >= GameConstants.kRimPressureLimit) {
        if (challengeLevel != null) {
          _endChallengeRun(ChallengeRunStatus.lost);
        } else {
          _beginRunEnding();
        }
        return;
      }
    }

    final target = nuclei.isEmpty
        ? 0.0
        : nuclei.map((n) => n.rimPressure).fold<double>(0, math.max) /
            GameConstants.kRimPressureLimit;

    _displayedPressure +=
        (target - _displayedPressure) * (1 - math.exp(-8.0 * dt));
    chamber.displayedPressure = _displayedPressure;
    onRimPressure(_displayedPressure);
  }

  void _scanSupernova() {
    if (gameOver) return;
    if (!modeRules.ironCollapses) return;
    if (_pendingSupernovaA != null) return;

    final irons = nuclei
        .where((n) => n.isMounted && !n.pendingDestroy && n.tier.isIron)
        .toList();

    for (var i = 0; i < irons.length; i++) {
      for (var j = i + 1; j < irons.length; j++) {
        final a = irons[i];
        final b = irons[j];
        final gap = a.body.position.distanceTo(b.body.position) -
            a.effectiveRadius -
            b.effectiveRadius;
        if (gap <= GameConstants.kSupernovaContactEpsilon) {
          _pendingSupernovaA = a;
          _pendingSupernovaB = b;
          return;
        }
      }
    }
  }

  void _resolveQueuedSupernova() {
    final a = _pendingSupernovaA;
    final b = _pendingSupernovaB;
    if (a == null || b == null) return;
    _pendingSupernovaA = null;
    _pendingSupernovaB = null;

    if (!a.isMounted || !b.isMounted) return;
    if (a.pendingDestroy || b.pendingDestroy) return;

    final origin = (a.body.position + b.body.position) * 0.5;
    a.pendingDestroy = true;
    b.pendingDestroy = true;
    a.removeFromParent();
    b.removeFromParent();

    score += GameConstants.kSupernovaScore;
    onScore(GameConstants.kSupernovaScore, score);
    challengeTracker?.onSupernova();

    SfxController.instance.playSpringHit();
    HapticsController.instance.playBlast();
    // ignore: unawaited_futures
    AchievementHooks.onSupernovaBlast();
    add(SupernovaBlast(origin: origin, gameWorld: this));

    chamber.flare = 1.0;
    add(ScreenFlash(life: GameConstants.kSupernovaFlashSeconds));
    onFlash(GameConstants.kSupernovaFlashSeconds);
    onShake(GameConstants.kSupernovaShakeSeconds, 12);

    _injectorLockout = GameConstants.kSupernovaLockoutSeconds;
    injector.cancelCharge();
  }

  void _beginRunEnding() {
    if (gameOver) return;
    gameOver = true;
    inputEnabled = false;
    physicsEnabled = false;
    rimPressureEnabled = false;
    injector.cancelCharge();

    if (isCollapse && kilonovaCount >= 1) {
      activeEnding = RunEnding.kilonova;
    } else if (highestTier >= ElementTier.iron.tier) {
      activeEnding = RunEnding.supernova;
    } else {
      activeEnding = RunEnding.whiteDwarf;
    }

    for (final n in nuclei) {
      if (n.isMounted) n.body.linearVelocity.setZero();
    }
    for (final r in remnantSystem?.remnants ?? const []) {
      if (r.isMounted) r.body.linearVelocity.setZero();
    }

    endingController = EndingController(
      world: this,
      ending: activeEnding!,
      onCardReady: (ending) => onEndingCard(ending),
      onFlash: onFlash,
      onShake: onShake,
    )..start();
    add(endingController!);
    onGameOver(activeEnding!);
  }
}
