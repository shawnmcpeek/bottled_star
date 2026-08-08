import 'dart:math' as math;

import 'package:flame/components.dart';

import '../components/effects.dart';
import '../components/nucleus.dart';
import '../constants.dart';
import 'bottled_star_world.dart';

enum EndingPhase {
  idle,
  // White dwarf
  hold,
  vent,
  remnant,
  // Supernova ending
  compress,
  detonate,
  expand,
  seed,
  // Shared
  card,
}

/// Cinematic run ending. Physics must already be stopped by the world.
class EndingController extends Component {
  EndingController({
    required this.world,
    required this.ending,
    required this.onCardReady,
    required this.onFlash,
    required this.onShake,
  });

  final BottledStarWorld world;
  final RunEnding ending;
  final void Function(RunEnding ending) onCardReady;
  final void Function(double seconds) onFlash;
  final void Function(double seconds, double intensity) onShake;

  EndingPhase phase = EndingPhase.idle;
  double phaseAge = 0;
  double totalAge = 0;
  bool cardShown = false;
  bool skipArmed = false;

  final _rng = math.Random();
  final Map<Nucleus, _VentState> _vent = {};
  RemnantStar? _remnant;

  void start() {
    phase = switch (ending) {
      RunEnding.supernova => EndingPhase.compress,
      RunEnding.kilonova => EndingPhase.hold,
      RunEnding.whiteDwarf => EndingPhase.hold,
    };
    phaseAge = 0;
    totalAge = 0;
    cardShown = false;
    skipArmed = false;
    _vent.clear();

    for (final n in List<Nucleus>.from(world.nuclei)) {
      if (!n.isMounted) continue;
      final pos = n.body.position.clone();
      final dir = pos.length2 < 0.01
          ? Vector2(1, 0)
          : pos.normalized();
      _vent[n] = _VentState(
        origin: pos,
        dir: dir,
        speed: 40 + _rng.nextDouble() * 30,
        delay: _rng.nextDouble() * 0.4,
        startScale: 1,
      );
    }

    // Kilonova card beat: short gold flash then card.
    if (ending == RunEnding.kilonova) {
      onFlash(0.18);
      onShake(0.35, 6);
    }
  }

  void trySkip() {
    if (totalAge < GameConstants.endingSkipAfterSeconds) return;
    if (cardShown) return;
    _goToCard();
  }

  void _goToCard() {
    if (cardShown) return;
    cardShown = true;
    phase = EndingPhase.card;
    onCardReady(ending);
  }

  @override
  void update(double dt) {
    if (phase == EndingPhase.idle || phase == EndingPhase.card) return;
    phaseAge += dt;
    totalAge += dt;
    if (totalAge >= GameConstants.endingSkipAfterSeconds) {
      skipArmed = true;
    }

    switch (ending) {
      case RunEnding.whiteDwarf:
        _updateWhiteDwarf(dt);
      case RunEnding.supernova:
        _updateSupernova(dt);
      case RunEnding.kilonova:
        _updateKilonova(dt);
    }
  }

  void _updateKilonova(double dt) {
    world.chamber.displayedPressure =
        math.max(0, world.chamber.displayedPressure - dt / 0.8);
    for (final n in world.nuclei) {
      if (n.isMounted) {
        n.body.linearVelocity.setZero();
        n.renderOpacity = math.max(0, n.renderOpacity - dt * 0.7);
      }
    }
    if (phaseAge >= 1.0) {
      _goToCard();
    }
  }

  void _updateWhiteDwarf(double dt) {
    switch (phase) {
      case EndingPhase.hold:
        world.chamber.displayedPressure =
            math.max(0, world.chamber.displayedPressure - dt / GameConstants.whiteDwarfHold);
        for (final n in world.nuclei) {
          if (n.isMounted) n.body.linearVelocity.setZero();
        }
        if (phaseAge >= GameConstants.whiteDwarfHold) {
          phase = EndingPhase.vent;
          phaseAge = 0;
        }
      case EndingPhase.vent:
        world.chamber.displayedPressure = 0;
        for (final entry in _vent.entries) {
          final n = entry.key;
          final s = entry.value;
          if (!n.isMounted) continue;
          final localT = ((phaseAge - s.delay) / GameConstants.whiteDwarfVent)
              .clamp(0.0, 1.0);
          final localEase = 1 - math.pow(1 - localT, 2).toDouble();
          final dist = s.speed * localEase * GameConstants.whiteDwarfVent * 0.55;
          final pos = s.origin + s.dir * dist;
          n.body.setTransform(pos, n.body.angle);
          n.body.linearVelocity.setZero();
          n.renderOpacity = (1 - localEase).clamp(0.0, 1.0);
        }
        if (phaseAge >= GameConstants.whiteDwarfVent) {
          for (final n in List<Nucleus>.from(world.nuclei)) {
            if (n.isMounted) n.removeFromParent();
          }
          _remnant = RemnantStar()..opacity = 0;
          world.add(_remnant!);
          phase = EndingPhase.remnant;
          phaseAge = 0;
        }
      case EndingPhase.remnant:
        if (_remnant != null) {
          _remnant!.opacity =
              (phaseAge / 0.4).clamp(0.0, 1.0);
        }
        if (phaseAge >= GameConstants.whiteDwarfRemnant) {
          _goToCard();
        }
      default:
        break;
    }
  }

  void _updateSupernova(double dt) {
    switch (phase) {
      case EndingPhase.compress:
        world.chamber.displayedPressure =
            (phaseAge / GameConstants.supernovaCompress).clamp(0.0, 1.0);
        world.chamber.flare = 1;
        final t = (phaseAge / GameConstants.supernovaCompress).clamp(0.0, 1.0);
        final pull = t * t;
        for (final entry in _vent.entries) {
          final n = entry.key;
          final s = entry.value;
          if (!n.isMounted) continue;
          final pos = s.origin * (1 - pull * 0.92);
          n.body.setTransform(pos, n.body.angle);
          n.body.linearVelocity.setZero();
        }
        if (phaseAge >= GameConstants.supernovaCompress) {
          phase = EndingPhase.detonate;
          phaseAge = 0;
          onFlash(GameConstants.kSupernovaFlashSeconds);
          onShake(GameConstants.kSupernovaShakeSeconds, 18);
          world.add(ScreenFlash(life: GameConstants.supernovaDetonate + 0.05));
          world.chamber.broken = true;
          world.chamber.breakProgress = 0;
        }
      case EndingPhase.detonate:
        world.chamber.breakProgress =
            (phaseAge / GameConstants.supernovaDetonate).clamp(0.0, 1.0);
        if (phaseAge >= GameConstants.supernovaDetonate) {
          phase = EndingPhase.expand;
          phaseAge = 0;
          for (final entry in _vent.entries) {
            entry.value.speed = 280 + _rng.nextDouble() * 220;
          }
        }
      case EndingPhase.expand:
        world.chamber.breakProgress = 1;
        final t = (phaseAge / GameConstants.supernovaExpand).clamp(0.0, 1.0);
        for (final entry in _vent.entries) {
          final n = entry.key;
          final s = entry.value;
          if (!n.isMounted) continue;
          final pos = s.dir * (s.speed * t * GameConstants.supernovaExpand * 0.35);
          n.body.setTransform(pos, n.body.angle);
          n.renderOpacity = (1 - t).clamp(0.0, 1.0);
        }
        if (phaseAge >= GameConstants.supernovaExpand) {
          for (final n in List<Nucleus>.from(world.nuclei)) {
            if (n.isMounted) n.removeFromParent();
          }
          _spawnSeeds();
          phase = EndingPhase.seed;
          phaseAge = 0;
        }
      case EndingPhase.seed:
        if (phaseAge >= GameConstants.supernovaSeed) {
          _goToCard();
        }
      default:
        break;
    }
  }

  void _spawnSeeds() {
    final picks = List<String>.from(SeedElements.prioritized)..shuffle(_rng);
    final count = 12 + _rng.nextInt(7);
    for (var i = 0; i < count; i++) {
      final symbol = picks[i % picks.length];
      final angle = _rng.nextDouble() * math.pi * 2;
      final speed = 35 + _rng.nextDouble() * 90;
      world.add(
        SeedParticle(
          symbol: symbol,
          color: SeedElements.colors[i % SeedElements.colors.length],
          velocity: Vector2(math.cos(angle), math.sin(angle)) * speed,
          appearDelay: _rng.nextDouble() * 1.0,
        ),
      );
    }
  }
}

class _VentState {
  _VentState({
    required this.origin,
    required this.dir,
    required this.speed,
    required this.delay,
    required this.startScale,
  });

  final Vector2 origin;
  final Vector2 dir;
  double speed;
  final double delay;
  final double startScale;
}
