// The tuning bench.
//
//   flutter run -t lib/main_calibrate.dart
//
// Three screens, because there are three separable problems and putting
// them on one page meant every change looked like it had broken the other
// two:
//
//   UI      the whole screen, at any camera between fielding and batting,
//           with every distance on the field on a slider. Saved.
//   SWING   the batter close up. How the bat moves and how long it takes.
//   PITCH   when the swing has to happen, and what a mis-timed one does.
//
// Only the UI tab's values persist, because only those are the LOOK. The
// swing and pitch numbers are still live game rules, and making them
// quietly overridable on one device is how you end up tuning against a
// game nobody else is playing.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bench/chrome.dart';
import 'bench/field_tab.dart';
import 'bench/pitch_tab.dart';
import 'bench/swing_tab.dart';
import 'game/components/caveman.dart';
import 'game/components/caveman_cartoon.dart';
import 'game/look.dart';
import 'sim/game_rules.dart';

/// Where the saved look lives on the device.
const _lookKey = 'look.v1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadLook();
  runApp(const BenchApp());
}

Future<void> _loadLook() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lookKey);
    if (raw == null) return;
    Look.now.applyMap(Map<String, dynamic>.from(jsonDecode(raw) as Map));
  } catch (_) {
    // A bench that refuses to start because a saved value went bad is
    // worse than a bench that starts at the shipped ones.
  }
}

class BenchApp extends StatelessWidget {
  const BenchApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Caveman Baseball bench',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(
      useMaterial3: true,
    ).copyWith(scaffoldBackgroundColor: benchBg),
    home: const _Bench(),
  );
}

class _Bench extends StatefulWidget {
  const _Bench();

  @override
  State<_Bench> createState() => _BenchState();
}

class _BenchState extends State<_Bench> {
  // Swing and pitch levers live up here so the two benches that use them
  // read the same numbers.
  double swingSeconds = CavemanPainter.swingSeconds;
  SwingCurve curve = SwingCurve.shipped;
  double window = GameRules.timingWindow;
  double pitch = GameRules.pitchFlightSeconds;
  double slowScale = GameRules.slowPitchScale;

  String saveNote = '';

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lookKey, Look.now.toJson());
      setState(() => saveNote = 'saved');
    } catch (e) {
      setState(() => saveNote = 'save failed');
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(
              height: 36,
              child: TabBar(
                labelColor: benchAccent,
                unselectedLabelColor: benchDim,
                indicatorColor: benchAccent,
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
                tabs: [
                  Tab(text: 'UI'),
                  Tab(text: 'SWING'),
                  Tab(text: 'PITCH'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  FieldTab(onSave: _save, saveNote: saveNote),
                  SwingTab(
                    seconds: swingSeconds,
                    curve: curve,
                    onChanged: ({double? seconds, SwingCurve? curve}) =>
                        setState(() {
                          swingSeconds = seconds ?? swingSeconds;
                          this.curve = curve ?? this.curve;
                        }),
                  ),
                  PitchTab(
                    swingSeconds: swingSeconds,
                    curve: curve,
                    window: window,
                    pitch: pitch,
                    slowScale: slowScale,
                    onChanged:
                        ({
                          double? window,
                          double? pitch,
                          double? slowScale,
                        }) => setState(() {
                          this.window = window ?? this.window;
                          this.pitch = pitch ?? this.pitch;
                          this.slowScale = slowScale ?? this.slowScale;
                        }),
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
