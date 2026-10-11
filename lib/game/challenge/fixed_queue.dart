import '../element_tier.dart';
import '../systems/injection_source.dart';

/// Fixed-sequence injector for Challenge levels.
///
/// Walks [sequence] in order. [onHighestTier] is a no-op — the queue never
/// expands from board progress.
class FixedInjectionQueue implements InjectionSource {
  FixedInjectionQueue({
    required List<ElementTier> sequence,
    this.visibleCount = 3,
  }) : sequence = List<ElementTier>.unmodifiable(sequence) {
    if (this.sequence.isEmpty) {
      throw ArgumentError('FixedInjectionQueue sequence must be non-empty');
    }
    reset();
  }

  final List<ElementTier> sequence;

  /// How many upcoming shots the HUD shows (0 = none, 3 = current + next two).
  final int visibleCount;

  int _index = 0;

  int get index => _index;

  void restoreAt(int index) {
    _index = index.clamp(0, sequence.length);
  }

  @override
  ElementTier get current {
    if (isExhausted) {
      throw StateError('FixedInjectionQueue is exhausted');
    }
    return sequence[_index];
  }

  @override
  ElementTier get next {
    if (isExhausted) {
      throw StateError('FixedInjectionQueue is exhausted');
    }
    if (_index + 1 < sequence.length) return sequence[_index + 1];
    return sequence[_index];
  }

  @override
  bool get isExhausted => _index >= sequence.length;

  /// Upcoming shots for the HUD, capped by [visibleCount] and optional
  /// remaining shot budget so the preview never shows unfireable molecules.
  List<ElementTier> visible({int? remainingShots}) {
    if (visibleCount <= 0 || isExhausted) return const [];
    var count = visibleCount;
    if (remainingShots != null) {
      if (remainingShots <= 0) return const [];
      if (remainingShots < count) count = remainingShots;
    }
    final end = (_index + count).clamp(0, sequence.length);
    return sequence.sublist(_index, end);
  }

  /// Next queue entry if it can still be fired. Null on the last budgeted shot.
  ElementTier? nextIfAvailable({int? remainingShots}) {
    if (isExhausted) return null;
    if (remainingShots != null && remainingShots <= 1) return null;
    if (_index + 1 >= sequence.length) return null;
    return sequence[_index + 1];
  }

  @override
  ElementTier consume() {
    if (isExhausted) {
      throw StateError('FixedInjectionQueue is exhausted');
    }
    final fired = sequence[_index];
    _index++;
    return fired;
  }

  @override
  void reset() {
    _index = 0;
  }

  @override
  void onHighestTier(int highestTier) {
    // Fixed queues ignore board progress.
  }
}
