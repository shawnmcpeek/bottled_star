import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'level_spec.dart';

/// Loads and caches Challenge pack files from the asset bundle.
class LevelLibrary {
  LevelLibrary({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  final Map<int, LevelPack> _packs = {};
  final Map<String, LevelSpec> _byId = {};
  bool _loaded = false;

  static const List<String> packAssetPaths = [
    'assets/levels/pack1.json',
  ];

  bool get isLoaded => _loaded;

  /// Play-order list across all loaded packs (pack order, then array order).
  List<LevelSpec> get allLevels => [
        for (final packNum in _packs.keys.toList()..sort())
          ..._packs[packNum]!.levels,
      ];

  LevelPack? pack(int number) => _packs[number];

  LevelSpec? byId(String id) => _byId[id];

  LevelSpec require(String id) {
    final level = _byId[id];
    if (level == null) {
      throw LevelParseException('level id "$id" not found');
    }
    return level;
  }

  /// Load every known pack asset. Safe to call more than once.
  Future<void> loadAll() async {
    if (_loaded) return;
    for (final path in packAssetPaths) {
      await loadPackAsset(path);
    }
    _loaded = true;
  }

  Future<LevelPack> loadPackAsset(String assetPath) async {
    final source = await _bundle.loadString(assetPath);
    return loadPackJson(source);
  }

  LevelPack loadPackJson(String source) {
    final pack = LevelPack.fromJsonString(source);
    for (final level in pack.levels) {
      final existing = _byId[level.id];
      if (existing != null) {
        throw LevelParseException(
          'duplicate level id "${level.id}" across packs '
          '(pack ${existing.pack} and pack ${pack.pack})',
          levelId: level.id,
        );
      }
      _byId[level.id] = level;
    }
    _packs[pack.pack] = pack;
    return pack;
  }

  void clear() {
    _packs.clear();
    _byId.clear();
    _loaded = false;
  }

  /// Debug-only full validation over every pack asset.
  ///
  /// Release builds skip this — malformed levels should already fail CI via
  /// unit tests, and players should not pay for the asset scan at startup.
  static Future<void> assertValidInDebug({AssetBundle? bundle}) async {
    if (!kDebugMode) return;
    final lib = LevelLibrary(bundle: bundle);
    await lib.loadAll();
    assert(lib.allLevels.isNotEmpty, 'Challenge pack1 must contain levels');
  }
}
