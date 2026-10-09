import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'ursa_game.dart';

class FrameViewerPage extends StatefulWidget {
  const FrameViewerPage({super.key});

  @override
  State<FrameViewerPage> createState() => _FrameViewerPageState();
}

class _FrameViewerPageState extends State<FrameViewerPage> {
  final UrsaGame _game = UrsaGame(audioEnabled: false, frameViewer: true);

  @override
  void dispose() {
    _game.revision.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff182219),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _game.viewerNextSkin,
        child: GameWidget(game: _game),
      ),
    );
  }
}
