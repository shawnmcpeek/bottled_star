import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../element_tier.dart';
import '../modes/game_mode.dart';

/// One-shot SFX: per-mode guitar plucks on merge, spring on Fe+Fe / kilonova,
/// and a low-string sting on white dwarf / Challenge lost.
///
/// Each ladder rung is a baked AAC `.m4a` (iOS AVPlayer ignores pitch on
/// `playbackRate`). Classic = harmonic minor, Collapse = diminished,
/// Challenge = augmented. Android still uses [PlayerMode.lowLatency].
class SfxController {
  SfxController._();
  static final SfxController instance = SfxController._();

  static const _springAsset = 'sfx/spring_metal.m4a';
  static const gameOverAsset = 'sfx/game_over.m4a';

  static const int _pluckPoolSize = 4;

  final List<AudioPlayer> _plucks = [];
  AudioPlayer? _spring;
  AudioPlayer? _gameOver;
  int _pluckIndex = 0;
  bool enabled = true;
  bool _ready = false;
  Future<void>? _preloadFuture;
  double _volume = 0.75;

  static const double _pluckGain = 0.75;
  static const double _springGain = 1.0;
  static const double _gameOverGain = 0.9;

  static bool get _preferLowLatency =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static String pluckFolderFor(GameMode mode) => switch (mode) {
    GameMode.classic => 'harmonic_minor',
    GameMode.collapse => 'diminished',
    GameMode.challenge => 'augmented',
  };

  static String pluckAssetFor({
    required GameMode mode,
    required ElementTier tier,
  }) {
    final index = tier.tier
        .clamp(0, ElementTier.iron.tier)
        .toString()
        .padLeft(2, '0');
    return 'sfx/plucks/${pluckFolderFor(mode)}/$index.m4a';
  }

  static List<String> get _allPluckAssets => [
    for (final mode in GameMode.values)
      for (final tier in ElementTier.values)
        pluckAssetFor(mode: mode, tier: tier),
  ];

  /// 0..1 master SFX level (applied relative to pluck/spring gains).
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (!_ready) return;
    for (final p in _plucks) {
      await p.setVolume(_volume * _pluckGain);
    }
    await _spring?.setVolume(_volume * _springGain);
    await _gameOver?.setVolume(_volume * _gameOverGain);
  }

  /// Warm cache + players early (menu / mode select) so first merge is instant.
  Future<void> preload() {
    return _preloadFuture ??= _doPreload();
  }

  Future<void> _doPreload() async {
    try {
      await AudioPlayer.global.setAudioContext(_sfxContext);
      await AudioCache.instance.loadAll([
        _springAsset,
        gameOverAsset,
        ..._allPluckAssets,
      ]);

      for (var i = 0; i < _pluckPoolSize; i++) {
        _plucks.add(await _makePlayer(volume: _volume * _pluckGain));
      }
      _spring = await _makePlayer(volume: _volume * _springGain);
      _gameOver = await _makePlayer(volume: _volume * _gameOverGain);
      _ready = true;
      debugPrint('SfxController ready (lowLatency=$_preferLowLatency)');
    } catch (e, st) {
      _preloadFuture = null;
      _plucks.clear();
      _spring = null;
      _gameOver = null;
      _ready = false;
      debugPrint('SfxController preload failed: $e\n$st');
    }
  }

  Future<AudioPlayer> _makePlayer({required double volume}) async {
    final player = AudioPlayer();
    if (_preferLowLatency) {
      await player.setPlayerMode(PlayerMode.lowLatency);
    }
    await player.setAudioContext(_sfxContext);
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setVolume(volume);
    return player;
  }

  /// Ambient so SFX and music share one session without exclusive playback focus.
  /// (mixWithOthers is only legal with playback / playAndRecord / multiRoute.)
  static final AudioContext _sfxContext = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
      stayAwake: false,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  /// Soft nylon pluck for the product's ladder rung in this mode's scale.
  void playMergePluck(ElementTier result, {required GameMode mode}) {
    if (!enabled) return;
    unawaited(_playPluck(pluckAssetFor(mode: mode, tier: result)));
  }

  Future<void> _playPluck(String asset) async {
    if (!_ready) await preload();
    if (_plucks.isEmpty) return;
    final player = _plucks[_pluckIndex];
    _pluckIndex = (_pluckIndex + 1) % _plucks.length;
    try {
      await player.stop();
      await player.setVolume(_volume * _pluckGain);
      await player.play(AssetSource(asset));
    } catch (e) {
      debugPrint('Sfx pluck failed: $e');
    }
  }

  /// Sci-fi spring for Fe+Fe supernova and remnant kilonova.
  void playSpringHit() {
    if (!enabled) return;
    unawaited(_playNamed(_SfxOneShot.spring));
  }

  /// Low-string cadence for white dwarf and Challenge lost.
  void playGameOver() {
    if (!enabled) return;
    unawaited(_playNamed(_SfxOneShot.gameOver));
  }

  Future<void> _playNamed(_SfxOneShot shot) async {
    if (!_ready) await preload();
    final player = switch (shot) {
      _SfxOneShot.spring => _spring,
      _SfxOneShot.gameOver => _gameOver,
    };
    if (player == null) return;
    try {
      await player.stop();
      await player.setVolume(_volume * shot.gain);
      await player.play(AssetSource(shot.asset));
    } catch (e) {
      debugPrint('Sfx ${shot.label} failed: $e');
    }
  }

  Future<void> stopAll() async {
    for (final p in _plucks) {
      await p.stop();
    }
    await _spring?.stop();
    await _gameOver?.stop();
  }
}

enum _SfxOneShot {
  spring,
  gameOver;

  String get asset => switch (this) {
    spring => SfxController._springAsset,
    gameOver => SfxController.gameOverAsset,
  };

  double get gain => switch (this) {
    spring => SfxController._springGain,
    gameOver => SfxController._gameOverGain,
  };

  String get label => switch (this) {
    spring => 'spring',
    gameOver => 'game over',
  };
}
