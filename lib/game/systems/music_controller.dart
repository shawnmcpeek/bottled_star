import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../modes/game_mode.dart';

/// Loops ambient tracks during a run; picks a different track each play.
class MusicController {
  MusicController._();
  static final MusicController instance = MusicController._();

  /// Shared Classic / Collapse pool.
  static const List<String> sharedTracks = [
    'music/loops/documentary_meditative.ogg',
    'music/loops/new_ambient.ogg',
    'music/loops/quiet_night.ogg',
    'music/loops/space_ambient.ogg',
  ];

  /// Collapse-only.
  static const String collapseExclusive = 'music/loops/world_is_frozen.ogg';

  final AudioPlayer _player = AudioPlayer();
  final Random _random = Random();
  bool _ready = false;
  String? _currentTrack;
  GameMode? _modeForCurrent;
  double _volume = 0.7;

  bool get isPlaying => _player.state == PlayerState.playing;

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
  Future<void> startForRun({
    required bool enabled,
    required GameMode mode,
  }) async {
    if (!enabled) {
      await stop();
      return;
    }
    await _ensureReady();
    final track = await _nextTrack(mode);
    _currentTrack = track;
    _modeForCurrent = mode;
    await _player.stop();
    await _player.play(AssetSource(track));
  }

  /// Resume or kick off playback if autoplay was blocked (e.g. web).
  Future<void> ensurePlaying({
    required bool enabled,
    required GameMode mode,
  }) async {
    if (!enabled) return;
    if (isPlaying && _modeForCurrent == mode) return;
    if (_currentTrack != null && _modeForCurrent == mode) {
      await _player.resume();
      if (isPlaying) return;
      await _player.play(AssetSource(_currentTrack!));
      if (isPlaying) return;
    }
    await startForRun(enabled: enabled, mode: mode);
  }

  Future<void> pause() async {
    if (_player.state == PlayerState.playing) {
      await _player.pause();
    }
  }

  Future<void> resume({required bool enabled}) async {
    if (!enabled || _currentTrack == null) return;
    if (_player.state == PlayerState.paused) {
      await _player.resume();
    }
  }

  Future<void> stop() async {
    _currentTrack = null;
    _modeForCurrent = null;
    await _player.stop();
  }
}
