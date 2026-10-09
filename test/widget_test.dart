import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panda/game/ursa_game.dart';
import 'package:panda/main.dart';

void main() {
  test('bundled URSA level and image manifests are complete', () async {
    final gameData =
        jsonDecode(await rootBundle.loadString('assets/json/game_data.json'))
            as Map<String, dynamic>;
    final imageManifest =
        jsonDecode(
              await rootBundle.loadString('assets/json/asset_manifest.json'),
            )
            as Map<String, dynamic>;

    expect(gameData['areas'], hasLength(20));
    expect(gameData['sheetKeys'], hasLength(64));
    expect(imageManifest, hasLength(84));
    await rootBundle.load('assets/images/bg_area_01.webp');
    await rootBundle.load('assets/images/ursa_biped_core-transparent.webp');
    expect(
      (await rootBundle.load('assets/audio/jump.mp3')).lengthInBytes,
      greaterThan(0),
    );
    expect(
      (await rootBundle.load('assets/audio/bgm.mp3')).lengthInBytes,
      greaterThan(0),
    );
  });

  testWidgets('URSA opens every area and restarts after three hits', (
    tester,
  ) async {
    await tester.pumpWidget(const UrsaApp(audioEnabled: false));

    expect(find.text('MENYIAPKAN JEJAK MUSIM…'), findsOneWidget);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 3)),
    );
    await tester.pump();
    expect(find.text('20 AREA · 3 SKIN · 3 KESEMPATAN'), findsOneWidget);

    final game = tester
        .widget<GameWidget<UrsaGame>>(find.byType(GameWidget<UrsaGame>))
        .game!;
    expect(game.highestUnlockedArea, 19);

    game.startArea(1, 'brown');
    expect(game.areaIndex, 1);
    expect(game.started, isTrue);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 8)),
    );
    await tester.pump();
    expect(game.loading, isFalse);
    expect(game.areaIndex, 1);

    game.health = 1;
    game.playerY = 761;
    game.velocityY = 0;
    game.update(0.016);
    expect(game.health, 3);
    expect(game.completed, isTrue);
    expect(game.areaIndex, 1);

    game.transitionTimer = 0.016;
    game.update(0.016);
    expect(game.areaIndex, 1);
    expect(game.loading, isTrue);
  });
}
