import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

class UrsaAudio {
  UrsaAudio({this.enabled = true});

  static final AudioContext _mixingAudioContext = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const <AVAudioSessionOptions>{
        AVAudioSessionOptions.mixWithOthers,
      },
    ),
  );

  static const List<String> _sfxNames = <String>[
    'avalanche',
    'break',
    'check_point',
    'claw',
    'collect',
    'eat',
    'enemy_hit',
    'hurt',
    'ice_crack',
    'jump',
    'land',
    'menu_confirm',
    'menu_open',
    'pickup',
    'pound',
    'power_up',
    'restart',
    'shift',
    'sniff',
    'steam',
    'tackle',
    'win',
    'wind_gust',
  ];

  final bool enabled;
  Future<void>? _initializing;
  Future<void> _musicQueue = Future<void>.value();
  AudioPlayer? _ambientPlayer;
  String? _musicName;
  String? _ambientName;
  bool _disposed = false;

  static const double _musicVolume = 0.5;
  static const double _ambientVolume = 0.16;

  /// Master volume 0..1 applied on top of each sound's own level.
  double masterVolume = 1;

  Future<void> setMasterVolume(double value) async {
    masterVolume = value.clamp(0.0, 1.0);
    if (!enabled || _disposed) return;
    try {
      await FlameAudio.bgm.audioPlayer.setVolume(_musicVolume * masterVolume);
      await _ambientPlayer?.setVolume(_ambientVolume * masterVolume);
    } catch (error) {
      debugPrint('URSA volume change failed: $error');
    }
  }

  Future<void> initialize() {
    if (!enabled || _disposed) return Future<void>.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      await FlameAudio.bgm.initialize(audioContext: _mixingAudioContext);
    } catch (error) {
      // Audio may be unavailable in widget tests or muted by the platform.
      debugPrint('URSA audio init failed: $error');
    }
    // Copy effects to the cache in the background so the first play of a
    // sound (e.g. on death) is not delayed by the asset copy. Not awaited:
    // music and effects wait on initialize() and must not wait for this.
    unawaited(_preloadSfx());
  }

  Future<void> _preloadSfx() async {
    for (final name in _sfxNames) {
      if (_disposed) return;
      try {
        await FlameAudio.audioCache.load('$name.mp3');
      } catch (error) {
        debugPrint('URSA sfx preload $name failed: $error');
      }
    }
  }

  void playSfx(String name, {double volume = 0.62}) {
    unawaited(_playSfx(name, volume));
  }

  Future<void> _playSfx(String name, double volume) async {
    if (!enabled || _disposed || masterVolume <= 0) return;
    final player = AudioPlayer()..audioCache = FlameAudio.audioCache;
    player.onPlayerComplete.listen((_) {
      unawaited(player.dispose());
    });
    try {
      await initialize();
      await player.setAudioContext(_mixingAudioContext);
      await player.setVolume((volume * masterVolume).clamp(0, 1).toDouble());
      await player.play(AssetSource('$name.mp3'));
    } catch (error) {
      debugPrint('URSA sfx $name failed: $error');
      // Keep gameplay running if a user-replaced audio file is invalid.
      try {
        await player.dispose();
      } catch (_) {
        // The audio backend may already have released the player.
      }
    }
  }

  void playMusic(String name) {
    if (!enabled || _disposed || _musicName == name) return;
    _musicName = name;
    _musicQueue = _musicQueue.then((_) async {
      if (_disposed || _musicName != name) return;
      try {
        await initialize();
        await FlameAudio.bgm.play('$name.mp3', volume: _musicVolume * masterVolume);
      } catch (error) {
        debugPrint('URSA music $name failed: $error');
        if (_musicName == name) _musicName = null;
      }
    });
  }

  void playAmbient(String? name) {
    if (!enabled || _disposed || _ambientName == name) return;
    _ambientName = name;
    unawaited(_switchAmbient(name));
  }

  Future<void> _switchAmbient(String? name) async {
    final previous = _ambientPlayer;
    _ambientPlayer = null;
    if (previous != null) {
      try {
        await previous.stop();
        await previous.dispose();
      } catch (_) {
        // The player may already have been released by the audio backend.
      }
    }
    if (name == null || _disposed || _ambientName != name) return;
    try {
      await initialize();
      final player = await FlameAudio.loopLongAudio(
        '$name.mp3',
        volume: _ambientVolume * masterVolume,
        audioContext: _mixingAudioContext,
      );
      if (_disposed || _ambientName != name) {
        await player.stop();
        await player.dispose();
      } else {
        _ambientPlayer = player;
      }
    } catch (error) {
      debugPrint('URSA ambient $name failed: $error');
      // Ambient audio is optional and must never block a level transition.
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    if (!enabled) return;
    _ambientName = null;
    final ambient = _ambientPlayer;
    _ambientPlayer = null;
    try {
      await ambient?.stop();
      await ambient?.dispose();
      await FlameAudio.bgm.stop();
      await FlameAudio.bgm.dispose();
    } catch (_) {
      // Platform audio may already be disposed during app shutdown.
    }
  }
}
