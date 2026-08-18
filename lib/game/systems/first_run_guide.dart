import 'dart:async';

import 'package:flutter/foundation.dart';

import '../element_tier.dart';

/// First-run coach beats for a live guided play session.
enum FirstRunStep {
  inject,
  fuse,
  sink,
  iron,
  containment,
  done,
}

/// Advances short tips from real play events. Does not block input.
class FirstRunGuide {
  FirstRunGuide({required this.onCompleted});

  final VoidCallback onCompleted;

  final ValueNotifier<FirstRunStep> step =
      ValueNotifier(FirstRunStep.inject);
  final ValueNotifier<String?> tipText = ValueNotifier(_copy[FirstRunStep.inject]);

  bool get isActive => step.value != FirstRunStep.done;

  static const _rimTeachPressure = 0.22;
  static const _ironFallbackSeconds = 14.0;
  static const _containmentFallbackSeconds = 8.0;
  static const _finishHoldSeconds = 5.0;

  Timer? _fallbackTimer;
  Timer? _finishTimer;
  bool _completed = false;

  static const Map<FirstRunStep, String> _copy = {
    FirstRunStep.inject:
        'Drag around the rim to aim. Hold to charge. Release to inject.',
    FirstRunStep.fuse:
        'Matching light elements fuse. Helium can also step a heavier piece up the ladder.',
    FirstRunStep.sink:
        'Heavy nuclei sink toward the core. Light ones drift out — keep the rim clear.',
    FirstRunStep.iron:
        'Two irons in contact detonate. Useful clearing — dangerous if the rim is crowded.',
    FirstRunStep.containment:
        'Too much against the rim for too long fails the vessel. Watch the rim warm amber to red.',
  };

  void dispose() {
    _fallbackTimer?.cancel();
    _finishTimer?.cancel();
    tipText.dispose();
    step.dispose();
  }

  void skip() => _finish();

  /// Manual next-tip. Last step completes the guide.
  void advance() {
    if (_completed) return;
    final current = step.value;
    if (current == FirstRunStep.done) return;
    final next = FirstRunStep.values[current.index + 1];
    if (next == FirstRunStep.done) {
      _finish();
      return;
    }
    _advanceTo(next);
    if (next == FirstRunStep.containment) {
      _armFinishHold();
    }
  }

  void onShotFired() {
    if (step.value == FirstRunStep.inject) {
      _advanceTo(FirstRunStep.fuse);
    }
  }

  void onMerge() {
    if (step.value == FirstRunStep.fuse) {
      _advanceTo(FirstRunStep.sink);
      _armFallback(_ironFallbackSeconds, () {
        if (step.value == FirstRunStep.sink) {
          _advanceTo(FirstRunStep.iron);
          _armContainmentFallback();
        }
      });
    }
  }

  void onTierReached(ElementTier tier) {
    if (tier.tier < ElementTier.silicon.tier) return;
    if (step.value == FirstRunStep.sink ||
        step.value == FirstRunStep.fuse) {
      // Jump forward if they somehow skipped ahead while still on early tips.
      if (step.value == FirstRunStep.fuse) {
        _advanceTo(FirstRunStep.sink);
      }
      _advanceTo(FirstRunStep.iron);
      _armContainmentFallback();
    }
  }

  void onRimPressure(double normalized01) {
    if (normalized01 < _rimTeachPressure) return;
    if (step.value == FirstRunStep.iron ||
        step.value == FirstRunStep.sink) {
      _advanceTo(FirstRunStep.containment);
      _armFinishHold();
    }
  }

  void _armContainmentFallback() {
    _armFallback(_containmentFallbackSeconds, () {
      if (step.value == FirstRunStep.iron) {
        _advanceTo(FirstRunStep.containment);
        _armFinishHold();
      }
    });
  }

  void _armFinishHold() {
    _fallbackTimer?.cancel();
    _finishTimer?.cancel();
    _finishTimer = Timer(
      Duration(milliseconds: (_finishHoldSeconds * 1000).round()),
      _finish,
    );
  }

  void _armFallback(double seconds, VoidCallback action) {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(
      Duration(milliseconds: (seconds * 1000).round()),
      action,
    );
  }

  void _advanceTo(FirstRunStep next) {
    if (_completed) return;
    final current = step.value;
    if (current == FirstRunStep.done) return;
    if (next.index <= current.index) return;
    step.value = next;
    tipText.value = _copy[next];
  }

  void _finish() {
    if (_completed) return;
    _completed = true;
    _fallbackTimer?.cancel();
    _finishTimer?.cancel();
    step.value = FirstRunStep.done;
    tipText.value = null;
    onCompleted();
  }
}
