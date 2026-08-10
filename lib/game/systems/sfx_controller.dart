import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../element_tier.dart';

/// One-shot SFX: pentatonic guitar plucks on merge, spring hit on Fe+Fe / kilonova.
///
/// Players are pooled and warmed at menu time. Playback uses [play] with a
/// cached [AssetSource] — reliable across Android / iOS / Linux / web.
/// Android still opts into [PlayerMode.lowLatency] where SoundPool helps.
class SfxController {
  SfxController._();
  static final SfxController instance = SfxController._();

  static const _guitarAsset = 'sfx/guitar_string.ogg';
  static const _springAsset = 'sfx/spring_metal.ogg';

  /// Minor-pentatonic climb H→Fe across one octave (rates stay in 0.5→1.0).
  /// Below ~0.5 many backends ignore playbackRate and play at 1.0 — which made
  /// early merges (He) sound higher than later ones.
  static const List<int> _semitones = [
    0, 3, 5, 7, 10, 12, 15, 17, 19, 22, 24,
  ];

  static const int _pluckPoolSize = 4;

  final List<AudioPlayer> _plucks = [];
  AudioPlayer? _spring;
  int _pluckIndex = 0;
  bool enabled = true;
  bool _ready = false;
  Future<void>? _preloadFuture;
  double _volume = 0.75;

  static const double _pluckGain = 0.75;
  static const double _springGain = 1.0;

  static bool get _preferLowLatency =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 0..1 master SFX level (applied relative to pluck/spring gains).
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (!_ready) return;
    for (final p in _plucks) {
      await p.setVolume(_volume * _pluckGain);
    }
    await _spring?.setVolume(_volume * _springGain);
  }

  /// Warm cache + players early (menu / mode select) so first merge is instant.
  Future<void> preload() {
    return _preloadFuture ??= _doPreload();
  }

  Future<void> _doPreload() async {
    try {
      await AudioPlayer.global.setAudioContext(_sfxContext);
      await AudioCache.instance.loadAll(const [_guitarAsset, _springAsset]);

      for (var i = 0; i < _pluckPoolSize; i++) {
        _plucks.add(await _makePlayer(volume: _volume * _pluckGain));
      }
      _spring = await _makePlayer(volume: _volume * _springGain);
      _ready = true;
      debugPrint('SfxController ready (lowLatency=$_preferLowLatency)');
    } catch (e, st) {
      _preloadFuture = null;
      _plucks.clear();
      _spring = null;
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

  static final AudioContext _sfxContext = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
      stayAwake: false,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
  );

  static double rateForTier(ElementTier tier) {
    final i = tier.tier.clamp(0, _semitones.length - 1);
    // Map 0..24 semitones into one octave of rate so every step is ≥ 0.5.
    return 0.5 * math.pow(2, _semitones[i] / 24.0);
  }

  /// Soft nylon pluck pitched to the product's ladder rung.
  void playMergePluck(ElementTier result) {
    if (!enabled) return;
    final rate = rateForTier(result);
    unawaited(_playPluck(rate));
  }

  Future<void> _playPluck(double rate) async {
    if (!_ready) await preload();
    if (_plucks.isEmpty) return;
    final player = _plucks[_pluckIndex];
    _pluckIndex = (_pluckIndex + 1) % _plucks.length;
    try {
      await player.stop();
      await player.setVolume(_volume * _pluckGain);
      await player.play(AssetSource(_guitarAsset));
      // Apply after play — some backends reset rate when starting a source.
      await player.setPlaybackRate(rate);
    } catch (e) {
      debugPrint('Sfx pluck failed: $e');
    }
  }

  /// Sci-fi spring for Fe+Fe supernova and remnant kilonova.
  void playSpringHit() {
    if (!enabled) return;
    unawaited(_playSpring());
  }

  Future<void> _playSpring() async {
    if (!_ready) await preload();
    final player = _spring;
    if (player == null) return;
    try {
      await player.stop();
      await player.setVolume(_volume * _springGain);
      await player.setPlaybackRate(1.0);
      await player.play(AssetSource(_springAsset));
    } catch (e) {
      debugPrint('Sfx spring failed: $e');
    }
  }

  Future<void> stopAll() async {
    for (final p in _plucks) {
      await p.stop();
    }
    await _spring?.stop();
  }
}
