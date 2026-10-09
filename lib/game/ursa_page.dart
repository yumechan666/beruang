import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ursa_game.dart';

const _ink = Color(0xff182219);
const _panel = Color(0xff273328);
const _gold = Color(0xffe7c678);
const _cream = Color(0xfffff1cb);

class UrsaPage extends StatefulWidget {
  const UrsaPage({super.key, this.audioEnabled = true});

  final bool audioEnabled;

  @override
  State<UrsaPage> createState() => _UrsaPageState();
}

class _UrsaPageState extends State<UrsaPage> {
  late final UrsaGame _game;
  final FocusNode _focusNode = FocusNode(debugLabel: 'URSA controls');

  @override
  void initState() {
    super.initState();
    _game = UrsaGame(audioEnabled: widget.audioEnabled);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _game.revision.dispose();
    unawaited(_game.audio.dispose());
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    _game.handleKey(event.logicalKey, event is! KeyUpEvent);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      body: Focus(
        autofocus: true,
        focusNode: _focusNode,
        onKeyEvent: _onKey,
        child: ValueListenableBuilder<int>(
          valueListenable: _game.revision,
          builder: (context, revision, _) {
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                GameWidget<UrsaGame>(
                  game: _game,
                  loadingBuilder: (_) => const Center(
                    child: CircularProgressIndicator(color: _gold),
                  ),
                ),
                if (_game.loading) const _LoadingOverlay(),
                if (_game.menuOpen && !_game.loading)
                  _StartMenu(
                    game: _game,
                    onStart: (area, skin) {
                      _game.startArea(area, skin);
                      _focusNode.requestFocus();
                    },
                  ),
                if (_game.controlsVisible) ...<Widget>[
                  _Hud(game: _game, onMenu: _game.openMenu),
                  _TouchControls(game: _game),
                  if (_game.message != null && _game.messageTimer > 0)
                    _Toast(message: _game.message!),
                ],
                if (_game.ending) _EndingOverlay(game: _game),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xdd101810),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(color: _gold),
            SizedBox(height: 18),
            Text(
              'MENYIAPKAN JEJAK MUSIM…',
              style: TextStyle(color: _cream, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartMenu extends StatefulWidget {
  const _StartMenu({required this.game, required this.onStart});

  final UrsaGame game;
  final void Function(int area, String skin) onStart;

  @override
  State<_StartMenu> createState() => _StartMenuState();
}

class _StartMenuState extends State<_StartMenu> {
  late int _selectedArea;
  late String _selectedSkin;
  String _tab = 'levels';

  @override
  void initState() {
    super.initState();
    _selectedArea = widget.game.started ? widget.game.areaIndex : 0;
    _selectedSkin = widget.game.selectedSkin;
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _panel,
        title: const Text(
          'Reset semua progres?',
          style: TextStyle(color: _cream, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Area yang terbuka, koin, skin yang dibeli, cap cakar, checkpoint '
          'dan simpanan permainan akan dihapus. Tindakan ini tidak bisa '
          'dibatalkan.',
          style: TextStyle(color: Color(0xffe3d6ad)),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('BATAL', style: TextStyle(color: _cream)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'RESET',
              style: TextStyle(
                color: Color(0xffe8a08a),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.game.resetAllProgress();
    if (!mounted) return;
    setState(() {
      _selectedArea = 0;
      _selectedSkin = widget.game.selectedSkin;
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final areas = game.areas;
    final skins = game.skins;
    final size = MediaQuery.sizeOf(context);
    final panelHeight = math.min(size.height * 0.94, 760.0);
    final panelWidth = math.min(size.width * 0.94, 620.0);

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (areas.isNotEmpty)
            _Backdrop(game: game, area: areas[_selectedArea]),
          ColoredBox(color: _ink.withValues(alpha: 0.5)),
          Center(
            child: Container(
              width: panelWidth,
              height: panelHeight,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _panel.withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _gold.withValues(alpha: 0.72),
                  width: 2,
                ),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x88000000),
                    blurRadius: 28,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                children: <Widget>[
                  const Text(
                    '20 AREA · 3 SKIN · 3 KESEMPATAN',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Pijak Pijak Cakar',
                    style: TextStyle(
                      color: _cream,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      height: 0.95,
                    ),
                  ),
                  const Text(
                    'Pijak Pijak Cakar',
                    style: TextStyle(
                      color: Color(0xffd8c89e),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _MenuTab(
                          label: 'LEVEL',
                          selected: _tab == 'levels',
                          onTap: () => setState(() => _tab = 'levels'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MenuTab(
                          label: 'SKIN',
                          selected: _tab == 'skins',
                          onTap: () => setState(() => _tab = 'skins'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _tab == 'levels'
                        ? GridView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: areas.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 5,
                                  crossAxisSpacing: 6,
                                  mainAxisSpacing: 6,
                                  childAspectRatio: 1.15,
                                ),
                            itemBuilder: (context, index) {
                              final area = areas[index];
                              return _LevelTile(
                                game: game,
                                area: area,
                                index: index,
                                locked: index > game.highestUnlockedArea,
                                selected: _selectedArea == index,
                                onTap: () =>
                                    setState(() => _selectedArea = index),
                              );
                            },
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            itemCount: skins.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                            itemBuilder: (context, index) {
                              final skin = skins[index];
                              final skinId = skin['id'].toString();
                              final selected = _selectedSkin == skinId;
                              final owned = game.purchasedSkins.contains(
                                skinId,
                              );
                              final price =
                                  (skin['price'] as num?)?.toInt() ?? 0;
                              final swatch = _parseColor(
                                skin['swatch']?.toString(),
                              );
                              return GestureDetector(
                                onTap: () {
                                  if (owned) {
                                    setState(() => _selectedSkin = skinId);
                                  } else if (game.purchaseSkin(skinId)) {
                                    setState(() => _selectedSkin = skinId);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: swatch.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: selected
                                          ? _gold
                                          : swatch.withValues(alpha: 0.8),
                                      width: selected ? 3 : 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Expanded(
                                        child: _SkinPreview(
                                          game: game,
                                          skin: skin,
                                          tint: swatch,
                                        ),
                                      ),
                                      Text(
                                        skin['name'].toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: _cream,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        skin['description'].toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xffd8c99e),
                                          fontSize: 10,
                                        ),
                                      ),
                                      Text(
                                        owned
                                            ? (price == 0
                                                  ? 'GRATIS'
                                                  : 'DIMILIKI')
                                            : 'BELI · $price KOIN',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: owned ? _gold : _cream,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${(_selectedArea + 1).toString().padLeft(2, '0')} · ${areas[_selectedArea]['name']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _cream,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              _skinName(skins, _selectedSkin),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'KOIN ${game.totalFood}',
                              style: const TextStyle(
                                color: _cream,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton.icon(
                        onPressed: _confirmReset,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xffe8a08a),
                        ),
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: const Text(
                          'RESET',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _PrimaryButton(
                        label: game.hasSessionFor(_selectedArea)
                            ? 'LANJUTKAN'
                            : 'MULAI',
                        onPressed: () =>
                            widget.onStart(_selectedArea, _selectedSkin),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.game, required this.area});

  final UrsaGame game;
  final Map<String, dynamic> area;

  @override
  Widget build(BuildContext context) {
    final path = game.imageAssetPath(area['bg'].toString());
    if (path == null) return const ColoredBox(color: _ink);
    return Image.asset(
      path,
      cacheWidth: 1024,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          const ColoredBox(color: _ink),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.game,
    required this.area,
    required this.index,
    required this.locked,
    required this.selected,
    required this.onTap,
  });

  final UrsaGame game;
  final Map<String, dynamic> area;
  final int index;
  final bool locked;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final path = game.imageAssetPath(area['bg'].toString());
    return GestureDetector(
      onTap: locked ? null : onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? _gold : Colors.white24,
              width: selected ? 3 : 1,
            ),
            image: path == null
                ? null
                : DecorationImage(
                    // Thumbnails: decode small instead of the full 1536px art.
                    image: ResizeImage(AssetImage(path), width: 256),
                    fit: BoxFit.cover,
                  ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ColoredBox(color: _ink.withValues(alpha: locked ? 0.72 : 0.38)),
              if (locked)
                const Center(child: Icon(Icons.lock, color: _gold, size: 22)),
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        (index + 1).toString().padLeft(2, '0'),
                        style: const TextStyle(
                          color: _cream,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 0.9,
                        ),
                      ),
                      Text(
                        area['name'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xfff0ddae),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkinPreview extends StatelessWidget {
  const _SkinPreview({
    required this.game,
    required this.skin,
    required this.tint,
  });

  final UrsaGame game;
  final Map<String, dynamic> skin;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final sheets = skin['sheets'];
    final key = sheets is Map ? sheets['URSA_BIPED_CORE']?.toString() : null;
    if (key == null) {
      return Icon(Icons.pets, size: 58, color: tint);
    }
    final path = game.imageAssetPath(key);
    if (path == null) {
      return Icon(Icons.pets, size: 58, color: tint);
    }
    final columns = game.spriteColumns(key);
    final rows = game.spriteRows(key);
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox.expand(
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: <Widget>[
              Positioned(
                left: 0,
                top: 0,
                width: constraints.maxWidth * columns,
                height: constraints.maxHeight * rows,
                child: Image.asset(
                  path,
                  cacheWidth: 640,
                  fit: BoxFit.fill,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.pets, size: 58, color: tint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTab extends StatelessWidget {
  const _MenuTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xff79502f)
              : _ink.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _gold : Colors.white24),
        ),
        child: Text(
          label,
          style: const TextStyle(color: _cream, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xffa96835),
        foregroundColor: _cream,
        minimumSize: const Size(112, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _gold),
        ),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.game, required this.onMenu});

  final UrsaGame game;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(7, 5, 7, 0),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xee2d2b1e),
            border: Border(
              bottom: BorderSide(
                color: _gold.withValues(alpha: 0.45),
                width: 2,
              ),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: <Widget>[
              _HudButton(icon: Icons.menu, onPressed: onMenu),
              const SizedBox(width: 5),
              _HudButton(
                icon: game.volumePercent == 0
                    ? Icons.volume_off
                    : Icons.volume_down,
                onPressed: () => game.changeVolume(-1),
              ),
              SizedBox(
                width: 34,
                child: Text(
                  '${game.volumePercent}%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _cream,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _HudButton(
                icon: Icons.volume_up,
                onPressed: () => game.changeVolume(1),
              ),
              const SizedBox(width: 7),
              Icon(Icons.pets, color: _gold, size: 28),
              const SizedBox(width: 6),
              Flexible(
                fit: FlexFit.tight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${game.areaIndex + 1} · ${game.season}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _cream,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      game.mode == 'biped' ? 'BERDIRI' : 'MERANGKAK',
                      style: const TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List<Widget>.generate(
                  3,
                  (index) => Icon(
                    Icons.pets,
                    size: 15,
                    color: index < game.health ? _gold : Colors.white24,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _HudBadge(
                icon: Icons.monetization_on,
                label: '${game.totalFood}',
              ),
              if (!compact) ...<Widget>[
                const SizedBox(width: 5),
                _HudBadge(
                  icon: Icons.auto_awesome,
                  label: '${game.clawCount}/20',
                ),
              ],
              if (game.meterLabel.isNotEmpty) ...<Widget>[
                const SizedBox(width: 8),
                SizedBox(
                  width: compact ? 58 : 80,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        game.meterLabel,
                        style: const TextStyle(
                          color: _gold,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: (game.meterValue / 100).clamp(0, 1),
                          minHeight: 7,
                          backgroundColor: Colors.black45,
                          color: const Color(0xff78c3c5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HudButton extends StatelessWidget {
  const _HudButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 39,
      height: 39,
      child: IconButton.filledTonal(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          foregroundColor: _gold,
          backgroundColor: _ink.withValues(alpha: 0.6),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, size: 20),
      ),
    );
  }
}

class _HudBadge extends StatelessWidget {
  const _HudBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: _ink.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: _gold, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: _cream,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TouchControls extends StatelessWidget {
  const _TouchControls({required this.game});

  final UrsaGame game;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scale = (size.shortestSide / 390).clamp(0.75, 1.2);
    final buttonSize = 62 * scale;
    final gap = 6 * scale;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18 * scale, 0, 18 * scale, 14 * scale),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              _Joystick(game: game, size: 140 * scale),
              // Gamepad-style diamond: A (bottom), X (left), B (top-right).
              SizedBox(
                width: buttonSize * 2 + gap,
                height: buttonSize * 2 + gap,
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      right: 0,
                      top: 0,
                      child: _RoundButton(
                        game: game,
                        control: 'shift',
                        letter: 'B',
                        label: game.mode == 'biped' ? 'MERANGKAK' : 'BERDIRI',
                        color: const Color(0xff8a552f),
                        size: buttonSize,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: buttonSize * 0.5,
                      child: _RoundButton(
                        game: game,
                        control: 'action',
                        letter: 'X',
                        label: game.mode == 'biped'
                            ? 'CAKAR'
                            : game.areaIndex >= 8
                            ? 'ENDUS'
                            : 'TACKLE',
                        color: const Color(0xff6b3f3a),
                        size: buttonSize,
                      ),
                    ),
                    Positioned(
                      right: buttonSize * 0.25,
                      bottom: 0,
                      child: _RoundButton(
                        game: game,
                        control: 'jump',
                        letter: 'A',
                        label: 'LOMPAT',
                        color: const Color(0xff3f5a3a),
                        size: buttonSize,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Joystick extends StatefulWidget {
  const _Joystick({required this.game, required this.size});

  final UrsaGame game;
  final double size;

  @override
  State<_Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<_Joystick> {
  // Knob offset from centre, normalised to -1..1 on each axis.
  Offset _knob = Offset.zero;

  void _update(Offset local) {
    final radius = widget.size / 2;
    var delta = (local - Offset(radius, radius)) / radius;
    if (delta.distance > 1) delta = delta / delta.distance;
    setState(() => _knob = delta);
    widget.game.setControl('left', delta.dx < -0.3);
    widget.game.setControl('right', delta.dx > 0.3);
    widget.game.setControl('jump', delta.dy < -0.6);
  }

  void _releaseControls() {
    for (final control in const <String>['left', 'right', 'jump']) {
      widget.game.setControl(control, false);
    }
  }

  void _release() {
    setState(() => _knob = Offset.zero);
    _releaseControls();
  }

  @override
  void dispose() {
    _releaseControls();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final knobSize = size * 0.42;
    final travel = (size - knobSize) / 2;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (details) => _update(details.localPosition),
      onPanUpdate: (details) => _update(details.localPosition),
      onPanEnd: (_) => _release(),
      onPanCancel: _release,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _ink.withValues(alpha: 0.45),
                border: Border.all(
                  color: _gold.withValues(alpha: 0.55),
                  width: 2,
                ),
              ),
            ),
            Positioned(
              top: size * 0.06,
              child: Icon(Icons.keyboard_arrow_up,
                  color: _cream.withValues(alpha: 0.5), size: size * 0.16),
            ),
            Positioned(
              left: size * 0.04,
              child: Icon(Icons.keyboard_arrow_left,
                  color: _cream.withValues(alpha: 0.5), size: size * 0.16),
            ),
            Positioned(
              right: size * 0.04,
              child: Icon(Icons.keyboard_arrow_right,
                  color: _cream.withValues(alpha: 0.5), size: size * 0.16),
            ),
            Transform.translate(
              offset: _knob * travel,
              child: Container(
                width: knobSize,
                height: knobSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xff8a552f),
                  border: Border.all(color: _gold, width: 2),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x88000000),
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatefulWidget {
  const _RoundButton({
    required this.game,
    required this.control,
    required this.letter,
    required this.label,
    required this.color,
    required this.size,
  });

  final UrsaGame game;
  final String control;
  final String letter;
  final String label;
  final Color color;
  final double size;

  @override
  State<_RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<_RoundButton> {
  bool _down = false;

  void _set(bool down) {
    setState(() => _down = down);
    widget.game.setControl(widget.control, down);
  }

  @override
  void dispose() {
    if (_down) widget.game.setControl(widget.control, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.9 : 1,
        duration: const Duration(milliseconds: 60),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: _down ? 1 : 0.85),
            border: Border.all(color: _gold, width: 2),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x88000000),
                blurRadius: 5,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                widget.letter,
                style: TextStyle(
                  color: _cream,
                  fontSize: size * 0.32,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: size * 0.08),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      color: _cream,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 56,
      left: 20,
      right: 20,
      child: IgnorePointer(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xe626281c),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _gold.withValues(alpha: 0.45)),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _cream,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EndingOverlay extends StatelessWidget {
  const _EndingOverlay({required this.game});

  final UrsaGame game;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xdd081018),
      child: Center(
        child: Container(
          width: math.min(MediaQuery.sizeOf(context).width * 0.9, 420),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _gold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'SIKLUS LENGKAP',
                style: TextStyle(
                  color: _gold,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Dua tahun liar terlewati.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _cream,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${game.clawCount}/20 cap cakar · cadangan lemak ${game.fat.round()}%',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xffe3d6ad),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              _PrimaryButton(
                label: 'MULAI TAHUN BARU',
                onPressed: game.restartJourney,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _parseColor(String? value) {
  if (value == null) return _gold;
  final normalized = value.replaceFirst('#', '');
  final parsed = int.tryParse(normalized, radix: 16);
  return parsed == null ? _gold : Color(0xff000000 | parsed);
}

String _skinName(List<Map<String, dynamic>> skins, String id) {
  for (final skin in skins) {
    if (skin['id'] == id) return skin['name'].toString();
  }
  return 'Cokelat Hutan';
}
