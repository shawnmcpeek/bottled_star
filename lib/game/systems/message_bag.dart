import 'dart:math';

/// Draws unseen entries first; reshuffles only when the pool is exhausted.
class MessageBag {
  MessageBag(this._all, [Set<int>? seen]) : _seen = {...?seen};

  final List<String> _all;
  final Set<int> _seen;

  List<String> get all => List.unmodifiable(_all);
  Set<int> get seen => Set.unmodifiable(_seen);

  String draw(Random rng) {
    var pool = [
      for (var i = 0; i < _all.length; i++)
        if (!_seen.contains(i)) i,
    ];
    if (pool.isEmpty) {
      _seen.clear();
      pool = List.generate(_all.length, (i) => i);
    }
    final pick = pool[rng.nextInt(pool.length)];
    _seen.add(pick);
    return _all[pick];
  }

  /// Index-aware draw for stable message ids across reshuffles.
  ({String text, int index}) drawIndexed(Random rng) {
    var pool = [
      for (var i = 0; i < _all.length; i++)
        if (!_seen.contains(i)) i,
    ];
    if (pool.isEmpty) {
      _seen.clear();
      pool = List.generate(_all.length, (i) => i);
    }
    final pick = pool[rng.nextInt(pool.length)];
    _seen.add(pick);
    return (text: _all[pick], index: pick);
  }
}
