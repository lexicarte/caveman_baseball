// The swing calibration screen and the clock the match reads.
//
// Two promises are locked in here. The shipped numbers do not move when a
// slider does — only a saved preset comes back next launch. And a tap is
// judged by that same clock, in the match and on the screen.
import 'dart:math';

import 'package:caveman_baseball/data/clubs.dart';
import 'package:caveman_baseball/data/items.dart';
import 'package:caveman_baseball/data/rocks.dart';
import 'package:caveman_baseball/data/starter_team.dart';
import 'package:caveman_baseball/game/caveman_baseball_game.dart';
import 'package:caveman_baseball/game/components/caveman.dart';
import 'package:caveman_baseball/game/components/caveman_cartoon.dart';
import 'package:caveman_baseball/game/ground.dart';
import 'package:caveman_baseball/game/match_controller.dart';
import 'package:caveman_baseball/game/sprites/field_figure.dart';
import 'package:caveman_baseball/game/sprites/sprite_strip.dart';
import 'package:caveman_baseball/game/swing_calibration_screen.dart';
import 'package:caveman_baseball/game/swing_preset.dart';
import 'package:caveman_baseball/game/swing_timing.dart';
import 'package:caveman_baseball/main.dart';
import 'package:caveman_baseball/model/loadout.dart';
import 'package:caveman_baseball/sim/game_rules.dart';
import 'package:caveman_baseball/sim/swing_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _until(WidgetTester t, Finder finder) async {
  for (var i = 0; i < 90; i++) {
    await t.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('never found $finder');
}

const _strip = SpriteStripSpec(
  cellW: 64,
  cellH: 64,
  frames: 6,
  durationsMs: [70, 70, 70, 70, 70, 70],
  pivotX: 32,
  pivotY: 63,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  tearDown(SwingTiming.reset);

  MatchController playing({Team? player, int seed = 1}) {
    final m = MatchController(
      playerTeam: player ?? StarterTeams.player(),
      opponent: StarterTeams.rookieOpponent(),
      rng: Random(seed),
    );
    expect(m.playerBatting, isTrue);
    m.commitSlot(0);
    expect(m.phase, PitchPhase.windUp);
    m.tick(5);
    expect(m.phase, PitchPhase.inFlight);
    expect(m.pitchElapsed, 0);
    return m;
  }

  group('the shipped swing is what the match already used', () {
    test('every dial starts at the live constant', () {
      final s = SwingTiming.shipped;
      expect(s.swingSeconds, CavemanPainter.swingSeconds);
      expect(s.swingSpeed, 1);
      expect(s.window, GameRules.timingWindow);
      expect(s.windowOffset, 0);
      expect(s.pitchFlightSeconds, GameRules.pitchFlightSeconds);
      expect(s.rockPitchSpeed, isEmpty);
      expect(s.whip, SwingCurve.shipped.whip);
      expect(s.whip, 0.30);
      expect(s.contactAt, SwingCurve.shipped.contactAt);
      expect(s.spriteContactFrame, 0.67);
      expect(s.spriteContactFrame, SwingCurve.shipped.contactAt);
      expect(s.approach, SwingCurve.shipped.approach);
      expect(s.follow, SwingCurve.shipped.follow);
      expect(s.windUpSeconds, GameRules.windUpSeconds);
      expect(s.slowPitchScale, GameRules.slowPitchScale);
      expect(s.slowWindowScale, shippedSlowWindowScale);
      expect(s.contactDepth, MatchController.contactDepth);
      expect(s.swingPlaySeconds, s.swingSeconds);
    });

    test('dragging a dial does not rewrite the shipped numbers', () {
      SwingTiming.now = SwingTiming.shipped.copyWith(
        window: 0.40,
        swingSeconds: 0.50,
        windowOffset: -0.04,
      );
      expect(GameRules.timingWindow, 0.150);
      expect(CavemanPainter.swingSeconds, 0.30);
      expect(SwingTiming.shipped.window, GameRules.timingWindow);
      expect(SwingTiming.shipped.swingSeconds, CavemanPainter.swingSeconds);
      expect(SwingTiming.now.window, 0.40);
    });
  });

  group('sprite contact frame', () {
    test('the shipped position samples the strip at swing time', () {
      final timing = SwingTiming.shipped;
      for (final t in [0.0, 0.30, 0.67, 0.9, 1.0]) {
        expect(timing.spritePhase(t), t);
        expect(
          stripPhaseFor(Pose.swing(t), _strip, 0),
          t,
          reason: 'a swing figure must use the timing config',
        );
      }
    });

    test('moving it puts the contact frame on screen at that moment', () {
      SwingTiming.now = SwingTiming.shipped.copyWith(spriteContactFrame: 0.30);
      expect(SwingTiming.now.spritePhase(0.30), closeTo(0.67, 1e-9));
      expect(SwingTiming.now.spritePhase(0), 0);
      expect(SwingTiming.now.spritePhase(1), closeTo(1, 1e-9));
      expect(
        stripPhaseFor(const Pose.swing(0.30), _strip, 0),
        closeTo(0.67, 1e-9),
      );
    });
  });

  group('pitch speed is per rock', () {
    test('an untouched rock keeps the base flight', () {
      final timing = SwingTiming.shipped.withRockSpeed(Rocks.heavy.id, 2);
      expect(
        timing.flightFor(Rocks.heavy.id, slow: false),
        closeTo(GameRules.pitchFlightSeconds / 2, 1e-9),
      );
      expect(
        timing.flightFor(Rocks.plain.id, slow: false),
        GameRules.pitchFlightSeconds,
      );
      expect(
        timing.flightFor(Rocks.plain.id, slow: true),
        closeTo(GameRules.pitchFlightSeconds * GameRules.slowPitchScale, 1e-9),
      );
    });

    test('the match flies the tuned rock and leaves the constants', () {
      SwingTiming.now = SwingTiming.shipped.copyWith(
        rockPitchSpeed: {for (final r in Rocks.all) r.id: 2.0},
      );
      final m = playing();
      expect(
        m.pitchFlightTime,
        closeTo(GameRules.pitchFlightSeconds / 2, 1e-9),
      );
      expect(GameRules.pitchFlightSeconds, 1.21);
    });
  });

  group('the match judges with the clock', () {
    test(
      'a tap at contact is on time and a hair outside the window misses',
      () {
        final m = playing();
        m.pitchElapsed = m.contactTime;
        m.swingNow();
        expect(m.swing!.timingError, closeTo(0, 1e-9));
        expect(m.swing!.verdict, SwingVerdict.contact);
        expect(m.swing!.quality, closeTo(1, 1e-9));

        final late = playing();
        late.pitchElapsed = late.contactTime + GameRules.timingWindow * 1.001;
        late.swingNow();
        expect(late.swing!.verdict, SwingVerdict.whiff);

        final inside = playing();
        inside.pitchElapsed =
            inside.contactTime + GameRules.timingWindow * 0.999;
        inside.swingNow();
        expect(inside.swing!.verdict, SwingVerdict.contact);
      },
    );

    test('a wider window connects a swing the shipped one misses', () {
      SwingTiming.now = SwingTiming.shipped.copyWith(window: 0.40);
      final m = playing();
      m.pitchElapsed = m.contactTime + 0.25;
      m.swingNow();
      expect(m.swing!.verdict, SwingVerdict.contact);
      expect(GameRules.timingWindow, 0.150);
    });

    test('the offset moves on-time without moving the shipped window', () {
      SwingTiming.now = SwingTiming.shipped.copyWith(windowOffset: -0.08);
      final m = playing();
      m.pitchElapsed = m.contactTime;
      m.swingNow();
      expect(m.swing!.timingError, closeTo(0.08, 1e-9));
      expect(
        m.swing!.timingError > 0,
        isTrue,
        reason: 'negative offset is late',
      );
    });

    test('the take deadline follows the window and the offset', () {
      final shipped = playing();
      shipped.pitchElapsed =
          shipped.contactTime + GameRules.timingWindow + 0.01;
      shipped.tick(0);
      expect(shipped.phase, PitchPhase.outcome);

      SwingTiming.now = SwingTiming.shipped.copyWith(windowOffset: 0.10);
      final later = playing();
      later.pitchElapsed = later.contactTime + GameRules.timingWindow + 0.01;
      later.tick(0);
      expect(later.phase, PitchPhase.inFlight);
    });

    test('a slow pitch uses the flight scale and the window scale', () {
      final player = StarterTeams.player();
      player.batting[0][0] = const ItemCard(Items.nokNoggin);
      final m = playing(player: player);
      expect(
        m.pitchFlightTime,
        closeTo(GameRules.pitchFlightSeconds * GameRules.slowPitchScale, 1e-9),
      );
      // 200ms is outside 150ms and inside 150ms * 1.35.
      m.pitchElapsed = m.contactTime + 0.20;
      m.swingNow();
      expect(m.swing!.verdict, SwingVerdict.contact);
    });

    test('contact depth moves the on-time instant and the drawn rock', () {
      SwingTiming.now = SwingTiming.shipped.copyWith(contactDepth: 1.5);
      final m = playing();
      expect(
        m.contactTime,
        closeTo(m.pitchFlightTime * (1 - 1.5 / m.throwerDepth), 1e-9),
      );
      final lift = CavemanBaseballGame.rockLift(1.5, m.throwerDepth);
      expect(
        Ground.y(1.5) - lift,
        closeTo(CavemanBaseballGame.batHeight, 1e-6),
        reason: 'the rock has to meet the bat at the tuned depth',
      );
    });

    test('swing speed shortens the bat without touching the painter', () {
      final game = CavemanBaseballGame(
        match: MatchController(
          playerTeam: StarterTeams.player(),
          opponent: StarterTeams.rookieOpponent(),
        ),
      );
      expect(game.liveSwingSeconds, CavemanBaseballGame.swingSeconds);
      SwingTiming.now = SwingTiming.shipped.copyWith(swingSpeed: 2);
      expect(
        game.liveSwingSeconds,
        closeTo(CavemanPainter.swingSeconds / 2, 1e-9),
      );
      expect(CavemanBaseballGame.swingSeconds, CavemanPainter.swingSeconds);
    });
  });

  group('judging a tap', () {
    test('early is negative, late is positive, and the edge is the window', () {
      final timing = SwingTiming.shipped;
      const contact = 1.0;
      final early = timing.judge(
        tapAt: contact - 0.04,
        contactTime: contact,
        club: Clubs.stik,
        rock: Rocks.plain,
      );
      expect(early.timingError, closeTo(-0.04, 1e-12));
      expect(early.earlyLateMs, -40);
      expect(early.hit, isTrue);
      expect(early.summary, contains('EARLY 40ms'));
      expect(early.summary, contains('HIT'));

      final miss = timing.judge(
        tapAt: contact + timing.window + 0.01,
        contactTime: contact,
        club: Clubs.stik,
        rock: Rocks.plain,
      );
      expect(miss.hit, isFalse);
      expect(miss.quality, 0);
      expect(miss.summary, contains('MISS'));
      expect(hitRateLabel(1, 4), 'hit rate 1/4 · 25%');
      expect(hitRateLabel(0, 0), 'hit rate 0/0');
    });
  });

  group('presets', () {
    test('round-trips through JSON and ignores a broken file', () async {
      final tuned = SwingTiming.shipped
          .copyWith(window: 0.22, windowOffset: 0.03, whip: 0.25)
          .withRockSpeed(Rocks.heavy.id, 1.4);
      final back = SwingTiming.fromJson(tuned.toJson());
      expect(back.window, closeTo(0.22, 1e-9));
      expect(back.windowOffset, closeTo(0.03, 1e-9));
      expect(back.whip, closeTo(0.25, 1e-9));
      expect(back.speedFor(Rocks.heavy.id), closeTo(1.4, 1e-9));
      expect(back.speedFor(Rocks.plain.id), 1);
      expect(back.swingSeconds, CavemanPainter.swingSeconds);

      SwingTiming.now = tuned;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(swingPresetKey, '{');
      await loadSwingPreset();
      expect(SwingTiming.now.window, SwingTiming.shipped.window);
      await prefs.remove(swingPresetKey);
    });

    test('save is what the next launch reads; reset clears it', () async {
      SwingTiming.now = SwingTiming.shipped.copyWith(window: 0.28);
      await saveSwingPreset();
      SwingTiming.reset();
      expect(SwingTiming.now.window, GameRules.timingWindow);
      await loadSwingPreset();
      expect(SwingTiming.now.window, closeTo(0.28, 1e-9));

      await clearSwingPreset();
      expect(SwingTiming.now.window, GameRules.timingWindow);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(swingPresetKey), isNull);
      await loadSwingPreset();
      expect(SwingTiming.now.window, GameRules.timingWindow);
    });

    test('nothing saved leaves the shipped swing', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(swingPresetKey);
      SwingTiming.now = SwingTiming.shipped.copyWith(window: 0.33);
      await loadSwingPreset();
      // No key: load returns without touching the clock. Startup calls
      // load when the clock is still shipped, which is the case that
      // must not invent a preset.
      SwingTiming.reset();
      await loadSwingPreset();
      expect(SwingTiming.now.whip, SwingCurve.shipped.whip);
      expect(SwingTiming.now.window, GameRules.timingWindow);
    });

    test('a wild preset is pinned back onto the dials', () {
      final pinned = SwingTiming.fromJson('{"window": 9, "swingSpeed": 0}');
      expect(pinned.window, SwingDials.window.max);
      expect(pinned.swingSpeed, SwingDials.swingSpeed.min);
    });
  });

  group('the lab is a debug and dev screen', () {
    test('release hides it unless the build was marked dev', () {
      expect(showSwingLab(debug: false, dev: false), isFalse);
      expect(showSwingLab(debug: true, dev: false), isTrue);
      expect(showSwingLab(debug: false, dev: true), isTrue);
      expect(swingLabAvailable, showSwingLab(debug: true, dev: false));
    });

    testWidgets('the match offers it, and a tap opens the loop', (t) async {
      await t.binding.setSurfaceSize(const Size(390, 844));
      await t.pumpWidget(const CavemanBaseballApp());
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('open-swing-lab')), findsOneWidget);

      await t.tap(find.byKey(const Key('open-swing-lab')));
      await t.pump();
      await _until(t, find.text('TAP TO SWING'));
      expect(find.text('swing duration'), findsOneWidget);
      expect(find.text('TAP TO SWING'), findsOneWidget);
      expect(t.takeException(), isNull);

      await t.pumpWidget(const SizedBox.shrink());
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('a swing reports early or late, hit or miss, and the rate', (
      t,
    ) async {
      SwingTiming.now = SwingTiming.shipped.copyWith(
        pitchGap: 0.15,
        windUpSeconds: 0.05,
      );
      await t.binding.setSurfaceSize(const Size(390, 844));
      await t.pumpWidget(const MaterialApp(home: SwingCalibrationScreen()));
      await _until(t, find.text('TAP TO SWING'));
      expect(find.text('TAP TO SWING'), findsOneWidget);
      expect(find.text('hit rate 0/0'), findsOneWidget);

      await t.tap(find.byKey(const Key('swing-lab-stage')));
      await t.pump();

      expect(find.textContaining('EARLY'), findsOneWidget);
      expect(find.textContaining('MISS'), findsOneWidget);
      expect(find.textContaining('quality'), findsOneWidget);
      expect(find.text('hit rate 0/1 · 0%'), findsOneWidget);
      expect(t.takeException(), isNull);

      await t.pumpWidget(const SizedBox.shrink());
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('dials apply immediately, and only save writes them down', (
      t,
    ) async {
      String? copiedText;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text'] as String?;
          } else if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': copiedText};
          }
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await t.binding.setSurfaceSize(const Size(390, 844));
      await t.pumpWidget(const MaterialApp(home: SwingCalibrationScreen()));
      await t.pump();

      Future<void> setDial(Key key, double value) async {
        // Drag the dial list until the row is built. ensureVisible can wait
        // forever here: the pitch ticker rebuilds every frame, so a scroll
        // animation never reports that it settled.
        final scrollable = find.descendant(
          of: find.byKey(const Key('swing-dials')),
          matching: find.byType(Scrollable),
        );
        for (var i = 0; i < 12 && find.byKey(key).evaluate().isEmpty; i++) {
          await t.drag(scrollable, const Offset(0, -160));
          await t.pump();
        }
        expect(find.byKey(key), findsOneWidget);
        final slider = t.widget<Slider>(
          find.descendant(of: find.byKey(key), matching: find.byType(Slider)),
        );
        slider.onChanged!(value);
        await t.pump();
      }

      await setDial(const Key('window'), 0.40);
      expect(SwingTiming.now.window, closeTo(0.40, 1e-9));
      expect(GameRules.timingWindow, 0.150);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(swingPresetKey), isNull);

      // Chips sit above the dial list. Pitch speed is above sprite contact,
      // and the list only reveals what is further down, so edit top to bottom.
      await t.tap(find.text('FAT ROK'));
      await t.pump();
      await setDial(const Key('pitch-speed'), 1.8);
      expect(SwingTiming.now.speedFor(Rocks.heavy.id), closeTo(1.8, 1e-9));
      expect(SwingTiming.now.speedFor(Rocks.plain.id), 1);

      await setDial(const Key('sprite-contact'), 0.30);
      expect(SwingTiming.now.spriteContactFrame, closeTo(0.30, 1e-9));

      await t.tap(find.text('SAVE'));
      await t.pump();
      await t.pump();
      expect(find.text('saved'), findsOneWidget);
      expect(prefs.getString(swingPresetKey), contains('"window"'));

      await t.tap(find.text('COPY'));
      await t.pump();
      final copied = await Clipboard.getData(Clipboard.kTextPlain);
      expect(copied?.text, contains('"spriteContactFrame"'));
      expect(copied?.text, contains('"whip"'));
      expect(copied?.text, contains('heavy'));

      await t.tap(find.text('RESET'));
      await t.pump();
      await t.pump();
      expect(SwingTiming.now.window, GameRules.timingWindow);
      expect(SwingTiming.now.spriteContactFrame, SwingCurve.shipped.contactAt);
      expect(SwingTiming.now.rockPitchSpeed, isEmpty);
      expect(prefs.getString(swingPresetKey), isNull);
      expect(find.text('shipped swing'), findsOneWidget);
      expect(find.text('hit rate 0/0'), findsOneWidget);

      await t.pumpWidget(const SizedBox.shrink());
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('every timing dial is on the screen', (t) async {
      await t.binding.setSurfaceSize(const Size(390, 844));
      await t.pumpWidget(const MaterialApp(home: SwingCalibrationScreen()));
      await t.pump();
      const labels = [
        'swing duration',
        'swing speed',
        'window',
        'window offset',
        'pitch speed',
        'pitch flight',
        'pitch gap',
        'sprite contact',
        'whip',
        'arc contact',
        'approach',
        'follow',
        'wind-up',
        'slow pitch',
        'slow window',
        'contact depth',
      ];
      final scrollable = find.descendant(
        of: find.byKey(const Key('swing-dials')),
        matching: find.byType(Scrollable),
      );
      for (final label in labels) {
        for (var i = 0; i < 16 && find.text(label).evaluate().isEmpty; i++) {
          await t.drag(scrollable, const Offset(0, -140));
          await t.pump();
        }
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('RESET'), findsOneWidget);
      expect(find.text('SAVE'), findsOneWidget);
      expect(find.text('COPY'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.binding.setSurfaceSize(null);
    });
  });
}
