// Entry point. Locks to portrait and routes taps into the game.
//
// Input is captured at the Flutter layer rather than inside Flame so there is
// exactly one place a tap can enter the game.
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/starter_team.dart';
import 'game/caveman_baseball_game.dart';
import 'game/hud/match_hud.dart';
import 'game/match_controller.dart';
import 'game/swing_preset.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A saved swing preset, if there is one. No preset leaves the shipped
  // timing alone.
  await loadSwingPreset();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const CavemanBaseballApp());
}

class CavemanBaseballApp extends StatefulWidget {
  const CavemanBaseballApp({super.key});

  @override
  State<CavemanBaseballApp> createState() => _CavemanBaseballAppState();
}

class _CavemanBaseballAppState extends State<CavemanBaseballApp> {
  late final CavemanBaseballGame _game = CavemanBaseballGame(
    match: MatchController(
      playerTeam: StarterTeams.player(),
      opponent: StarterTeams.rookieOpponent(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caveman Baseball',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1B2419),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) =>
              _game.handleTapAt(d.localPosition.dx, d.localPosition.dy),
          child: Stack(
            children: [
              GameWidget(game: _game),
              MatchHud(game: _game),
              // The playing view is a band between the scoreboard and the
              // cards. The HUD's own bands are opaque, but they sit inside
              // the safe area, so without these the field shows through
              // behind the status bar and the home indicator and the crop
              // looks like a bug.
              _InsetCap(
                height: MediaQuery.of(context).padding.top,
                alignment: Alignment.topCenter,
              ),
              _InsetCap(
                height: MediaQuery.of(context).padding.bottom,
                alignment: Alignment.bottomCenter,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An opaque strip over a system inset, so the cropped playing view does
/// not leak out past the scoreboard or the cards.
class _InsetCap extends StatelessWidget {
  const _InsetCap({required this.height, required this.alignment});

  final double height;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (height <= 0) return const SizedBox.shrink();
    return Align(
      alignment: alignment,
      child: Container(
        height: height,
        width: double.infinity,
        color: const Color(0xFF161210),
      ),
    );
  }
}
