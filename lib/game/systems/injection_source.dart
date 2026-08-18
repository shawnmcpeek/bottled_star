import '../element_tier.dart';

/// Shared contract for Classic's weighted [InjectionQueue] and Challenge's
/// fixed sequence. Challenge never expands the pool via [onHighestTier].
abstract interface class InjectionSource {
  ElementTier get current;
  ElementTier get next;
  ElementTier consume();
  void reset();
  void onHighestTier(int highestTier);
  bool get isExhausted;
}
