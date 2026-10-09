import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/frame_viewer_page.dart';
import 'game/ursa_page.dart';

// Debug switch: true = show only the bear's animation frames, false = the game.
const bool kFrameViewer = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const UrsaApp());
}

class UrsaApp extends StatelessWidget {
  const UrsaApp({super.key, this.audioEnabled = true});

  final bool audioEnabled;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pijak Pijak Cakar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff8a623e),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: kFrameViewer
          ? const FrameViewerPage()
          : UrsaPage(audioEnabled: audioEnabled),
    );
  }
}
