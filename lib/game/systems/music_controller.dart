import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../modes/game_mode.dart';

/// Loops ambient tracks during a run; picks a different track each play.
///
/// Assets are AAC `.m4a` — iOS AVPlayer does not play Ogg Vorbis, and awaiting
/// a failed/hung [play] used to block mode-select navigation entirely.
class MusicController {
  MusicController._();
  static final MusicController instance = MusicController._();

  /// Shared Classic / Collapse pool.
  static const List<String> sharedTracks = [
    'music/loops/documentary_meditative.m4a',
    'music/loops/new_ambient.m4a',
    'music/loops/quiet_night.m4a',
    'music/loops/space_ambient.m4a',
  ];

  /// Collapse-only.
  static const String collapseExclusive = 'music/loops/world_is_frozen.m4a';

  final AudioPlayer _player = AudioPlayer();
  final Random _random = Random();
  bool _ready = false;
  String? _currentTrack;
  GameMode? _modeForCurrent;
  double _volume = 0.7;

  bool get isPlaying => _player.state == PlayerState.playing;

  static final AudioContext _musicContext = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
      stayAwake: false,
    ),
    // ambient already mixes with other players/apps; mixWithOthers is illegal here.
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.ambient,
    ),
  );

  /// 0..1 master music level.
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (_ready) {
      await _player.setVolume(_volume);
    }
  }

  static List<String> tracksFor(GameMode mode) {
    if (mode == GameMode.collapse) {
      return [...sharedTracks, collapseExclusive];
    }
    return sharedTracks;
  }

  Future<void> _ensureReady() async {
    if (_ready) return;
    await _player.setAudioContext(_musicContext);
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(_volume);
    _ready = true;
  }

  Future<String> _nextTrack(GameMode mode) async {
    final tracks = tracksFor(mode);
    final prefs = await SharedPreferences.getInstance();
    final key = '${GameConstants.prefsLastMusicIndex}_${mode.name}';
    final last = prefs.getInt(key);
    if (tracks.length == 1) return tracks.first;

    var index = _random.nextInt(tracks.length);
    if (last != null && tracks.length > 1) {
      while (index == last) {
        index = _random.nextInt(tracks.length);
      }
    }
    await prefs.setInt(key, index);
    return tracks[index];
  }

  /// Start (or restart) a looped ambient track for a new play session.
  ///
  /// Never throws — callers may fire-and-forget so navigation is never blocked.
  Future<void> startForRun({
    required bool enabled,
    required GameMode mode,
  }) async {
    if (!enabled) {
      await stop();
      return;
    }
    try {
      await _ensureReady();
      final track = await _nextTrack(mode);
      _currentTrack = track;
      _modeForCurrent = mode;
      await _player.stop();
      await _player
          .play(AssetSource(track))
          .timeout(const Duration(seconds: 4));
    } catch (e, st) {
      debugPrint('MusicController.startForRun failed: $e\n$st');
    }
  }

  /// Resume or kick off playback if autoplay was blocked (e.g. web).
  Future<void> ensurePlaying({
    required bool enabled,
    required GameMode mode,
  }) async {
    if (!enabled) return;
    try {
      if (isPlaying && _modeForCurrent == mode) return;
      if (_currentTrack != null && _modeForCurrent == mode) {
        await _player.resume();
        if (isPlaying) return;
        await _player
            .play(AssetSource(_currentTrack!))
            .timeout(const Duration(seconds: 4));
        if (isPlaying) return;
      }
      await startForRun(enabled: enabled, mode: mode);
    } catch (e, st) {
      debugPrint('MusicController.ensurePlaying failed: $e\n$st');
    }
  }

  Future<void> pause() async {
    try {
      if (_player.state == PlayerState.playing) {
        await _player.pause();
      }
    } catch (e) {
      debugPrint('MusicController.pause failed: $e');
    }
  }

  Future<void> resume({required bool enabled}) async {
    if (!enabled || _currentTrack == null) return;
    try {
      if (_player.state == PlayerState.paused) {
        await _player.resume();
      }
    } catch (e) {
      debugPrint('MusicController.resume failed: $e');
    }
  }

  Future<void> stop() async {
    _currentTrack = null;
    _modeForCurrent = null;
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('MusicController.stop failed: $e');
    }
  }
}
