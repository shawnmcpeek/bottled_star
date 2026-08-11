import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';

import '../collapse/remnant_system.dart';
import '../components/chamber.dart';
import '../components/effects.dart';
import '../components/injector.dart';
import '../components/nucleus.dart';
import '../constants.dart';
import '../element_tier.dart';
import '../modes/game_mode.dart';
import 'ending_controller.dart';
import 'injection_queue.dart';
import 'merge_system.dart';
import 'haptics_controller.dart';
import 'sfx_controller.dart';
import 'supernova_blast.dart';
import 'achievement_hooks.dart';

typedef ScoreCallback = void Function(int delta, int total);
typedef GameOverCallback = void Function(RunEnding ending);
typedef TierCallback = void Function(ElementTier tier);
typedef QueueCallback = void Function(ElementTier current, ElementTier next);
typedef EndingCardCallback = void Function(RunEnding ending);
typedef FlashCallback = void Function(double seconds);
typedef ShakeCallback = void Function(double seconds, double intensity);
typedef VoidGameCallback = void Function();
typedef PressureCallback = void Function(double normalized01);

class BottledStarWorld extends Forge2DWorld {
  BottledStarWorld({
    this.mode = GameMode.classic,
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
        super(gravity: Vector2.zero());

  final GameMode mode;

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

  late final MergeSystem mergeSystem;
  final InjectionQueue injectionQueue = InjectionQueue();
  late final ChamberWall chamber;
  final Injector injector = Injector();
  late final ChamberBackdrop backdrop;
  RemnantSystem? remnantSystem;

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
  Nucleus? _pendingSupernovaA;
  Nucleus? _pendingSupernovaB;
  RunEnding? activeEnding;

  static final Vector2 chamberCenter = Vector2.zero();

  bool get isCollapse => mode == GameMode.collapse;
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

    if (isCollapse) {
      remnantSystem = RemnantSystem(this);
    }

    injector.loadedTier = injectionQueue.current;
    await add(injector);
    _publishQueue();

    mergeSystem.scanTouchingPairs();
    mergeSystem.resolve();
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
    _publishQueue();
  }

  void _publishQueue() {
    injector.loadedTier = injectionQueue.current;
    onQueueChanged(injectionQueue.current, injectionQueue.next);
  }

  Nucleus spawnNucleus({
    required ElementTier tier,
    required Vector2 position,
    bool freshFromMerge = false,
    bool asProjectile = false,
    Vector2? velocity,
  }) {
    late Nucleus nucleus;
    nucleus = Nucleus(
      tier: tier,
      spawnPosition: position,
      freshFromMerge: freshFromMerge,
      asProjectile: asProjectile,
      initialVelocity: velocity,
      onMergeRequest: (a, b) => mergeSystem.request(a, b),
    );
    nuclei.add(nucleus);
    add(nucleus);
    _noteTierCreated(tier);
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
    final power01 = injector.releaseCharge();
    if (power01 == null) return false;

    final tier = injectionQueue.consume();
    _publishQueue();

    final dir = injector.fireDirection;
    final spawn = injector.tipPosition + dir * 8;
    final maxSpawn = GameConstants.chamberRadius - tier.radius - 2;
    final spawnClamped = spawn.length > maxSpawn
        ? spawn.normalized() * maxSpawn
        : spawn;

    final impulse = injector.impulseForPower(power01);
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

  /// Collapse only — called when a mid-run blast shell finishes.
  void onSupernovaBlastResolved(Vector2 fusionPoint) {
    if (!isCollapse || gameOver) return;
    remnantSystem?.spawnAt(fusionPoint);
  }

  @override
  void update(double dt) {
    if (_injectorLockout > 0) {
      _injectorLockout = math.max(0, _injectorLockout - dt);
    }

    if (physicsEnabled && !gameOver) {
      for (final n in nuclei) {
        if (n.isMounted) n.applyRadialGravity();
      }
      if (isCollapse) {
        remnantSystem?.applyGravity();
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
    }
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
        _beginRunEnding();
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
    if (_pendingSupernovaA != null) return;

    final irons = nuclei
        .where((n) => n.isMounted && !n.pendingDestroy && n.tier.isIron)
        .toList();

    for (var i = 0; i < irons.length; i++) {
      for (var j = i + 1; j < irons.length; j++) {
        final a = irons[i];
        final b = irons[j];
        final gap = a.body.position.distanceTo(b.body.position) -
            a.tier.radius -
            b.tier.radius;
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
