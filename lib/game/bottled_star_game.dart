import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'constants.dart';
import 'element_art.dart';
import 'element_tier.dart';
import 'modes/game_mode.dart';
import 'systems/bottled_star_world.dart';
import 'systems/first_run_guide.dart';
import 'systems/score_store.dart';

class BottledStarGame extends Forge2DGame<BottledStarWorld>
    with MultiTouchDragDetector, KeyboardEvents {
  BottledStarGame({
    required this.scoreStore,
    this.mode = GameMode.classic,
  }) : super(
          world: BottledStarWorld(mode: mode),
          gravity: Vector2.zero(),
          zoom: 1,
        ) {
    world
      ..onScore = _handleScore
      ..onGameOver = _handleGameOver
      ..onTierReached = _handleTier
      ..onQueueChanged = _handleQueue
      ..onEndingCard = _handleEndingCard
      ..onFlash = _handleFlash
      ..onShake = _handleShake
      ..onShotFired = _handleShotFired
      ..onMerge = _handleMerge
      ..onRimPressure = _handleRimPressure;
  }

  final ScoreStore scoreStore;
  final GameMode mode;
  FirstRunGuide? firstRunGuide;

  final ValueNotifier<int> scoreNotifier = ValueNotifier(0);
  final ValueNotifier<int> highScoreNotifier = ValueNotifier(0);
  final ValueNotifier<String> bestElementNotifier = ValueNotifier('—');
  final ValueNotifier<bool> gameOverNotifier = ValueNotifier(false);
  final ValueNotifier<bool> endingCardNotifier = ValueNotifier(false);
  final ValueNotifier<RunEnding?> endingNotifier = ValueNotifier(null);
  final ValueNotifier<ElementTier?> lastUnlockNotifier = ValueNotifier(null);
  final ValueNotifier<ElementTier> currentShotNotifier =
      ValueNotifier(ElementTier.hydrogen);
  final ValueNotifier<ElementTier> nextShotNotifier =
      ValueNotifier(ElementTier.hydrogen);
  final ValueNotifier<double> flashNotifier = ValueNotifier(0);
  final ValueNotifier<int> peakTierNotifier = ValueNotifier(0);
  final ValueNotifier<String?> endingLineNotifier = ValueNotifier(null);

  bool _pointerDown = false;
  int? _activePointer;
  bool _spaceDown = false;
  Set<LogicalKeyboardKey> _keys = {};

  double _shakeTime = 0;
  double _shakeDuration = 0;
  double _shakeIntensity = 0;
  Vector2 _cameraBase = Vector2.zero();
  double _flashTime = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await ElementArt.preload(images);
    await scoreStore.load();
    highScoreNotifier.value = scoreStore.highScore;
    bestElementNotifier.value = scoreStore.highestTier > 0
        ? ElementTier.fromTier(scoreStore.highestTier).symbol
        : '—';

    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = Vector2.zero();
    _cameraBase = Vector2.zero();
    _fitCamera();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _fitCamera();
  }

  void _fitCamera() {
    final view = camera.viewport.size;
    if (view.x <= 0 || view.y <= 0) return;
    final needed = GameConstants.chamberRadius * 2.55;
    final zoom = math.min(view.x, view.y) / needed;
    camera.viewfinder.zoom = zoom;
  }

  void _handleScore(int delta, int total) {
    scoreNotifier.value = total;
  }

  void _handleTier(ElementTier tier) {
    lastUnlockNotifier.value = tier;
    peakTierNotifier.value = world.highestTier;
    if (tier.tier > scoreStore.highestTier) {
      bestElementNotifier.value = tier.symbol;
    }
    firstRunGuide?.onTierReached(tier);
  }

  void _handleShotFired() {
    firstRunGuide?.onShotFired();
  }

  void _handleMerge() {
    firstRunGuide?.onMerge();
  }

  void _handleRimPressure(double normalized01) {
    firstRunGuide?.onRimPressure(normalized01);
  }

  void _handleQueue(ElementTier current, ElementTier next) {
    currentShotNotifier.value = current;
    nextShotNotifier.value = next;
  }

  Future<void> _handleGameOver(RunEnding ending) async {
    gameOverNotifier.value = true;
    endingNotifier.value = ending;
    endingCardNotifier.value = false;
    peakTierNotifier.value = world.highestTier;
    final remnant = world.remnant?.state;
    final pick = await scoreStore.recordRun(
      score: world.score,
      highestTierReached: world.highestTier,
      ending: ending,
      tiersCreatedThisRun: Set<int>.from(world.tiersCreatedThisRun),
      supernovaCount: remnant?.supernovaCount ?? 0,
      consumedCount: remnant?.consumedCount ?? 0,
    );
    endingLineNotifier.value = pick.text;
    highScoreNotifier.value = scoreStore.highScore;
    if (scoreStore.highestTier > 0) {
      bestElementNotifier.value =
          ElementTier.fromTier(scoreStore.highestTier).symbol;
    }
  }

  void _handleEndingCard(RunEnding ending) {
    endingNotifier.value = ending;
    endingCardNotifier.value = true;
  }

  void _handleFlash(double seconds) {
    _flashTime = seconds;
    flashNotifier.value = 1;
  }

  void _handleShake(double seconds, double intensity) {
    _shakeTime = seconds;
    _shakeDuration = seconds;
    _shakeIntensity = intensity;
  }

  void restart() {
    world.resetRun();
    scoreNotifier.value = 0;
    gameOverNotifier.value = false;
    endingCardNotifier.value = false;
    endingNotifier.value = null;
    endingLineNotifier.value = null;
    lastUnlockNotifier.value = null;
    peakTierNotifier.value = 0;
    flashNotifier.value = 0;
    camera.viewfinder.position = _cameraBase.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_flashTime > 0) {
      _flashTime = math.max(0, _flashTime - dt);
      flashNotifier.value = (_flashTime / 0.12).clamp(0.0, 1.0);
    }

    if (_shakeTime > 0) {
      _shakeTime = math.max(0, _shakeTime - dt);
      final t = _shakeDuration <= 0 ? 0.0 : _shakeTime / _shakeDuration;
      final mag = _shakeIntensity * t * t;
      camera.viewfinder.position = _cameraBase +
          Vector2(
            (math.Random().nextDouble() - 0.5) * 2 * mag,
            (math.Random().nextDouble() - 0.5) * 2 * mag,
          );
    } else {
      camera.viewfinder.position = _cameraBase.clone();
    }

    if (!world.isLoaded || world.gameOver || !world.inputEnabled) return;

    final left = _keys.contains(LogicalKeyboardKey.arrowLeft) ||
        _keys.contains(LogicalKeyboardKey.keyA);
    final right = _keys.contains(LogicalKeyboardKey.arrowRight) ||
        _keys.contains(LogicalKeyboardKey.keyD);

    if (left && !right) {
      world.injector.rotateBy(-2.2 * dt);
    } else if (right && !left) {
      world.injector.rotateBy(2.2 * dt);
    }
  }

  @override
  void onDragStart(int pointerId, DragStartInfo info) {
    if (world.gameOver) {
      world.trySkipEnding();
      return;
    }
    if (!world.canInject) return;
    if (_activePointer != null) return;
    _activePointer = pointerId;
    _pointerDown = true;
    _aimFromScreen(info.eventPosition.widget);
    world.injector.startCharge();
  }

  @override
  void onDragUpdate(int pointerId, DragUpdateInfo info) {
    if (pointerId != _activePointer) return;
    if (world.gameOver) return;
    _aimFromScreen(info.eventPosition.widget);
  }

  @override
  void onDragEnd(int pointerId, DragEndInfo info) {
    if (pointerId != _activePointer) return;
    _activePointer = null;
    _pointerDown = false;
    if (world.gameOver) return;
    world.fireInjector();
  }

  @override
  void onDragCancel(int pointerId) {
    if (pointerId != _activePointer) return;
    _activePointer = null;
    _pointerDown = false;
    world.injector.cancelCharge();
  }

  void _aimFromScreen(Vector2 screen) {
    final worldPoint = screenToWorld(screen);
    world.injector.aimToward(worldPoint);
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    _keys = Set.of(keysPressed);

    if (world.gameOver) {
      if (event is KeyDownEvent) {
        if (!endingCardNotifier.value) {
          world.trySkipEnding();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.keyR) {
          restart();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent && !_spaceDown && !_pointerDown) {
        if (!world.canInject) return KeyEventResult.handled;
        _spaceDown = true;
        world.injector.startCharge();
        return KeyEventResult.handled;
      }
      if (event is KeyUpEvent && _spaceDown) {
        _spaceDown = false;
        world.fireInjector();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.handled;
  }
}
