import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ursa_audio.dart';

class UrsaGame extends FlameGame {
  UrsaGame({bool audioEnabled = true, this.frameViewer = false})
    : audio = UrsaAudio(enabled: audioEnabled);

  /// Debug mode: skip the game and only show every player animation frame.
  final bool frameViewer;
  double _viewerTime = 0;
  int _viewerSkin = 0;

  static const double _worldHeight = 680;
  // World units visible vertically; less than _worldHeight zooms in, with
  // cameraY following the bear.
  static const double _viewHeight = 520;
  static const double _playerScale = 1.1;
  static const double _gravity = 1650;
  static const double _bipedSpeed = 240;
  static const double _quadSpeed = 410;

  final UrsaAudio audio;
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  final Set<String> _held = <String>{};
  final Set<String> _pressed = <String>{};
  final Set<String> _loadedImages = <String>{};
  final Map<String, Future<void>> _pendingImages = <String, Future<void>>{};
  final Map<String, dynamic> _spriteLayouts = <String, dynamic>{};
  final Map<String, dynamic> _spriteFrames = <String, dynamic>{};

  Map<String, String> _assetPaths = <String, String>{};
  SharedPreferences? _preferences;
  List<Map<String, dynamic>> areas = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> skins = <Map<String, dynamic>>[];
  Map<String, dynamic> level = <String, dynamic>{};
  List<Map<String, dynamic>> platforms = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> objects = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> pickups = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> enemies = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _effects = <Map<String, dynamic>>[];
  final Set<int> collectedClaws = <int>{};

  bool menuOpen = true;
  bool loading = true;
  bool ending = false;
  bool started = false;
  bool completed = false;
  int areaIndex = 0;
  int _highestUnlockedArea = 0;
  int totalFood = 0;
  int years = 0;
  String selectedSkin = 'brown';
  final Set<String> purchasedSkins = <String>{'brown'};
  String? message;
  double messageTimer = 0;

  double playerX = 120;
  double playerY = 570;
  double velocityX = 0;
  double velocityY = 0;
  double facing = 1;
  double cameraX = 0;
  double cameraY = _worldHeight - _viewHeight;
  double time = 0;
  double _runCycle = 0;
  double shake = 0;
  double fat = 20;
  double cold = 100;
  double heat = 0;
  double noise = 0;
  double buffTimer = 0;
  double instinctTimer = 0;
  double tractionTimer = 0;
  double areaTimer = 0;
  double invulnerable = 0;
  double transitionTimer = 0;
  double _uiNotifyTimer = 0;
  double _checkpointX = 120;
  double _checkpointY = 570;
  final Map<int, List<double>> _savedCheckpoints = <int, List<double>>{};
  bool _respawnAtCheckpoint = false;
  int health = 3;
  String mode = 'quad';
  bool grounded = true;
  bool moving = false;
  bool _actionReverse = false;
  bool _wasInWindZone = false;
  bool _restartAreaPending = false;
  double _actionAge = 0;
  double _actionDuration = 0;
  String? _actionSheet;
  String? _actionAnimation;

  bool get controlsVisible => started && !menuOpen && !loading && !ending;
  String get areaName => _text(level['name'], 'Hutan Rumah');
  String get season => _text(level['season'], 'MUSIM SEMI');
  int get clawCount => collectedClaws.length;
  int get highestUnlockedArea => _highestUnlockedArea;

  String? imageAssetPath(String key) {
    final path = _assetPaths[key];
    return path == null ? null : 'assets/images/${path.split('/').last}';
  }

  String get meterLabel {
    if (_bool(level['noise'])) return 'BISING';
    if (_bool(level['heat'])) return 'PANAS';
    if (_bool(level['cold'])) return 'HANGAT';
    if (areaIndex == 7) return 'LEMAK';
    if (buffTimer > 0) return 'TENAGA';
    return '';
  }

  double get meterValue {
    if (_bool(level['noise'])) return noise;
    if (_bool(level['heat'])) return heat;
    if (_bool(level['cold'])) return cold;
    if (areaIndex == 7) return fat;
    if (buffTimer > 0) return math.min(100, buffTimer * 12.5);
    return 0;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final manifest =
        jsonDecode(
              await rootBundle.loadString('assets/json/asset_manifest.json'),
            )
            as Map<String, dynamic>;
    _assetPaths = manifest.map((key, value) => MapEntry(key, value.toString()));

    final gameData =
        jsonDecode(await rootBundle.loadString('assets/json/game_data.json'))
            as Map<String, dynamic>;
    areas = (gameData['areas'] as List<dynamic>)
        .map(_asMap)
        .toList(growable: false);
    skins = (gameData['skins'] as List<dynamic>)
        .map(_asMap)
        .toList(growable: false);

    try {
      _preferences = await SharedPreferences.getInstance();
      final saved = _preferences?.getString('ursa.progress');
      if (saved != null) {
        final progress = jsonDecode(saved) as Map<String, dynamic>;
        final saveVersion = progress['version'];
        if (saveVersion is num && saveVersion.toInt() >= 2) {
          final savedHighestArea = progress['highestArea'];
          if (savedHighestArea is num) {
            _highestUnlockedArea = savedHighestArea.toInt().clamp(
              0,
              areas.length - 1,
            );
          }
          final savedArea = progress['currentArea'];
          if (savedArea is num) {
            areaIndex = savedArea.toInt().clamp(0, _highestUnlockedArea);
          }
          final savedSkins = progress['purchasedSkins'];
          if (savedSkins is List) {
            purchasedSkins.addAll(
              savedSkins.whereType<String>().where(
                (id) => skins.any((skin) => skin['id'] == id),
              ),
            );
          }
          final skinId = progress['selectedSkin'];
          if (skinId is String && purchasedSkins.contains(skinId)) {
            selectedSkin = skinId;
          }
        }
        final food = progress['totalFood'];
        if (food is num) totalFood = math.max(0, food.toInt());
        final savedFat = progress['fat'];
        if (savedFat is num) fat = savedFat.toDouble().clamp(0, 100);
        final savedYears = progress['years'];
        if (savedYears is num) years = math.max(0, savedYears.toInt());
          final claws = progress['collectedClaws'];
          if (claws is List) {
            collectedClaws.addAll(
              claws
                  .whereType<num>()
                  .map((value) => value.toInt())
                  .where((value) => value >= 0 && value < areas.length),
            );
          }
          final checkpoints = progress['checkpoints'];
          if (checkpoints is Map) {
            for (final entry in checkpoints.entries) {
              final key = int.tryParse(entry.key.toString());
              final value = entry.value;
              if (key != null &&
                  value is List &&
                  value.length == 2 &&
                  value[0] is num &&
                  value[1] is num) {
                _savedCheckpoints[key] = <double>[
                  value[0].toDouble(),
                  value[1].toDouble(),
                ];
              }
            }
          }
        }
      final savedVolume = _preferences?.getDouble(_volumeKey);
      if (savedVolume != null) audio.masterVolume = savedVolume.clamp(0.0, 1.0);
      final session = _preferences?.getString(_sessionKey);
      if (session != null) {
        _pendingSession = jsonDecode(session) as Map<String, dynamic>;
      }
    } catch (_) {
      _preferences = null;
    }

    final layouts =
        jsonDecode(
              await rootBundle.loadString('assets/json/sprite_layouts.json'),
            )
            as Map<String, dynamic>;
    _spriteLayouts.addAll(layouts);

    _openAreaState(areaIndex);
    if (frameViewer) {
      await _loadKeys(<String>[
        for (final skin in skins)
          for (final key in const <String>['URSA_QUAD_CORE', 'URSA_BIPED_CORE'])
            skin['sheets'] is Map ? _text((skin['sheets'] as Map)[key], key) : key,
      ]);
    }
    loading = false;
    unawaited(audio.initialize());
    _emitUi();
  }

  Future<void> _loadKeys(Iterable<String> keys) async {
    final unique = keys.toSet();
    await Future.wait(unique.map(_loadKey));
  }

  Future<void> _loadKey(String key) async {
    final assetPath = _assetPaths[key];
    if (assetPath == null) return;
    final filename = assetPath.split('/').last;
    if (_loadedImages.contains(filename)) return;
    final pending = _pendingImages[filename];
    if (pending != null) return pending;
    final future = images.load(filename).then((_) {
      _loadedImages.add(filename);
      _pendingImages.remove(filename);
    });
    _pendingImages[filename] = future;
    return future;
  }

  (ui.Rect?, ui.Offset?) _lookupFrame(
    String key, {
    String? anim,
    String? name,
    int frameIndex = 0,
  }) {
    final data = _spriteFrames[key];
    if (data is! Map) return (null, null);
    if (name != null) {
      final frames = data['frames'];
      if (frames is List) {
        for (final frame in frames) {
          if (frame is Map && frame['name'] == name) return _cropOf(frame);
        }
      }
      return (null, null);
    }
    final animations = data['animations'];
    if (animations is List) {
      for (final animation in animations) {
        if (animation is Map && animation['name'] == anim) {
          final frames = animation['frames'];
          if (frames is List && frames.isNotEmpty) {
            final index = frameIndex.clamp(0, frames.length - 1);
            return _cropOf(frames[index]);
          }
        }
      }
    }
    return (null, null);
  }

  (ui.Rect?, ui.Offset?) _cropOf(dynamic frame) {
    if (frame is! Map) return (null, null);
    final content = frame['content'];
    if (content is! Map) return (null, null);
    final rect = ui.Rect.fromLTWH(
      _number(content['x']),
      _number(content['y']),
      _number(content['w']),
      _number(content['h']),
    );
    final anchorData = frame['anchor'];
    final anchor = anchorData is Map
        ? ui.Offset(_number(anchorData['x']), _number(anchorData['y']))
        : ui.Offset(rect.left + rect.width / 2, rect.bottom);
    return (rect, anchor);
  }

  void _drawSprite(
    ui.Canvas canvas,
    String key,
    ui.Rect crop,
    double x,
    double y,
    double worldHeight,
    double facing,
    double opacity,
  ) {
    final image = _image(key);
    if (image == null) return;
    final padX = crop.width * 0.10;
    final padTop = crop.height * 0.35;
    final padBottom = crop.height * 0.04;
    // The intended (unclamped) padded rect defines the sprite's real size
    // and position so it is never scaled down or shifted when the padding
    // reaches a sheet edge (which previously cut running frames).
    final fullSource = ui.Rect.fromLTWH(
      crop.left - padX,
      crop.top - padTop,
      crop.width + padX * 2,
      crop.height + padTop + padBottom,
    );
    // Only the pixels we actually sample are clamped to the image bounds.
    final source = ui.Rect.fromLTRB(
      math.max(0.0, fullSource.left),
      math.max(0.0, fullSource.top),
      math.min(image.width.toDouble(), fullSource.right),
      math.min(image.height.toDouble(), fullSource.bottom),
    );
    final scale = worldHeight / crop.height;
    final destWidth = fullSource.width * scale;
    final destHeight = fullSource.height * scale;
    // Anchor the intended rect at (x, y) the same way as before: centered
    // horizontally on the crop and with its bottom at y.
    final fullLeft = x - destWidth / 2;
    final fullTop = y - destHeight;
    final drawLeft = fullLeft + (source.left - fullSource.left) * scale;
    final drawTop = fullTop + (source.top - fullSource.top) * scale;
    final drawWidth = source.width * scale;
    final drawHeight = source.height * scale;
    canvas.save();
    if (facing < 0) {
      canvas.translate(x, y);
      canvas.scale(-1, 1);
      canvas.translate(-x, -y);
    }
    final paint = ui.Paint()..color = ui.Color.fromRGBO(255, 255, 255, opacity);
    canvas.drawImageRect(
      image,
      source,
      ui.Rect.fromLTWH(drawLeft, drawTop, drawWidth, drawHeight),
      paint,
    );
    canvas.restore();
  }

  /// Base sheet key (e.g. URSA_QUAD_CORE) -> the selected skin's sheet key.
  Map<String, String> _skinSheetMap(String skinId) {
    final skin = skins.where((item) => item['id'] == skinId).firstOrNull;
    final sheets = skin?['sheets'];
    if (sheets is! Map) return const <String, String>{};
    return sheets.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  void startArea(int index, String skinId) {
    if (areas.isEmpty) return;
    final targetArea = index.clamp(0, areas.length - 1);
    if (targetArea > _highestUnlockedArea) {
      _toast('Selesaikan area ${_highestUnlockedArea + 1} dulu.');
      _emitUi();
      return;
    }
    if (!purchasedSkins.contains(skinId)) {
      _toast('Skin ini perlu dibeli dengan koin terlebih dahulu.');
      _emitUi();
      return;
    }
    final wasMenuOpen = menuOpen;
    areaIndex = targetArea;
    selectedSkin = skinId;
    menuOpen = false;
    ending = false;
    started = true;
    _restartAreaPending = false;
    transitionTimer = 0;
    if (wasMenuOpen) audio.playSfx('menu_confirm');
    _saveProgress();
    unawaited(_beginArea());
    _emitUi();
  }

  Future<void> _beginArea() async {
    loading = true;
    _clearInput();
    _emitUi();
    final selectedArea = areas[areaIndex];
    final skinSheets = _skinSheetMap(selectedSkin);
    // Only wait for what the first frame of the area draws; each sheet is a
    // large image, so decoding all of them up front made the start slow.
    final keys = <String>{
      skinSheets['URSA_QUAD_CORE'] ?? 'URSA_QUAD_CORE',
      skinSheets['URSA_BIPED_CORE'] ?? 'URSA_BIPED_CORE',
      'UI_ICONS',
      selectedArea['bg'].toString(),
      selectedArea['tile'].toString(),
      selectedArea['enemySheet'].toString(),
      for (final item in _maps(selectedArea['objects']))
        _text(item['atlas'], 'WORLD_PROPS'),
      for (final item in _maps(selectedArea['pickups']))
        _text(item['atlas'], 'FOOD_ATLAS'),
    };
    // Action sheets are only needed once the bear does a skill.
    final deferred = <String>[
      for (final entry in skinSheets.entries)
        if (!keys.contains(entry.value)) entry.value,
    ];
    try {
      await _loadKeys(keys);
    } catch (error, stackTrace) {
      debugPrint('URSA asset load failed: $error\n$stackTrace');
      loading = false;
      menuOpen = true;
      _toast('Sebagian aset gagal dibuka. Coba pilih area lagi.', 5);
      _emitUi();
      return;
    }
    _openAreaState(areaIndex);
    _applySession();
    loading = false;
    unawaited(
      _loadKeys(deferred).catchError(
        (Object error) => debugPrint('URSA deferred load failed: $error'),
      ),
    );
    message = '${areaIndex + 1}. $areaName · ${_text(level['lesson'], '')}';
    messageTimer = 3;
    _emitUi();
  }

  void _openAreaState(int index) {
    areaIndex = index;
    level = areas[index];
    platforms = _maps(level['platforms']);
    objects = _maps(level['objects']).map((item) {
      item['opened'] = false;
      item['activated'] = false;
      return item;
    }).toList();
    pickups = _maps(level['pickups']).map((item) {
      item['collected'] = false;
      return item;
    }).toList();
    enemies = _maps(level['enemies']).asMap().entries.map((entry) {
      final enemy = entry.value;
      enemy['originX'] = _number(enemy['x']);
      enemy['phase'] = entry.key * 1.7;
      enemy['direction'] = entry.key.isOdd ? -1 : 1;
      enemy['stunned'] = 0.0;
      enemy['alert'] = 0.0;
      return enemy;
    }).toList();
    _effects.clear();
    time = 0;
    cameraX = 0;
    cameraY = _worldHeight - _viewHeight;
    shake = 0;
    completed = false;
    ending = false;
    mode = 'quad';
    grounded = true;
    moving = false;
    health = 3;
    playerX = 120;
    playerY = _number(platforms.firstOrNull?['y'], 570);
    velocityX = 0;
    velocityY = 0;
    facing = 1;
    invulnerable = 0;
    cold = _bool(level['cold']) ? math.min(100, 52 + fat * 0.45) : 100;
    heat = _bool(level['heat']) ? 20 : 0;
    noise = 0;
    buffTimer = 0;
    instinctTimer = 0;
    tractionTimer = 0;
    areaTimer = _number(level['timer']);
    if (_respawnAtCheckpoint && _savedCheckpoints.containsKey(areaIndex)) {
      _checkpointX = _savedCheckpoints[areaIndex]![0];
      _checkpointY = _savedCheckpoints[areaIndex]![1];
      playerX = _checkpointX;
      playerY = _checkpointY;
    } else {
      _checkpointX = 120;
      _checkpointY = playerY;
      _savedCheckpoints.remove(areaIndex);
    }
    _safeX = playerX;
    _safeY = playerY;
    _sessionTimer = 0;
    _respawnAtCheckpoint = false;
    _actionAnimation = null;
    _wasInWindZone = false;
    _clearInput();
    _syncAudioState();
  }

  // Out of lives: reset the area in place. Its assets are already loaded, so
  // skip the loading screen startArea would show.
  void _restartCurrentArea() {
    _openAreaState(areaIndex);
    _saveProgress();
    _emitUi();
  }

  void openMenu() {
    if (!started || ending) return;
    _saveSession();
    menuOpen = true;
    _clearInput();
    audio.playSfx('menu_open');
    _syncAudioState();
    _emitUi();
  }

  void closeMenu() {
    menuOpen = false;
    _clearInput();
    _syncAudioState();
    _emitUi();
  }

  void restartJourney() {
    totalFood = 0;
    fat = 20;
    ending = false;
    menuOpen = false;
    startArea(0, selectedSkin);
  }

  bool purchaseSkin(String skinId) {
    final skin = skins.where((item) => item['id'] == skinId).firstOrNull;
    if (skin == null) return false;
    if (purchasedSkins.contains(skinId)) {
      selectedSkin = skinId;
      _saveProgress();
      _emitUi();
      return true;
    }

    final price = _number(skin['price']).round();
    if (price <= 0 || totalFood < price) {
      _toast('Koin belum cukup. Kumpulkan makanan di area.');
      _emitUi();
      return false;
    }

    totalFood -= price;
    purchasedSkins.add(skinId);
    selectedSkin = skinId;
    _saveProgress();
    _toast('${_text(skin['name'], 'Skin')} berhasil dibeli!');
    _emitUi();
    return true;
  }

  void setControl(String name, bool active) {
    if (active) {
      if (_held.add(name)) _pressed.add(name);
    } else {
      _held.remove(name);
    }
  }

  void handleKey(LogicalKeyboardKey key, bool down) {
    final name = switch (key) {
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.keyA => 'left',
      LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.keyD => 'right',
      LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.keyS => 'down',
      LogicalKeyboardKey.space ||
      LogicalKeyboardKey.arrowUp ||
      LogicalKeyboardKey.keyW => 'jump',
      LogicalKeyboardKey.shiftLeft || LogicalKeyboardKey.shiftRight => 'shift',
      LogicalKeyboardKey.keyE || LogicalKeyboardKey.keyJ => 'action',
      _ => null,
    };
    if (name != null) setControl(name, down);
  }

  void _clearInput() {
    _held.clear();
    _pressed.clear();
  }

  bool _consume(String name) => _pressed.remove(name);

  @override
  void update(double dt) {
    super.update(dt);
    if (frameViewer) {
      _viewerTime += dt;
      return;
    }
    final delta = dt.clamp(0.0, 0.033);
    _uiNotifyTimer += dt;
    if (_uiNotifyTimer >= 0.12) {
      _uiNotifyTimer = 0;
      _emitUi();
    }
    if (messageTimer > 0) {
      messageTimer = math.max(0, messageTimer - delta);
      if (messageTimer == 0) message = null;
    }
    if (loading || menuOpen || !started || ending || level.isEmpty) return;

    if (transitionTimer > 0) {
      transitionTimer = math.max(0, transitionTimer - delta);
      if (transitionTimer == 0) {
        if (_restartAreaPending) {
          _restartAreaPending = false;
          _restartCurrentArea();
        } else if (areaIndex < areas.length - 1) {
          startArea(areaIndex + 1, selectedSkin);
        } else {
          years += 1;
          ending = true;
          completed = true;
          _beginAction('URSA_YEAR2_INSTINCT', 'star_sleep', 1);
          _syncAudioState();
          _saveProgress();
          _emitUi();
        }
      }
      return;
    }

    if (completed) return;
    _updateWorld(delta);
  }

  void _updateWorld(double dt) {
    time += dt;
    shake = math.max(0, shake - dt);
    invulnerable = math.max(0, invulnerable - dt);
    buffTimer = math.max(0, buffTimer - dt);
    instinctTimer = math.max(
      0,
      instinctTimer - dt * (_bool(level['moon']) ? 0.55 : 1),
    );
    tractionTimer = math.max(0, tractionTimer - dt);
    if (areaTimer > 0) areaTimer = math.max(0, areaTimer - dt);
    if (_actionAnimation != null) {
      _actionAge += dt;
      if (_actionAge >= _actionDuration) _actionAnimation = null;
    }

    if (_consume('shift')) {
      mode = mode == 'biped' ? 'quad' : 'biped';
      _beginAction(
        'URSA_SPECIAL',
        'stance_shift',
        0.34,
        reverse: mode == 'biped',
      );
      audio.playSfx('shift');
      _addEffect(playerX, playerY, color: const ui.Color(0xff8dd7bd));
    }
    if (_consume('action')) _handleAction();

    final axis =
        (_held.contains('right') ? 1 : 0) - (_held.contains('left') ? 1 : 0);
    if (axis != 0) facing = axis.toDouble();
    var speed = mode == 'biped' ? _bipedSpeed : _quadSpeed;
    if (_inZone('honey', playerX) && mode == 'quad') speed *= 0.42;
    if (_inZone('ice', playerX)) speed *= mode == 'quad' ? 1.2 : 0.72;
    if (_inZone('ash', playerX)) speed *= mode == 'quad' ? 1.12 : 0.82;
    final targetVx = axis * speed;
    velocityX += (targetVx - velocityX) * math.min(1, dt * (grounded ? 11 : 5));
    if (axis == 0 && grounded) {
      final braking = _inZone('ice', playerX) && tractionTimer <= 0 ? 0.8 : 9.0;
      velocityX *= math.max(0, 1 - dt * braking);
    }
    moving = velocityX.abs() > 38;
    if (moving && grounded) _runCycle += velocityX.abs() * dt;
    if (grounded && invulnerable <= 0) {
      _safeX = playerX;
      _safeY = playerY;
    }
    _sessionTimer += dt;
    if (_sessionTimer >= 2) {
      _sessionTimer = 0;
      _saveSession();
    }
    if (_inZone('wind', playerX)) {
      velocityX -= (mode == 'biped' ? 145 : 48) * dt;
    }
    if (_inZone('current', playerX)) {
      velocityX -= (mode == 'biped' ? 125 : 28) * dt;
    }

    if (_consume('jump') && grounded && _actionAnimation == null) {
      final boost = buffTimer > 0 ? 1.23 : 1.0;
      velocityY = -(mode == 'quad' ? 590 : 650) * boost;
      grounded = false;
      audio.playSfx('jump');
    }

    final previousX = playerX;
    final previousY = playerY;
    final wasGrounded = grounded;
    velocityY += _gravity * dt;
    playerX += velocityX * dt;
    playerY += velocityY * dt;
    playerX = playerX.clamp(40, _number(level['width'], 6260) - 30);
    _resolveGateCollisions(previousX);

    grounded = false;
    if (velocityY >= 0) {
      final playerWidth = mode == 'biped' ? 54.0 : 96.0;
      for (final ground in platforms) {
        final groundX = _number(ground['x']);
        final groundY = _number(ground['y']);
        final groundWidth = _number(ground['w']);
        final overlapsX =
            playerX + playerWidth / 2 > groundX &&
            playerX - playerWidth / 2 < groundX + groundWidth;
        if (overlapsX && previousY <= groundY + 2 && playerY >= groundY) {
          playerY = groundY;
          velocityY = 0;
          grounded = true;
          break;
        }
      }
    }
    if (!wasGrounded && grounded) {
      shake = math.max(shake, mode == 'biped' ? 0.16 : 0.08);
      _addEffect(playerX, playerY, color: const ui.Color(0xffd5c398));
      audio.playSfx('land');
    }
    if (playerY > 760) {
      _damage('Salah pijak—kembali ke jejak cakar.');
      if (completed) return;
    }

    _updateSurvival(dt);
    if (completed) return;
    _updateEnemies(dt);
    if (completed) return;
    _updateCollectibles();
    _updateCheckpoints();
    _updateHazards(dt);
    if (completed) return;
    final inWind = _inZone('wind', playerX);
    if (inWind && !_wasInWindZone) audio.playSfx('wind_gust');
    _wasInWindZone = inWind;
    _updateAmbient();
    for (final effect in _effects) {
      effect['age'] = _number(effect['age']) + dt;
    }
    _effects.removeWhere(
      (effect) => _number(effect['age']) >= _number(effect['duration'], 0.5),
    );

    if (completed) return;
    if (areaIndex == 7 && areaTimer == 0 && totalFood > 0) {
      _toast('Malam tiba—segera menuju ujung ladang.');
    }
    if (playerX >= _number(level['width'], 6260) - 110) {
      completed = true;
      transitionTimer = 1.05;
      audio.playSfx('win');
      if (areaIndex < areas.length - 1) {
        _highestUnlockedArea = math.max(_highestUnlockedArea, areaIndex + 1);
        _saveProgress();
        _toast(
          'Bab ${areaIndex + 1} selesai · ${_text(areas[areaIndex + 1]['season'], '')}',
          1.8,
        );
      }
    }
  }

  void _updateSurvival(double dt) {
    if (_bool(level['cold'])) {
      final inWind = _inZone('wind', playerX);
      cold += (mode == 'biped' ? 4.5 : -5.8) * dt;
      if (inWind) cold -= (mode == 'biped' ? 1.2 : 3.4) * dt;
      if (_inZone('warm', playerX)) cold += 16 * dt;
      cold = cold.clamp(0, 100);
      if (cold <= 0) {
        _damage('Terlalu dingin. Berdiri untuk menghangatkan tubuh.');
        cold = 42;
      }
    }
    if (_bool(level['heat'])) {
      final hotZone = _inZone('steam', playerX) || _inZone('ash', playerX);
      heat += (hotZone ? (mode == 'quad' ? 8.5 : 4.2) : -5) * dt;
      if (_actionAnimation == 'ash_shield' ||
          _actionAnimation == 'steam_brace') {
        heat -= 9 * dt;
      }
      heat = heat.clamp(0, 100);
      if (heat >= 100) {
        if (_damage(
          'Terlalu panas—gunakan lindungan atau berdiri menahan udara.',
        )) {
          audio.playSfx('steam');
        }
        heat = 45;
      }
    }
    if (_bool(level['noise'])) {
      noise += (velocityX.abs() > 280 ? 7 : -13) * dt;
      noise = noise.clamp(0, 100);
      if (noise >= 100) {
        _addEffect(playerX + 120, playerY, color: const ui.Color(0xfff2ecdb));
        if (_damage(
          'Salju mendengar langkahmu—bergerak pelan atau picu jalur aman.',
        )) {
          audio.playSfx('avalanche');
        }
        noise = 28;
      }
    }
  }

  void _resolveGateCollisions(double previousX) {
    final size = _playerSize;
    final playerRect = ui.Rect.fromLTWH(
      playerX - size.$1 / 2,
      playerY - size.$2,
      size.$1,
      size.$2,
    );
    for (final object in objects) {
      final type = _text(object['type']);
      if (_bool(object['opened']) ||
          type == 'checkpoint_tree' ||
          type == 'winter_cave' ||
          _bool(object['trap'])) {
        continue;
      }
      final required = object['requires']?.toString();
      final blocksByMode = required != null && required != mode;
      final blocksUntilOpened = _bool(object['breakable']);
      if (!blocksByMode && !blocksUntilOpened) continue;
      final rect = ui.Rect.fromLTWH(
        _number(object['x']) - _number(object['w']) / 2,
        _number(object['y']) - _number(object['h']),
        _number(object['w']),
        _number(object['h']),
      );
      if (!playerRect.overlaps(rect)) continue;
      final half = size.$1 / 2;
      playerX = previousX <= _number(object['x'])
          ? rect.left - half - 1
          : rect.right + half + 1;
      velocityX = 0;
    }
  }

  void _handleAction() {
    if (_actionAnimation != null) return;
    if (mode == 'quad' && areaIndex >= 8) {
      instinctTimer = 3.8;
      audio.playSfx('sniff');
      if (_inZone('ice', playerX)) {
        tractionTimer = 3.8;
        _beginAction('URSA_YEAR2_SKILLS', 'ice_balance', 0.5);
      } else if (_bool(level['echo'])) {
        _beginAction('URSA_YEAR2_INSTINCT', 'echo_sniff', 0.5);
      } else if (_bool(level['moon']) || _bool(level['starfall'])) {
        _beginAction('URSA_YEAR2_INSTINCT', 'moon_track', 0.5);
      } else {
        _beginAction('URSA_REACTIONS', 'instinct', 0.5);
      }
      _addEffect(playerX, playerY - 35, color: const ui.Color(0xff8de3e2));
      return;
    }
    if (mode == 'biped' && !grounded) {
      velocityY = 1050;
      if (_bool(level['noise'])) {
        noise = math.min(100, noise + 34);
        _beginAction('URSA_YEAR2_INSTINCT', 'avalanche_pound', 0.46);
        audio.playSfx('avalanche');
      } else {
        _beginAction('URSA_SKILLS', 'ground_pound', 0.46);
        audio.playSfx('pound');
      }
      return;
    }

    final special = _nearestSpecial();
    if (special != null && mode == 'biped') {
      if (_bool(special['steam']) || _bool(special['warm'])) {
        special['suppressed'] = 2.5;
        heat = math.max(0, heat - 28);
        cold = math.min(100, cold + 26);
        _beginAction('URSA_YEAR2_SKILLS', 'steam_brace', 0.56);
        audio.playSfx('steam');
        _addEffect(
          _number(special['x']),
          _number(special['y']) - 55,
          color: const ui.Color(0xffffd097),
        );
        return;
      }
      if (_bool(special['echo'])) {
        instinctTimer = 5;
        _beginAction('URSA_YEAR2_INSTINCT', 'echo_sniff', 0.52);
        audio.playSfx('sniff');
        _addEffect(
          _number(special['x']),
          _number(special['y']) - 55,
          color: const ui.Color(0xff8de3e2),
        );
        return;
      }
      special['opened'] = true;
      if (_bool(special['avalanche'])) {
        noise = 0;
        _beginAction('URSA_YEAR2_INSTINCT', 'avalanche_pound', 0.58);
        audio.playSfx('avalanche');
      } else {
        _beginAction('URSA_YEAR2_SKILLS', 'log_push', 0.58);
        audio.playSfx('break');
      }
      _addEffect(
        _number(special['x']),
        _number(special['y']),
        color: const ui.Color(0xffdfbb7a),
      );
      shake = 0.22;
      return;
    }
    if (mode == 'biped' && _inZone('ash', playerX)) {
      _beginAction('URSA_YEAR2_SKILLS', 'ash_shield', 0.5);
      audio.playSfx('steam');
      heat = math.max(0, heat - 18);
      return;
    }

    final object = _nearestInteractive();
    if (object != null && mode == 'biped') {
      object['opened'] = true;
      final type = _text(object['type']);
      final isRock = type == 'fragile_rock';
      _beginAction('URSA_SKILLS', isRock ? 'ground_pound' : 'carve', 0.5);
      audio.playSfx('break');
      _addEffect(
        _number(object['x']),
        _number(object['y']) - 45,
        color: isRock ? const ui.Color(0xffe0c27c) : const ui.Color(0xffb6d985),
      );
      shake = 0.22;
      return;
    }
    if (mode == 'biped') {
      _beginAction('URSA_BIPED_CORE', 'biped_claw', 0.38);
      audio.playSfx('claw');
    } else {
      _beginAction('URSA_QUAD_CORE', 'quad_tackle', 0.34);
      velocityX += facing * 170;
      audio.playSfx('tackle');
    }
  }

  Map<String, dynamic>? _nearestInteractive() {
    for (final object in objects) {
      if (_bool(object['opened'])) continue;
      if (!_bool(object['breakable']) && object['type'] != 'honey_wall') {
        continue;
      }
      if ((_number(object['x']) - playerX).abs() < 145 &&
          (_number(object['y']) - playerY).abs() < 180) {
        return object;
      }
    }
    return null;
  }

  Map<String, dynamic>? _nearestSpecial() {
    for (final object in objects) {
      final special =
          _bool(object['steam']) ||
          _bool(object['warm']) ||
          _bool(object['echo']) ||
          _bool(object['avalanche']) ||
          const <String>{
            'rolling_log',
            'beaver_dam',
            'redwood_gate',
          }.contains(object['type']);
      if (special &&
          !_bool(object['opened']) &&
          (_number(object['x']) - playerX).abs() < 150 &&
          (_number(object['y']) - playerY).abs() < 190) {
        return object;
      }
    }
    return null;
  }

  void _updateEnemies(double dt) {
    final size = _playerSize;
    final playerRect = ui.Rect.fromLTWH(
      playerX - size.$1 / 2,
      playerY - size.$2,
      size.$1,
      size.$2,
    );
    final hiddenInGrass = mode == 'quad' && _inZone('grass', playerX);
    for (final enemy in enemies) {
      enemy['stunned'] = math.max(0, _number(enemy['stunned']) - dt);
      enemy['alert'] = math.max(0, _number(enemy['alert']) - dt);
      final distance = (playerX - _number(enemy['x'])).abs();
      final noisy =
          _bool(enemy['noiseSensitive']) &&
          mode == 'quad' &&
          velocityX.abs() > 250;
      final spotted =
          _bool(enemy['human']) &&
          !hiddenInGrass &&
          distance < _number(enemy['range']) &&
          mode == 'biped';
      if (noisy ||
          spotted ||
          (distance < _number(enemy['range']) * 0.55 &&
              !_bool(enemy['harmless']))) {
        enemy['alert'] = 0.75;
      }
      final alert = _number(enemy['alert']);
      final pace = alert > 0 ? 85 : 28;
      final phase = time * (alert > 0 ? 2.2 : 0.8) + _number(enemy['phase']);
      final range = math.min(_number(enemy['range']) * 0.45, 120);
      enemy['x'] = _number(enemy['originX']) + math.sin(phase) * range;
      enemy['direction'] = math.cos(phase) >= 0 ? 1 : -1;
      if (alert > 0 && !_bool(enemy['human'])) {
        final sign = (playerX - _number(enemy['x'])).sign;
        enemy['x'] = _number(enemy['x']) + sign * pace * dt;
      }
      final enemyRect = ui.Rect.fromLTWH(
        _number(enemy['x']) - 36,
        _number(enemy['y']) - (_bool(enemy['air']) ? 42 : 58),
        72,
        _bool(enemy['air']) ? 70 : 58,
      );
      final attack =
          _actionAnimation == 'biped_claw' ||
          _actionAnimation == 'quad_tackle' ||
          _actionAnimation == 'ground_pound';
      if (attack &&
          distance < 115 &&
          (playerY - _number(enemy['y'])).abs() < 130 &&
          !_bool(enemy['harmless']) &&
          !_bool(enemy['human'])) {
        if (_number(enemy['stunned']) <= 0) {
          enemy['stunned'] = 1.7;
          enemy['alert'] = 0;
          audio.playSfx('enemy_hit');
          _addEffect(
            _number(enemy['x']),
            _number(enemy['y']) - 20,
            color: const ui.Color(0xffd5c398),
          );
        }
      } else if (_number(enemy['stunned']) <= 0 &&
          playerRect.overlaps(enemyRect)) {
        if (invulnerable <= 0) {
          health -= 1;
          invulnerable = 1.2;
          final dir =
              (playerX - _number(enemy['x'])).sign == 0 ? 1 : (playerX - _number(enemy['x'])).sign;
          velocityX = dir * 320;
          grounded = true;
          shake = 0.3;
          _toast(
            _bool(enemy['human'])
                ? 'Terdeteksi! Hindari tatapan mereka.'
                : 'Baca gerakannya sebelum mendekat.',
          );
          audio.playSfx('hurt');
          if (health <= 0) {
            health = 3;
            buffTimer = 0;
            _respawnAtCheckpoint = true;
            _toast('Tiga kesempatan habis—area dimulai ulang.');
            audio.playSfx('restart');
            _restartAreaPending = true;
            transitionTimer = 0.28;
            completed = true;
          }
        }
      }
    }
  }

  void _updateCollectibles() {
    for (final pickup in pickups) {
      if (_bool(pickup['hidden']) && instinctTimer <= 0) continue;
      if (_bool(pickup['collected'])) continue;
      final dx = playerX - _number(pickup['x']);
      final dy = playerY - _number(pickup['y']);
      if (math.sqrt(dx * dx + dy * dy) > 78) continue;
      pickup['collected'] = true;
      totalFood += 1;
      audio.playSfx('pickup');
      if (_bool(pickup['buff'])) buffTimer = math.max(buffTimer, 8);
      audio.playSfx(_bool(pickup['buff']) ? 'power_up' : 'eat');
      if (pickup['fat'] is num) {
        fat = math.min(100, fat + _number(pickup['fat']));
      }
      if (pickup['type'] == 'healing_herbs') health = math.min(3, health + 1);
      _beginAction('URSA_SKILLS', 'eat', 0.38);
      _addEffect(
        _number(pickup['x']),
        _number(pickup['y']),
        color: const ui.Color(0xffffd978),
      );
      _saveProgress();
    }
    if (!collectedClaws.contains(areaIndex) && level['claw'] is Map) {
      final claw = _asMap(level['claw']);
      final dx = playerX - _number(claw['x']);
      final dy = playerY - _number(claw['y']);
      if (math.sqrt(dx * dx + dy * dy) < 74) {
        collectedClaws.add(areaIndex);
        audio.playSfx('collect');
        _toast('Cap cakar $clawCount/${areas.length} ditemukan');
        _addEffect(
          _number(claw['x']),
          _number(claw['y']),
          color: const ui.Color(0xffa4ebed),
        );
        _saveProgress();
      }
    }
  }

  void _updateCheckpoints() {
    for (final object in objects) {
      if (object['type'] != 'checkpoint_tree' || _bool(object['activated'])) {
        continue;
      }
      if ((playerX - _number(object['x'])).abs() < 70) {
        object['activated'] = true;
        audio.playSfx('check_point');
        _checkpointX = _number(object['x']) + 70;
        _checkpointY = _number(object['y']);
        _savedCheckpoints[areaIndex] = <double>[_checkpointX, _checkpointY];
        _toast('Jejak cakar tersimpan');
        _saveProgress();
      }
    }
  }

  void _updateHazards(double dt) {
    final size = _playerSize;
    final playerRect = ui.Rect.fromLTWH(
      playerX - size.$1 / 2,
      playerY - size.$2,
      size.$1,
      size.$2,
    );
    for (final object in objects) {
      if (!_bool(object['trap'])) continue;
      final trap = ui.Rect.fromLTWH(
        _number(object['x']) - _number(object['w']) / 2,
        _number(object['y']) - _number(object['h']),
        _number(object['w']),
        _number(object['h']),
      );
      if (playerRect.overlaps(trap)) {
        _damage(
          instinctTimer > 0
              ? 'Jejak jebakan terlihat—lompat lebih awal.'
              : 'Endus rumput untuk menemukan jebakan.',
        );
      }
    }
    for (final object in objects) {
      object['suppressed'] = math.max(0, _number(object['suppressed']) - dt);
      final near =
          (playerX - _number(object['x'])).abs() <
          math.max(70, _number(object['w']) * 0.6);
      if (_bool(object['pressure']) && near && mode == 'biped' && grounded) {
        if (_damage('Es membaca beratmu—sebarkan tubuh dengan empat kaki.')) {
          audio.playSfx('ice_crack');
        }
      }
      if (_bool(object['steam']) &&
          _number(object['suppressed']) <= 0 &&
          near &&
          math.sin(time * 3.2 + _number(object['x'])) > 0.72 &&
          mode == 'quad') {
        if (_damage('Uap meletup—berdiri dan tahan semburannya.')) {
          audio.playSfx('steam');
        }
      }
      if (_bool(object['warm']) && near) cold = math.min(100, cold + 18 * dt);
    }
  }

  bool _damage(String reason) {
    if (invulnerable > 0) return false;
    health -= 1;
    invulnerable = 1.2;
    playerX = _checkpointX;
    playerY = _checkpointY;
    velocityX = 0;
    velocityY = 0;
    grounded = true;
    shake = 0.3;
    _toast(reason);
    audio.playSfx('hurt');
    if (health <= 0) {
      health = 3;
      buffTimer = 0;
      _respawnAtCheckpoint = true;
      _toast('Tiga kesempatan habis—area dimulai ulang.');
      audio.playSfx('restart');
      _restartAreaPending = true;
      transitionTimer = 0.28;
      completed = true;
    }
    return true;
  }

  void _beginAction(
    String sheet,
    String animation,
    double duration, {
    bool reverse = false,
  }) {
    _actionSheet = sheet;
    _actionAnimation = animation;
    _actionDuration = duration;
    _actionAge = 0;
    _actionReverse = reverse;
  }

  void _addEffect(
    double x,
    double y, {
    ui.Color color = const ui.Color(0xffe6c780),
  }) {
    _effects.add(<String, dynamic>{
      'x': x,
      'y': y,
      'age': 0.0,
      'duration': 0.5,
      'color': color,
    });
  }

  void _toast(String text, [double duration = 2.4]) {
    message = text;
    messageTimer = duration;
  }

  void _syncAudioState() {
    audio.playMusic(_musicForCurrentState());
    _updateAmbient();
  }

  String _musicForCurrentState() {
    if (ending) return 'bgm_ending';
    if (menuOpen || !started) return 'bgm_menu';
    if (areaIndex >= 10) return 'bgm_year2';
    if (areaIndex <= 1) return 'bgm';
    if (areaIndex <= 5) return 'bgm_summer';
    if (areaIndex <= 7) return 'bgm_autumn';
    return 'bgm_winter';
  }

  void _updateAmbient() {
    if (menuOpen || !started || ending) {
      audio.playAmbient(null);
      return;
    }
    final String? ambient;
    if (_inZone('steam', playerX) || _inZone('ash', playerX)) {
      ambient = 'steam_ambience';
    } else if (_inZone('wind', playerX)) {
      ambient = 'wind_ambience';
    } else if (_inZone('current', playerX)) {
      ambient = 'water_ambience';
    } else if (_bool(level['cold']) || areaIndex >= 8) {
      ambient = 'winter_ambience';
    } else {
      ambient = null; // No forest ambience file is bundled.
    }
    audio.playAmbient(ambient);
  }

  void _saveProgress() {
    final preferences = _preferences;
    if (preferences == null || areas.isEmpty) return;
    final progress = <String, Object>{
      'version': 2,
      'currentArea': areaIndex,
      'highestArea': _highestUnlockedArea,
      'collectedClaws': collectedClaws.toList()..sort(),
      'purchasedSkins': purchasedSkins.toList()..sort(),
      'totalFood': totalFood,
      'fat': fat,
      'years': years,
      'selectedSkin': selectedSkin,
      'checkpoints': _savedCheckpoints.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    };
    unawaited(preferences.setString('ursa.progress', jsonEncode(progress)));
  }

  static const String _sessionKey = 'ursa.session';
  static const String _volumeKey = 'ursa.volume';
  Map<String, dynamic>? _pendingSession;
  double _sessionTimer = 0;
  // Last position where the bear stood safely on the ground; saved instead of
  // the live position so a resume never starts mid-air over a pit.
  double _safeX = 120;
  double _safeY = 570;

  /// Whether a mid-area save exists for [area] (offered as "continue").
  bool hasSessionFor(int area) => _pendingSession?['area'] == area;

  // Snapshot of the area in progress, so a force-closed game resumes here.
  void _saveSession() {
    final preferences = _preferences;
    if (preferences == null ||
        !started ||
        loading ||
        ending ||
        completed ||
        level.isEmpty) {
      return;
    }
    final session = <String, Object>{
      'area': areaIndex,
      'x': _safeX,
      'y': _safeY,
      'mode': mode,
      'health': health,
      'checkpoint': <double>[_checkpointX, _checkpointY],
      'cold': cold,
      'heat': heat,
      'noise': noise,
      'pickups': <int>[
        for (var i = 0; i < pickups.length; i++)
          if (_bool(pickups[i]['collected'])) i,
      ],
      'opened': <int>[
        for (var i = 0; i < objects.length; i++)
          if (_bool(objects[i]['opened'])) i,
      ],
      'activated': <int>[
        for (var i = 0; i < objects.length; i++)
          if (_bool(objects[i]['activated'])) i,
      ],
    };
    unawaited(preferences.setString(_sessionKey, jsonEncode(session)));
    _saveProgress();
  }

  void _applySession() {
    final session = _pendingSession;
    _pendingSession = null;
    if (session == null || session['area'] != areaIndex) return;
    playerX = _number(session['x'], playerX);
    playerY = _number(session['y'], playerY);
    mode = session['mode'] == 'biped' ? 'biped' : 'quad';
    health = _number(session['health'], 3).round().clamp(1, 3);
    final checkpoint = session['checkpoint'];
    if (checkpoint is List && checkpoint.length == 2) {
      _checkpointX = _number(checkpoint[0], _checkpointX);
      _checkpointY = _number(checkpoint[1], _checkpointY);
      _savedCheckpoints[areaIndex] = <double>[_checkpointX, _checkpointY];
    }
    cold = _number(session['cold'], cold);
    heat = _number(session['heat'], heat);
    noise = _number(session['noise'], noise);
    void mark(String key, List<Map<String, dynamic>> items, String flag) {
      final indices = session[key];
      if (indices is! List) return;
      for (final index in indices.whereType<num>()) {
        if (index >= 0 && index < items.length) items[index.toInt()][flag] = true;
      }
    }

    mark('pickups', pickups, 'collected');
    mark('opened', objects, 'opened');
    mark('activated', objects, 'activated');
    _safeX = playerX;
    _safeY = playerY;
    cameraX = playerX - 300;
  }

  @override
  void lifecycleStateChange(ui.AppLifecycleState state) {
    super.lifecycleStateChange(state);
    // Save before the OS can kill a backgrounded app.
    if (state != ui.AppLifecycleState.resumed) _saveSession();
  }

  int get volumePercent => (audio.masterVolume * 100).round();

  void changeVolume(int steps) {
    final level = ((audio.masterVolume * 10).round() + steps).clamp(0, 10) / 10;
    unawaited(audio.setMasterVolume(level));
    unawaited(_preferences?.setDouble(_volumeKey, level));
    _emitUi();
  }

  /// Wipes every saved progress (areas, coins, skins, claws, checkpoints and
  /// the in-area save) and returns to a fresh start menu.
  Future<void> resetAllProgress() async {
    await _preferences?.remove('ursa.progress');
    await _preferences?.remove(_sessionKey);
    _pendingSession = null;
    areaIndex = 0;
    _highestUnlockedArea = 0;
    collectedClaws.clear();
    purchasedSkins
      ..clear()
      ..add('brown');
    selectedSkin = 'brown';
    totalFood = 0;
    fat = 20;
    years = 0;
    _savedCheckpoints.clear();
    _respawnAtCheckpoint = false;
    _restartAreaPending = false;
    transitionTimer = 0;
    started = false;
    ending = false;
    menuOpen = true;
    _openAreaState(0);
    _toast('Semua progres direset.');
    _emitUi();
  }

  (double, double) get _playerSize => mode == 'biped' ? (54, 112) : (96, 58);

  bool _inZone(String type, double x) {
    for (final zone in _maps(level['zones'])) {
      if (zone['type'] == type &&
          x >= _number(zone['x']) &&
          x <= _number(zone['x']) + _number(zone['w'])) {
        return true;
      }
    }
    return false;
  }

  void _emitUi() => revision.value++;

  Map<String, dynamic> _layoutFor(String key) {
    final groups = _spriteLayouts['groups'];
    if (groups is Map && groups[key] is Map) {
      return groups[key] as Map<String, dynamic>;
    }
    final def = _spriteLayouts['default'];
    return def is Map ? def as Map<String, dynamic> : <String, dynamic>{};
  }

  int _columns(String key) => _number(_layoutFor(key)['columns'], 5).round();

  int spriteColumns(String key) => _columns(key);
  int spriteRows(String key) => _rows(key);

  int _rows(String key) => _number(_layoutFor(key)['rows'], 4).round();

  ui.Image? _image(String key) {
    final path = _assetPaths[key];
    if (path == null) return null;
    final filename = path.split('/').last;
    if (!_loadedImages.contains(filename)) return null;
    return images.fromCache(filename);
  }

  ui.Rect _cellRect(String key, ui.Image image, int column, int row) {
    final layout = _layoutFor(key);
    final columns = _number(layout['columns'], 5).round();
    final rows = _number(layout['rows'], 4).round();
    final offsetX = _number(layout['offsetX'], 0).round();
    final offsetY = _number(layout['offsetY'], 0).round();
    final frameWidth = _number(layout['frameWidth'], image.width / columns).round();
    final frameHeight =
        _number(layout['frameHeight'], image.height / rows).round();
    final gapX = _number(layout['gapX'], 0).round();
    final gapY = _number(layout['gapY'], 0).round();
    final pitchX = frameWidth + gapX;
    final pitchY = frameHeight + gapY;
    return ui.Rect.fromLTWH(
      (offsetX + (column % columns) * pitchX).toDouble(),
      (offsetY + (row % rows) * pitchY).toDouble(),
      frameWidth.toDouble(),
      frameHeight.toDouble(),
    );
  }

  void _drawCell(
    ui.Canvas canvas,
    String key,
    int column,
    int row,
    ui.Rect destination, {
    double opacity = 1,
    bool contain = true,
    double bleedLeft = 0,
    double bleedRight = 0,
    double bleedTop = 0,
    double bleedBottom = 0,
    ui.Offset shift = ui.Offset.zero,
  }) {
    final image = _image(key);
    if (image == null) return;
    var source = _cellRect(key, image, column, row);
    var target = destination;
    if (contain) {
      final scale = math.min(
        destination.width / source.width,
        destination.height / source.height,
      );
      final width = source.width * scale;
      final height = source.height * scale;
      target = ui.Rect.fromLTWH(
        destination.center.dx - width / 2,
        destination.center.dy - height / 2,
        width,
        height,
      );
    }
    // Negative values crop inside the cell instead.
    if (bleedLeft != 0 || bleedRight != 0 || bleedTop != 0 || bleedBottom != 0) {
      // Sample into the empty gutter so art that overhangs the cell is not cut,
      // while keeping the cell itself at the same on-screen position and scale.
      final scaleX = target.width / source.width;
      final scaleY = target.height / source.height;
      final left = math.max(0.0, source.left - bleedLeft);
      final right = math.min(image.width.toDouble(), source.right + bleedRight);
      final top = math.max(0.0, source.top - bleedTop);
      final bottom =
          math.min(image.height.toDouble(), source.bottom + bleedBottom);
      target = ui.Rect.fromLTRB(
        target.left - (source.left - left) * scaleX,
        target.top - (source.top - top) * scaleY,
        target.right + (right - source.right) * scaleX,
        target.bottom + (bottom - source.bottom) * scaleY,
      );
      source = ui.Rect.fromLTRB(left, top, right, bottom);
    }
    if (shift != ui.Offset.zero) {
      target = target.translate(
        shift.dx * target.width / source.width,
        shift.dy * target.height / source.height,
      );
    }
    final paint = ui.Paint()..color = ui.Color.fromRGBO(255, 255, 255, opacity);
    canvas.drawImageRect(image, source, target, paint);
  }

  void _drawBackground(ui.Canvas canvas, double scale, double viewportWidth) {
    final key = _text(level['bg']);
    final image = _image(key);
    if (image == null) {
      canvas.drawColor(const ui.Color(0xff637c4d), ui.BlendMode.src);
      return;
    }
    final drawHeight = size.y;
    final drawWidth = image.width * (drawHeight / image.height);
    final parallax = cameraX * 0.12 * scale;
    var left = -parallax % drawWidth;
    while (left > 0) {
      left -= drawWidth;
    }
    var index = 0;
    while (left < viewportWidth) {
      final destination = ui.Rect.fromLTWH(left, 0, drawWidth, drawHeight);
      final paint = ui.Paint();
      if (index.isOdd) {
        canvas.save();
        canvas.translate(left + drawWidth, 0);
        canvas.scale(-1, 1);
        canvas.drawImageRect(
          image,
          ui.Rect.fromLTWH(
            0,
            0,
            image.width.toDouble(),
            image.height.toDouble(),
          ),
          ui.Rect.fromLTWH(0, 0, drawWidth, drawHeight),
          paint,
        );
        canvas.restore();
      } else {
        canvas.drawImageRect(
          image,
          ui.Rect.fromLTWH(
            0,
            0,
            image.width.toDouble(),
            image.height.toDouble(),
          ),
          destination,
          paint,
        );
      }
      left += drawWidth;
      index++;
    }
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    if (frameViewer) {
      _renderFrameViewer(canvas);
      return;
    }
    if (size.x <= 0 || size.y <= 0 || areas.isEmpty) return;
    final scale = size.y / _viewHeight;
    final worldWidth = size.x / scale;
    final targetY = (playerY - _viewHeight * 0.66)
        .clamp(0.0, _worldHeight - _viewHeight);
    cameraY += (targetY - cameraY) * 0.08;
    final lookAhead = facing * 105 * (mode == 'biped' ? 0.55 : 1);
    final target = playerX + lookAhead - worldWidth * 0.42;
    cameraX += (target - cameraX) * 0.1;
    final halfWidth = _playerWidth() / 2;
    final margin = halfWidth + 8;
    cameraX = cameraX.clamp(playerX - worldWidth + margin, playerX - margin);
    final shakeX = shake > 0 ? math.sin(time * 72) * 6 * shake : 0.0;

    canvas.save();
    _drawBackground(canvas, scale, size.x);
    canvas.save();
    canvas.scale(scale);
    canvas.translate(-cameraX + shakeX, -cameraY);
    _drawZones(canvas);
    _drawPlatforms(canvas);
    _drawObjects(canvas);
    _drawPickups(canvas);
    _drawEnemies(canvas);
    _drawEffects(canvas);
    _drawPlayer(canvas);
    _drawTutorial(canvas);
    canvas.restore();
    _drawAtmosphere(canvas, scale);
    canvas.restore();
  }

  void _drawZones(ui.Canvas canvas) {
    for (final zone in _maps(level['zones'])) {
      final type = _text(zone['type']);
      final x = _number(zone['x']);
      final width = _number(zone['w']);
      var rect = ui.Rect.fromLTWH(x, 450, width, 230);
      var color = const ui.Color(0x3354a8ac);
      if (type == 'grass') {
        rect = ui.Rect.fromLTWH(x, 490, width, 65);
        color = const ui.Color(0x66475f31);
      } else if (type == 'ash') {
        color = const ui.Color(0x55413a36);
      } else if (type == 'honey') {
        color = const ui.Color(0x334d3c17);
      } else if (type == 'wind') {
        color = const ui.Color(0x193c86a3);
      } else if (type == 'steam') {
        color = const ui.Color(0x33f59c66);
      } else if (type == 'warm') {
        color = const ui.Color(0x33ffba80);
      } else if (type == 'ice') {
        color = const ui.Color(0x335bd2e2);
        rect = ui.Rect.fromLTWH(x, 520, width, 55);
      }
      canvas.drawRect(rect, ui.Paint()..color = color);
    }
  }

  void _drawPlatforms(ui.Canvas canvas) {
    final tile = _text(level['tile']);
    final seasonColor = _areaGroundColor();
    for (final ground in platforms) {
      if (_bool(ground['hidden']) && instinctTimer <= 0) continue;
      final x = _number(ground['x']);
      final y = _number(ground['y']);
      final width = _number(ground['w']);
      final height = math
          .max(42, math.min(150, _number(ground['h'], 180)))
          .toDouble();
      canvas.drawRect(
        ui.Rect.fromLTWH(x, y, width, height),
        ui.Paint()..color = seasonColor.withValues(alpha: 0.9),
      );
      var tileX = x;
      while (tileX < x + width) {
        final tileWidth = math.min(100, x + width - tileX).toDouble();
        _drawCell(
          canvas,
          tile,
          1,
          1,
          ui.Rect.fromLTWH(tileX, y - 30, tileWidth, height + 30),
          opacity: _bool(ground['hidden']) ? 0.65 : 1,
          contain: false,
        );
        tileX += tileWidth;
      }
      if (_bool(ground['hidden'])) {
        canvas.drawRect(
          ui.Rect.fromLTWH(x, y - 5, width, 7),
          ui.Paint()
            ..color = const ui.Color(0xffb3eff1).withValues(alpha: 0.55),
        );
      }
    }
  }

  ui.Color _areaGroundColor() {
    if (areaIndex >= 8) return const ui.Color(0xff718d99);
    if (areaIndex >= 6) return const ui.Color(0xff9c7049);
    if (areaIndex >= 3) return const ui.Color(0xff81734b);
    return const ui.Color(0xff65854a);
  }

  void _drawObjects(ui.Canvas canvas) {
    for (final object in objects) {
      if (_bool(object['opened']) && object['type'] != 'checkpoint_tree') {
        continue;
      }
      final type = _text(object['type']);
      final atlas = _text(object['atlas'], 'WORLD_PROPS');
      final columns = _columns(atlas);
      final rows = _rows(atlas);
      final index = _stableIndex(type);
      final opacity = _bool(object['trap']) && instinctTimer <= 0 ? 0.6 : 1.0;
      final width = _number(object['w'], 75);
      final height = _number(object['h'], 75);
      _drawCell(
        canvas,
        atlas,
        index % columns,
        (index ~/ columns) % rows,
        ui.Rect.fromLTWH(
          _number(object['x']) - width / 2,
          _number(object['y']) - height,
          width,
          height,
        ),
        opacity: opacity,
      );
      if (type == 'checkpoint_tree' && _bool(object['activated'])) {
        canvas.drawCircle(
          ui.Offset(_number(object['x']), _number(object['y']) - 60),
          58,
          ui.Paint()
            ..color = const ui.Color(0xffffd66e).withValues(alpha: 0.18)
            ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 14),
        );
      }
    }
  }

  // (column, row) of each food in its atlas.
  static const Map<String, Map<String, (int, int)>> _foodCells = {
    'FOOD_ATLAS': {
      'spring_berries': (0, 0),
      'salmon': (1, 0),
      'honeycomb': (2, 0),
      'apple': (3, 0),
      'pumpkin': (0, 1),
      'acorns': (1, 1),
      'fat_cache': (2, 1),
      'healing_herbs': (3, 1),
    },
    'YEAR2_FOOD': {
      'mineral_salt': (0, 0),
      'pine_cone': (1, 0),
      'cloudberry': (2, 0),
      'cave_berry': (3, 0),
      'fireweed_root': (4, 0),
      'mussels': (0, 1),
      'moon_berries': (1, 1),
      'winter_pear': (2, 1),
      'trout': (3, 1),
      'spring_herbs': (4, 1),
    },
  };

  void _drawPickups(ui.Canvas canvas) {
    for (final pickup in pickups) {
      if (_bool(pickup['collected']) ||
          (_bool(pickup['hidden']) && instinctTimer <= 0)) {
        continue;
      }
      final type = _text(pickup['type']);
      final atlas = _text(pickup['atlas'], 'FOOD_ATLAS');
      final cell = _foodCells[atlas]?[type];
      final index = _stableIndex(type);
      final bob = math.sin(time * 3 + _number(pickup['x'])) * 7;
      _drawCell(
        canvas,
        atlas,
        cell?.$1 ?? index % _columns(atlas),
        cell?.$2 ?? (index ~/ _columns(atlas)) % _rows(atlas),
        ui.Rect.fromLTWH(
          _number(pickup['x']) - 27,
          _number(pickup['y']) - 27 + bob,
          54,
          54,
        ),
        // Fins, leaves and drips poke a little past the 320px cell edge.
        bleedLeft: 30,
        bleedRight: 30,
        bleedTop: 30,
        bleedBottom: 30,
      );
    }
    if (!collectedClaws.contains(areaIndex) && level['claw'] is Map) {
      final claw = _asMap(level['claw']);
      _drawCell(
        canvas,
        'UI_ICONS',
        2,
        1,
        ui.Rect.fromLTWH(
          _number(claw['x']) - 28,
          _number(claw['y']) - 28 + math.sin(time * 3.8) * 8,
          56,
          56,
        ),
      );
    }
  }

  void _drawEnemies(ui.Canvas canvas) {
    for (final enemy in enemies) {
      final atlas = _text(enemy['sheet'], _text(level['enemySheet']));
      final alerted = _number(enemy['alert']) > 0;
      final row =
          _stableIndex(_text(alerted ? enemy['attackAnim'] : enemy['anim'])) %
          4;
      final frame = (time * (alerted ? 10 : 6)).floor() % 5;
      final isStunned = _number(enemy['stunned']) > 0;
      final width = 84 * _number(enemy['scale'], 1).clamp(0.7, 1.4);
      final height = 84 * _number(enemy['scale'], 1).clamp(0.7, 1.4);
      _drawEntity(
        canvas,
        atlas,
        frame,
        row,
        _number(enemy['x']),
        _number(enemy['y']),
        width,
        height,
        facing: _number(enemy['direction'], 1),
        opacity: isStunned ? 0.55 : 1,
      );
      if (_bool(enemy['human']) && !alerted) {
        final direction = _number(enemy['direction'], 1);
        final path = ui.Path()
          ..moveTo(_number(enemy['x']), _number(enemy['y']) - 65)
          ..lineTo(
            _number(enemy['x']) + direction * _number(enemy['range']),
            _number(enemy['y']) - 140,
          )
          ..lineTo(
            _number(enemy['x']) + direction * _number(enemy['range']),
            _number(enemy['y']) + 5,
          )
          ..close();
        canvas.drawPath(path, ui.Paint()..color = const ui.Color(0x22ffcf5b));
      }
    }
  }

  ({String sheet, String anim, int frameIndex, double worldHeight}) _playerFrame() {
    final skin = skins.where((item) => item['id'] == selectedSkin).firstOrNull;
    final sheets = skin?['sheets'];
    final baseKey = _actionAnimation == null
        ? (mode == 'biped' ? 'URSA_BIPED_CORE' : 'URSA_QUAD_CORE')
        : _text(
            _actionSheet,
            mode == 'biped' ? 'URSA_BIPED_CORE' : 'URSA_QUAD_CORE',
          );
    final sheet = sheets is Map ? _text(sheets[baseKey], baseKey) : baseKey;
    final worldHeight = (mode == 'biped' ? 138.0 : 112.0) * _playerScale;
    final String anim;
    int frameIndex;
    if (_actionAnimation != null) {
      anim = _actionAnimation!;
      final progress = (_actionAge / math.max(0.001, _actionDuration)).clamp(
        0,
        0.999,
      );
      frameIndex = (progress * 5).floor();
      if (_actionReverse) frameIndex = 4 - frameIndex;
    } else if (!grounded) {
      anim = mode == 'biped' ? 'biped_jump' : 'quad_jump';
      frameIndex = ((velocityY + 700) / 290).floor().clamp(0, 4);
    } else if (moving) {
      anim = mode == 'biped' ? 'biped_walk' : 'quad_run';
      frameIndex = (_runCycle / 28).floor() % 5;
    } else {
      anim = mode == 'biped' ? 'biped_idle' : 'quad_sniff';
      frameIndex = (time * (moving ? (mode == 'biped' ? 9 : 11) : 5)).floor() % 5;
    }
    return (sheet: sheet, anim: anim, frameIndex: frameIndex, worldHeight: worldHeight);
  }

  double _playerWidth() {
    final frame = _playerFrame();
    final crop = _lookupFrame(frame.sheet, anim: frame.anim, frameIndex: frame.frameIndex);
    if (crop.$1 != null) {
      return crop.$1!.width * (frame.worldHeight / crop.$1!.height);
    }
    return (mode == 'biped' ? 116.0 : 150.0) * _playerScale;
  }

  static const double _playerStretchX = 0.95;
  static const double _playerStretchY = 1.10;

  void _drawPlayer(ui.Canvas canvas) {
    canvas.save();
    canvas.translate(playerX, playerY);
    canvas.scale(_playerStretchX, _playerStretchY);
    canvas.translate(-playerX, -playerY);
    _drawPlayerFrame(canvas);
    canvas.restore();
  }

  void _drawPlayerFrame(ui.Canvas canvas) {
    final frame = _playerFrame();
    final sheet = frame.sheet;
    final worldHeight = frame.worldHeight;
    final blink = invulnerable > 0 && (time * 14).floor().isEven;
    final lookup = _lookupFrame(sheet, anim: frame.anim, frameIndex: frame.frameIndex);
    if (lookup.$1 != null) {
      _drawSprite(
        canvas,
        sheet,
        lookup.$1!,
        playerX,
        playerY,
        worldHeight,
        facing,
        blink ? 0.45 : 1,
      );
      return;
    }
    var row = 0;
    final int frameIndex = frame.frameIndex;
    if (_actionAnimation != null) {
      row = _actionRows[_actionAnimation] ?? 3;
    } else if (!grounded) {
      row = 2;
    } else if (moving) {
      row = 1;
    } else if (mode == 'quad') {
      row = 0;
    }
    var drawSheet = sheet;
    var drawFrame = frameIndex;
    if (_image(sheet) == null) {
      // Action sheets load in the background; until then show the core pose.
      final base = mode == 'biped' ? 'URSA_BIPED_CORE' : 'URSA_QUAD_CORE';
      drawSheet = _skinSheetMap(selectedSkin)[base] ?? base;
      row = 0;
      drawFrame = 0;
    }
    _drawPlayerCell(
      canvas,
      drawSheet,
      row,
      drawFrame,
      playerX,
      playerY,
      biped: mode == 'biped',
      facing: facing,
      opacity: blink ? 0.45 : 1,
    );
  }

  void viewerNextSkin() {
    if (skins.isNotEmpty) _viewerSkin = (_viewerSkin + 1) % skins.length;
  }

  static const List<String> _viewerQuadNames = <String>[
    'Diam (endus)',
    'Lari',
    'Lompat',
    'Aksi',
  ];
  static const List<String> _viewerBipedNames = <String>[
    'Diam',
    'Jalan',
    'Lompat',
    'Aksi',
  ];
  // Approximate in-game playback rates per sheet row.
  static const List<double> _viewerQuadFps = <double>[5, 14.6, 6, 12];
  static const List<double> _viewerBipedFps = <double>[5, 8.6, 6, 12];

  void _renderFrameViewer(ui.Canvas canvas) {
    canvas.drawColor(const ui.Color(0xff182219), ui.BlendMode.src);
    if (loading || skins.isEmpty || size.x <= 0 || size.y <= 0) return;
    const cellW = 310.0;
    const cellH = 360.0;
    const headerH = 40.0;
    const cream = ui.Color(0xfffff1cb);
    final scale = math.min(size.x / (cellW * 4), size.y / (cellH * 2 + headerH));
    canvas.save();
    canvas.translate((size.x - cellW * 4 * scale) / 2, 0);
    canvas.scale(scale);
    final skin = skins[_viewerSkin];
    final sheets = skin['sheets'];
    _viewerText(
      canvas,
      'PENAMPIL FRAME · skin: ${skin['id']}   (ketuk layar untuk ganti skin)',
      cellW * 2,
      10,
      18,
      cream,
      width: cellW * 4,
    );
    for (var mode = 0; mode < 2; mode++) {
      final biped = mode == 1;
      final baseKey = biped ? 'URSA_BIPED_CORE' : 'URSA_QUAD_CORE';
      final sheet = sheets is Map ? _text(sheets[baseKey], baseKey) : baseKey;
      for (var row = 0; row < 4; row++) {
        final left = row * cellW;
        final top = headerH + mode * cellH;
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromLTWH(left + 6, top + 6, cellW - 12, cellH - 12),
            const ui.Radius.circular(10),
          ),
          ui.Paint()..color = const ui.Color(0xff273328),
        );
        final fps = (biped ? _viewerBipedFps : _viewerQuadFps)[row];
        final frame = (_viewerTime * fps).floor() % 5;
        final name = (biped ? _viewerBipedNames : _viewerQuadNames)[row];
        _viewerText(
          canvas,
          '${biped ? 'Berdiri' : 'Merangkak'} · $name\n'
          'baris ${row + 1} · frame ${frame + 1}',
          left + cellW / 2,
          top + 12,
          13,
          cream,
        );
        final groundPaint = ui.Paint()
          ..color = const ui.Color(0x66fff1cb)
          ..strokeWidth = 1.5;
        const bigGround = 235.0;
        canvas.drawLine(
          ui.Offset(left + 20, top + bigGround),
          ui.Offset(left + cellW - 20, top + bigGround),
          groundPaint,
        );
        _drawViewerBear(canvas, sheet, row, frame, left + cellW / 2,
            top + bigGround, biped, 1);
        const stripGround = 318.0;
        for (var f = 0; f < 5; f++) {
          final fx = left + 35 + f * 60;
          if (f == frame) {
            canvas.drawRRect(
              ui.RRect.fromRectAndRadius(
                ui.Rect.fromLTWH(fx - 29, top + 250, 58, 92),
                const ui.Radius.circular(6),
              ),
              ui.Paint()..color = const ui.Color(0x33fff1cb),
            );
          }
          _drawViewerBear(
              canvas, sheet, row, f, fx, top + stripGround, biped, 0.3);
          _viewerText(canvas, '${f + 1}', fx, top + stripGround + 4, 12, cream,
              width: 40);
        }
      }
    }
    canvas.restore();
  }

  void _drawViewerBear(
    ui.Canvas canvas,
    String sheet,
    int row,
    int frame,
    double x,
    double y,
    bool biped,
    double scale,
  ) {
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(scale * _playerStretchX, scale * _playerStretchY);
    _drawPlayerCell(canvas, sheet, row, frame, 0, 0, biped: biped);
    canvas.restore();
  }

  void _viewerText(
    ui.Canvas canvas,
    String text,
    double x,
    double y,
    double fontSize,
    ui.Color color, {
    double width = 290,
  }) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: fontSize,
        fontWeight: ui.FontWeight.w700,
        textAlign: ui.TextAlign.center,
      ),
    )
      ..pushStyle(ui.TextStyle(color: color))
      ..addText(text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: width));
    canvas.drawParagraph(paragraph, ui.Offset(x - width / 2, y));
  }

  void _drawPlayerCell(
    ui.Canvas canvas,
    String sheet,
    int row,
    int frameIndex,
    double x,
    double y, {
    required bool biped,
    double facing = 1,
    double opacity = 1,
  }) {
    final height = (biped ? 138.0 : 112.0) * _playerScale;
    final width = (biped ? 116.0 : 150.0) * _playerScale;
    final margins = _frameMargins[sheet]?[row * 5 + frameIndex] ??
        (16.0, 56.0, biped ? 60.0 : 0.0, biped ? 8.0 : 0.0);
    var bleedRight = margins.$2;
    // Standing claw swipe (frame 3): keep the reach short so it stays clean.
    if (sheet.endsWith('BIPED_CORE') && row == 3 && frameIndex == 2) {
      bleedRight = math.min(bleedRight, 30);
    }
    final down = !sheet.endsWith('QUAD_CORE') ? 0.0 : (_quadFrameDown[(row, frameIndex)] ?? 0.0);
    _drawEntity(
      canvas,
      sheet,
      frameIndex,
      row,
      x,
      y,
      width,
      height,
      facing: facing,
      opacity: opacity,
      bleedLeft: margins.$1,
      bleedRight: bleedRight,
      bleedTop: margins.$3,
      bleedBottom: margins.$4,
      shift: _runFrameShift(sheet, row, frameIndex) + ui.Offset(0, down),
    );
  }

  // Sheet row of each action animation (rows read off the sprite sheets).
  static const Map<String, int> _actionRows = {
    'stance_shift': 0,
    'carve': 0,
    'ground_pound': 2,
    'eat': 3,
    'instinct': 2,
    'steam_brace': 0,
    'log_push': 1,
    'ice_balance': 2,
    'ash_shield': 3,
    'echo_sniff': 0,
    'moon_track': 1,
    'avalanche_pound': 2,
    'star_sleep': 3,
    'biped_claw': 3,
    'quad_tackle': 3,
  };

  // Quad frames moved down (sheet px), keyed by (sheet row, frame).
  static const Map<(int, int), double> _quadFrameDown = {
    (2, 1): 20,
    (2, 2): 20,
    (3, 2): 20,
  };

  // How far (sheet px) each frame samples beyond its 320px cell on the left,
  // right, top and bottom; negative crops inside. Generated from the sheets so
  // every frame shows all of its own art and none of a neighbour's (which wins
  // where the two touch). Indexed by sheet row * 5 + frame.
  static const Map<String, List<(double, double, double, double)>>
      _frameMargins = {
      'URSA_QUAD_CORE': [
        (16, 0, 0, 0),
        (25, 0, 0, 0),
        (9, 21, 0, 0),
        (0, 18, 0, 0),
        (9, 2, 0, 0),
        (24, 19, 0, 0),
        (0, 23, 0, 0),
        (39, 31, 0, 0),
        (19, 40, 0, 0),
        (0, 40, 0, 0),
        (11, 0, 0, 0),
        (46, 0, 0, 0),
        (37, 46, 0, 0),
        (0, 19, 0, 0),
        (0, 15, 0, 0),
        (41, 0, 0, 0),
        (37, 10, 0, 0),
        (14, 21, 0, 0),
        (20, 34, 0, 0),
        (6, 27, 0, 0),
      ],
      'URSA_BIPED_CORE': [
        (0, 0, 34, 0),
        (0, 0, 37, 0),
        (0, 0, 33, 0),
        (0, 0, 35, 0),
        (0, 0, 32, 0),
        (0, 0, 29, 0),
        (0, 0, 31, 0),
        (0, 0, 28, 0),
        (0, 0, 28, 0),
        (0, 0, 30, 0),
        (8, 0, 0, 7),
        (0, 0, 45, 0),
        (0, 19, 58, 0),
        (0, 0, 8, 8),
        (0, 0, 0, 8),
        (0, 0, 3, 10),
        (14, 0, 12, 10),
        (5, 65, 14, 10),
        (-27, 53, 1, 10),
        (0, 15, 0, 10),
      ],
      'URSA_SKILLS': [
        (0, 0, 19, 21),
        (0, 5, 31, 21),
        (0, 9, 33, 20),
        (0, 0, 0, 21),
        (0, 0, 4, 20),
        (0, 0, 8, 59),
        (0, 0, 21, 40),
        (0, 0, 20, 57),
        (0, 0, 5, 58),
        (0, 0, 0, 58),
        (0, 0, 0, 21),
        (0, 0, 13, 0),
        (15, 10, 0, 21),
        (0, 0, 0, 21),
        (0, 0, 0, 21),
        (0, 0, 0, 16),
        (0, 0, 0, 16),
        (0, 0, 3, 16),
        (0, 0, 6, 16),
        (0, 0, 1, 16),
      ],
      'URSA_SPECIAL': [
        (0, 0, 32, 65),
        (0, 0, 0, 65),
        (20, 7, 0, 65),
        (15, 25, 0, 65),
        (0, 16, 0, 65),
        (31, 15, 0, 0),
        (17, 13, 0, 0),
        (18, 21, 0, 0),
        (23, 22, 0, 0),
        (19, 26, 0, 0),
        (32, 40, 0, 0),
        (0, 44, 0, 0),
        (0, 0, 0, 0),
        (42, 13, 0, 0),
        (34, 19, 0, 0),
        (0, 2, 9, 0),
        (0, 0, 0, 0),
        (0, 0, 0, 0),
        (4, 6, 4, 0),
        (1, 2, 0, 0),
      ],
      'URSA_REACTIONS': [
        (30, 2, 24, 0),
        (15, 0, 0, 11),
        (8, 4, 0, 15),
        (3, 20, 0, 12),
        (0, 31, 0, 12),
        (23, 8, 0, 3),
        (4, 0, 0, 4),
        (2, 0, 0, 3),
        (1, 0, 0, 4),
        (4, 31, 0, 5),
        (28, 0, 0, 0),
        (16, 7, 0, 0),
        (10, 11, 22, 0),
        (0, 0, 0, 0),
        (5, 20, 0, 0),
        (27, 0, 5, 0),
        (12, 3, 0, 0),
        (1, 10, 0, 0),
        (0, 10, 0, 0),
        (0, 20, 0, 0),
      ],
      'URSA_YEAR2_SKILLS': [
        (9, 29, 3, 0),
        (2, 41, 0, 0),
        (0, 20, 0, 0),
        (0, 57, 0, 0),
        (0, 57, 1, 0),
        (22, 15, 25, 5),
        (14, 19, 9, 5),
        (20, 36, 0, 4),
        (6, 40, 0, 5),
        (0, 47, 23, 5),
        (17, 0, 0, 0),
        (0, 0, 0, 0),
        (20, 26, 0, 0),
        (0, 27, 0, 0),
        (0, 35, 0, 0),
        (10, 28, 28, 0),
        (0, 42, 34, 0),
        (0, 47, 19, 0),
        (0, 44, 24, 0),
        (0, 57, 37, 0),
      ],
      'URSA_YEAR2_INSTINCT': [
        (32, 0, 0, 0),
        (20, 11, 0, 0),
        (10, 25, 0, 0),
        (6, 12, 0, 0),
        (1, 33, 0, 0),
        (38, 10, 0, 0),
        (25, 26, 0, 0),
        (21, 36, 0, -18),
        (12, 41, 0, 0),
        (8, 41, 0, 0),
        (0, 0, 50, 31),
        (0, 0, 64, 36),
        (0, 0, 66, 38),
        (0, 0, 0, 31),
        (0, 8, 0, 37),
        (39, 3, 0, 0),
        (31, 19, 0, 0),
        (3, 1, 0, 0),
        (0, 4, 0, 0),
        (9, 33, 0, 0),
      ],
      'BLACK_QUAD_CORE': [
        (24, 0, 0, 0),
        (22, 11, 0, 0),
        (8, 21, 0, 0),
        (8, 21, 0, 0),
        (0, 30, 0, 0),
        (30, 16, 0, 0),
        (6, 9, 0, 0),
        (43, 65, 0, 0),
        (-3, 63, 0, 0),
        (2, 38, 0, 0),
        (27, 1, 0, 0),
        (43, -13, 50, 0),
        (66, 65, 64, -10),
        (-5, 65, 0, 0),
        (-6, 35, 0, 0),
        (20, 5, 0, 0),
        (43, 8, 0, 0),
        (40, 46, 66, 0),
        (5, 33, 0, 0),
        (6, 32, 0, 0),
      ],
      'BLACK_BIPED_CORE': [
        (0, 0, 29, 7),
        (0, 0, 30, 6),
        (0, 0, 30, 6),
        (0, 0, 30, 6),
        (0, 0, 30, 6),
        (0, 0, 31, 4),
        (0, 0, 35, 1),
        (0, 0, 33, 4),
        (0, 2, 31, 2),
        (0, 0, 32, 0),
        (13, 0, 0, 0),
        (0, 30, 40, 2),
        (0, 14, 46, 0),
        (0, 18, 40, 0),
        (0, 12, 0, 0),
        (0, 0, 38, 0),
        (10, 65, 39, 0),
        (-11, 38, 38, 0),
        (0, 0, 39, 0),
        (0, 8, 38, 0),
      ],
      'BLACK_SKILLS': [
        (7, 0, 28, 0),
        (0, 0, 29, 0),
        (0, 58, 28, 0),
        (0, 65, 26, 0),
        (-2, 1, 26, 0),
        (0, 0, 49, 17),
        (0, 0, 48, 17),
        (0, 0, 49, 17),
        (0, 0, 39, 17),
        (0, 14, 17, 17),
        (11, 0, 0, 11),
        (3, 0, 36, 11),
        (10, 8, 0, 24),
        (2, 0, 0, 11),
        (0, 10, 0, 11),
        (7, 0, 0, 2),
        (0, 0, 5, 0),
        (0, 0, 13, 0),
        (0, 0, 0, 0),
        (0, 0, 0, 2),
      ],
      'BLACK_SPECIAL': [
        (0, 0, 46, 38),
        (0, 0, 0, 37),
        (15, 0, 0, 35),
        (25, 18, 0, 37),
        (26, 40, 0, 37),
        (42, 24, 0, 0),
        (23, 24, 0, 0),
        (0, 15, 0, 0),
        (25, 23, 0, 0),
        (26, 38, 0, 0),
        (37, 39, 0, 0),
        (0, 31, 0, 0),
        (0, 0, 0, -2),
        (28, 16, 0, 0),
        (24, 41, 0, 0),
        (0, 0, 45, 4),
        (0, 0, 36, 5),
        (0, 0, 66, 4),
        (0, 0, 39, 4),
        (0, 0, 39, 4),
      ],
      'BLACK_REACTIONS': [
        (17, 8, 24, 0),
        (0, 4, 0, 13),
        (0, 19, 0, 16),
        (0, 17, 0, 16),
        (0, 25, 0, 15),
        (22, 10, 0, 8),
        (0, 0, 2, 7),
        (0, 17, 4, 8),
        (0, 6, 0, 6),
        (0, 19, 0, 8),
        (21, 10, 0, 0),
        (0, 9, 0, 0),
        (0, 23, 0, 0),
        (0, 23, 0, 0),
        (0, 20, 0, 0),
        (23, 10, 0, 0),
        (9, 16, 0, 0),
        (12, 23, 0, 0),
        (0, 17, 0, 0),
        (0, 7, 0, 0),
      ],
      'BLACK_YEAR2_SKILLS': [
        (0, 0, 23, 27),
        (0, 0, 1, 27),
        (6, 2, 0, 28),
        (0, 1, 13, 27),
        (0, 0, 17, 27),
        (18, 35, 14, 35),
        (25, 53, 0, 36),
        (-20, 65, 0, 35),
        (-51, 58, 7, 34),
        (0, 0, 9, 34),
        (26, 16, 0, 0),
        (35, 22, 0, 0),
        (26, 32, 0, 0),
        (16, 41, 0, 0),
        (9, 37, 0, 0),
        (16, 30, 56, 0),
        (12, 0, 48, 0),
        (4, 0, 38, 0),
        (0, 37, 45, 0),
        (0, 47, 54, 0),
      ],
      'BLACK_YEAR2_INSTINCT': [
        (29, 25, 0, 0),
        (24, 28, 5, 0),
        (22, 25, 15, 0),
        (16, 22, 0, 0),
        (11, 31, 0, 0),
        (32, 38, 0, -37),
        (17, 45, 0, 0),
        (0, 46, 0, 0),
        (9, 42, 0, 0),
        (13, 41, 0, -37),
        (16, 0, 66, 0),
        (20, 4, 42, 0),
        (22, 26, 0, 3),
        (3, 4, 14, 0),
        (0, 20, 66, 0),
        (34, 15, 0, 0),
        (12, 24, 0, 0),
        (9, 29, 0, 0),
        (0, 37, 0, 0),
        (0, 38, 0, 0),
      ],
      'CINNAMON_QUAD_CORE': [
        (25, 0, 0, 0),
        (14, 13, 0, 0),
        (5, 29, 0, 0),
        (0, 19, 0, 0),
        (0, 25, 0, 0),
        (32, 15, 0, 0),
        (11, 26, 0, 0),
        (37, 56, 0, 0),
        (0, 55, 0, 0),
        (0, 43, 0, 0),
        (13, 0, 0, 0),
        (36, 0, 27, 0),
        (61, 42, 22, 0),
        (8, 33, 0, 0),
        (0, 29, 0, 0),
        (35, 0, 0, 0),
        (42, 39, 0, 0),
        (7, 36, 4, 0),
        (13, 36, 2, 0),
        (0, 40, 0, 0),
      ],
      'CINNAMON_BIPED_CORE': [
        (0, 0, 29, 5),
        (0, 0, 40, 6),
        (0, 0, 30, 5),
        (0, 0, 30, 5),
        (0, 0, 0, 5),
        (0, 0, 30, 0),
        (0, 0, 33, 0),
        (0, 0, 32, -4),
        (0, 0, 32, 0),
        (0, 0, 31, 0),
        (0, 0, 0, 8),
        (3, 11, 52, 0),
        (0, 17, 66, 0),
        (0, 32, 33, 0),
        (0, 11, 0, 8),
        (0, 0, 24, 10),
        (6, 0, 29, 9),
        (18, 65, 34, 7),
        (-17, 47, 13, 9),
        (0, 0, 12, 11),
      ],
      'CINNAMON_SKILLS': [
        (0, 0, 18, 3),
        (0, 0, 29, 3),
        (0, 4, 0, 3),
        (0, 5, 0, 3),
        (0, 0, 9, 3),
        (0, 0, 24, 26),
        (0, 0, 24, 26),
        (0, 0, 34, 27),
        (0, 0, 24, 24),
        (0, 0, 31, 27),
        (10, 0, 4, 26),
        (5, 0, 0, 14),
        (45, 46, 0, 27),
        (0, 1, 0, 21),
        (0, 8, 4, 26),
        (5, 0, 0, 12),
        (0, 0, 0, 12),
        (0, 0, 0, 13),
        (0, 0, 0, 12),
        (0, 8, 0, 12),
      ],
      'CINNAMON_SPECIAL': [
        (0, 0, 36, 63),
        (0, 0, 35, 63),
        (0, 0, 30, 62),
        (0, 0, 32, 63),
        (0, 0, 36, 63),
        (30, 28, 0, 0),
        (0, 25, 0, 20),
        (13, 23, 0, 22),
        (0, 29, 0, 19),
        (21, 30, 0, 21),
        (28, 27, 0, 0),
        (27, 21, 0, 0),
        (27, 27, 0, 0),
        (26, 23, 0, 0),
        (26, 31, 0, 0),
        (0, 0, 16, 0),
        (0, 0, 5, 0),
        (0, 0, 0, 0),
        (0, 0, 3, 0),
        (1, 0, 8, 0),
      ],
      'CINNAMON_REACTIONS': [
        (18, 53, 38, 0),
        (0, 6, 0, 6),
        (0, 29, 0, 19),
        (0, 24, 0, 19),
        (0, 27, 0, 19),
        (24, 24, 0, 14),
        (8, 5, 0, 12),
        (0, 0, 0, 12),
        (0, 2, 0, 12),
        (11, 30, 0, 12),
        (23, 23, 0, 5),
        (33, 42, 0, 1),
        (7, 65, 0, 0),
        (-6, 31, 0, 0),
        (0, 13, 9, 0),
        (24, 23, 12, 0),
        (0, 26, 7, 0),
        (0, 14, 4, 0),
        (0, 15, 0, 0),
        (0, 28, 0, 0),
      ],
      'CINNAMON_YEAR2_SKILLS': [
        (0, 0, 24, 2),
        (20, 0, 28, 2),
        (22, 65, 0, 2),
        (-24, 0, 0, 3),
        (0, 0, 21, 3),
        (31, 0, 16, 9),
        (35, 10, 0, 9),
        (31, 61, 0, 10),
        (-6, 20, 0, 9),
        (0, 32, 16, 9),
        (30, 2, 0, 0),
        (20, 27, 0, 0),
        (27, 46, 0, 0),
        (0, 35, 0, 0),
        (0, 31, 0, 0),
        (33, 0, 38, 4),
        (0, 0, 38, 5),
        (18, 35, 38, 4),
        (0, 0, 38, 4),
        (0, 35, 37, 3),
      ],
      'CINNAMON_YEAR2_INSTINCT': [
        (19, 21, 0, 4),
        (12, 5, 0, 4),
        (8, 0, 40, 4),
        (7, 9, 0, 4),
        (5, 29, 0, 4),
        (24, 2, 0, -13),
        (21, 21, 0, 0),
        (17, 25, 0, 0),
        (14, 28, 0, 0),
        (11, 28, 0, 0),
        (17, 0, 66, 14),
        (38, 0, 13, 14),
        (35, 0, 0, 21),
        (42, 30, 0, 23),
        (7, 28, 0, 11),
        (23, 6, 0, 0),
        (7, 24, 0, 0),
        (0, 13, 0, 0),
        (5, 22, 0, 0),
        (0, 29, 0, 0),
      ],
  };

  // The run frames (sheet row 2) are not drawn at a consistent spot inside
  // their cells, so the bear lurches back and forth each cycle. These shifts
  // (sheet px) re-centre each frame on its centre of mass and put planted
  // frames on one ground line. Precomputed offline from the sprite sheets:
  // reading pixels back from the GPU at runtime stalls rendering on Android.
  static const Map<String, List<ui.Offset>> _runFrameShifts = {
    'URSA_QUAD_CORE': [
      ui.Offset(3.1, 8.0),
      ui.Offset(-13.5, 18.0),
      ui.Offset(-6.3, 0.0),
      ui.Offset(-15.2, 0.0),
      ui.Offset(-11.4, 1.0),
    ],
    'BLACK_QUAD_CORE': [
      ui.Offset(4.9, 0.0),
      ui.Offset(-1.6, 2.0),
      ui.Offset(-16.4, 0.0),
      ui.Offset(-24.1, 0.0),
      ui.Offset(-2.5, 0.0),
    ],
    'CINNAMON_QUAD_CORE': [
      ui.Offset(0.6, 2.0),
      ui.Offset(-3.2, 0.0),
      ui.Offset(-17.1, 0.0),
      ui.Offset(-20.2, 1.0),
      ui.Offset(-15.3, 0.0),
    ],
  };

  ui.Offset _runFrameShift(String sheet, int row, int frameIndex) {
    if (row != 1) return ui.Offset.zero;
    final shifts = _runFrameShifts[sheet];
    return shifts == null ? ui.Offset.zero : shifts[frameIndex % shifts.length];
  }

  void _drawEntity(
    ui.Canvas canvas,
    String key,
    int column,
    int row,
    double x,
    double y,
    double width,
    double height, {
    double facing = 1,
    double opacity = 1,
    double bleedLeft = 0,
    double bleedRight = 0,
    double bleedTop = 0,
    double bleedBottom = 0,
    ui.Offset shift = ui.Offset.zero,
  }) {
    canvas.save();
    canvas.translate(x, y);
    if (facing < 0) canvas.scale(-1, 1);
    _drawCell(
      canvas,
      key,
      column,
      row,
      ui.Rect.fromLTWH(-width / 2, -height, width, height),
      opacity: opacity,
      bleedLeft: bleedLeft,
      bleedRight: bleedRight,
      bleedTop: bleedTop,
      bleedBottom: bleedBottom,
      shift: shift,
    );
    canvas.restore();
  }

  void _drawEffects(ui.Canvas canvas) {
    for (final effect in _effects) {
      final age = _number(effect['age']);
      final duration = _number(effect['duration'], 0.5);
      final progress = (age / duration).clamp(0, 1);
      final color = effect['color'] is ui.Color
          ? effect['color'] as ui.Color
          : const ui.Color(0xffe6c780);
      canvas.drawCircle(
        ui.Offset(_number(effect['x']), _number(effect['y']) - 22),
        8 + progress * 34,
        ui.Paint()
          ..color = color.withValues(alpha: (1 - progress) * 0.45)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }
  }

  void _drawTutorial(ui.Canvas canvas) {
    if (areaIndex != 0 || playerX > 720) return;
    final label = mode == 'quad'
        ? 'SHIFT untuk berdiri'
        : 'SHIFT untuk merangkak';
    _drawLabel(
      canvas,
      label,
      playerX + 100,
      388,
      18,
      const ui.Color(0xfffff2cf),
    );
  }

  void _drawLabel(
    ui.Canvas canvas,
    String text,
    double x,
    double y,
    double fontSize,
    ui.Color color,
  ) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              fontSize: fontSize,
              fontWeight: ui.FontWeight.w800,
              textAlign: ui.TextAlign.center,
            ),
          )
          ..pushStyle(ui.TextStyle(color: color))
          ..addText(text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: 240));
    final bg = ui.Rect.fromLTWH(x - 130, y - 22, 260, paragraph.height + 10);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(bg, const ui.Radius.circular(9)),
      ui.Paint()..color = const ui.Color(0xcc1b1f14),
    );
    canvas.drawParagraph(paragraph, ui.Offset(x - 120, y - 18));
  }

  void _drawAtmosphere(ui.Canvas canvas, double scale) {
    if (areaIndex == 7) {
      final dusk = 1 - (areaTimer / 55).clamp(0, 1);
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, size.x, size.y),
        ui.Paint()
          ..color = const ui.Color(0xff1c152e).withValues(alpha: dusk * 0.34),
      );
    }
    if (areaIndex == 9 || _bool(level['cold']) || _bool(level['noise'])) {
      for (var index = 0; index < 46; index++) {
        final x = ((index * 79 + time * 170) % (size.x + 100)) - 50;
        final y = (index * 131) % size.y;
        canvas.drawCircle(
          ui.Offset(x, y),
          1.2 + (index % 3),
          ui.Paint()..color = const ui.Color(0x66eef9ff),
        );
      }
    }
    if (_bool(level['dark'])) {
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, size.x, size.y),
        ui.Paint()
          ..color = const ui.Color(
            0xff030915,
          ).withValues(alpha: instinctTimer > 0 ? 0.34 : 0.68),
      );
      if (instinctTimer > 0) {
        final px = (playerX - cameraX) * scale;
        final py = (playerY - cameraY) * scale - 38 * scale;
        final glow = ui.Gradient.radial(
          ui.Offset(px, py),
          190 * scale,
          const <ui.Color>[ui.Color(0x428de8ef), ui.Color(0x008de8ef)],
        );
        canvas.drawCircle(
          ui.Offset(px, py),
          190 * scale,
          ui.Paint()
            ..shader = glow
            ..blendMode = ui.BlendMode.screen,
        );
      }
    }
  }

  int _stableIndex(String text) =>
      text.codeUnits.fold<int>(0, (sum, value) => sum + value);
}

Map<String, dynamic> _asMap(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

List<Map<String, dynamic>> _maps(dynamic value) =>
    value is List ? value.map(_asMap).toList() : <Map<String, dynamic>>[];

double _number(dynamic value, [double fallback = 0]) =>
    value is num ? value.toDouble() : fallback;

bool _bool(dynamic value) => value == true;

String _text(dynamic value, [String fallback = '']) =>
    value == null ? fallback : value.toString();
