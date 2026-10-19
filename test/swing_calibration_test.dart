// The swing calibration screen and the clock the match reads.
//
// Two promises are locked in here. The shipped numbers do not move when a
// slider does — only a saved preset comes back next launch. And a tap is
// judged by that same clock in the match. The lab plays the clock back.
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
import 'package:caveman_baseball/game/look.dart';
import 'package:caveman_baseball/game/pitch_test.dart';
import 'package:caveman_baseball/game/swing_calibration_screen.dart';
import 'package:caveman_baseball/game/swing_preset.dart';
import 'package:caveman_baseball/game/swing_timing.dart';
import 'package:caveman_baseball/sim/fielder_spec.dart';
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
      expect(s.earliestHit, SwingTiming.shippedEarliestHit);
      expect(s.fairEarly, SwingTiming.shippedFairEarly);
      expect(s.centreHit, s.whip);
      expect(s.fairLate, SwingTiming.shippedFairLate);
      expect(s.latestHit, SwingTiming.shippedLatestHit);
      expect(s.pitcherScale, 1);
      expect(s.batterScale, 1);
      expect(s.scaleFor(), 1);
      expect(s.scaleFor(pitcher: true), 1);
      expect(s.scaleFor(batter: true), 1);
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
      final pinned = SwingTiming.fromJson(
        '{"window": 9, "swingSpeed": 0, "earliestHit": 4, "pitcherScale": 0}',
      );
      expect(pinned.window, SwingDials.window.max);
      expect(pinned.swingSpeed, SwingDials.swingSpeed.min);
      expect(pinned.earliestHit, SwingDials.hitPhase.max);
      expect(pinned.pitcherScale, SwingDials.spriteScale.min);
    });

    test('new marks survive a round trip and old files keep them shipped', () {
      final tuned = SwingTiming.shipped.copyWith(
        earliestHit: 0.18,
        fairEarly: 0.27,
        centreHit: 0.40,
        fairLate: 0.55,
        latestHit: 0.70,
        pitcherScale: 1.25,
        batterScale: 0.8,
      );
      final back = SwingTiming.fromJson(tuned.toJson());
      expect(back.earliestHit, closeTo(0.18, 1e-9));
      expect(back.fairEarly, closeTo(0.27, 1e-9));
      expect(back.centreHit, closeTo(0.40, 1e-9));
      expect(back.fairLate, closeTo(0.55, 1e-9));
      expect(back.latestHit, closeTo(0.70, 1e-9));
      expect(back.pitcherScale, closeTo(1.25, 1e-9));
      expect(back.batterScale, closeTo(0.8, 1e-9));
      expect(back.scaleFor(pitcher: true), closeTo(1.25, 1e-9));
      expect(back.scaleFor(batter: true), closeTo(0.8, 1e-9));

      final legacy = SwingTiming.fromJson('{"window": 0.22, "whip": 0.25}');
      expect(legacy.window, closeTo(0.22, 1e-9));
      expect(legacy.whip, closeTo(0.25, 1e-9));
      expect(legacy.earliestHit, SwingTiming.shippedEarliestHit);
      expect(legacy.centreHit, SwingTiming.shipped.whip);
      expect(legacy.pitcherScale, 1);
      expect(legacy.batterScale, 1);
    });

    test('save writes the new marks and reset clears them', () async {
      SwingTiming.now = SwingTiming.shipped.copyWith(
        batterScale: 1.4,
        fairLate: 0.5,
      );
      await saveSwingPreset();
      SwingTiming.reset();
      await loadSwingPreset();
      expect(SwingTiming.now.batterScale, closeTo(1.4, 1e-9));
      expect(SwingTiming.now.fairLate, closeTo(0.5, 1e-9));
      await clearSwingPreset();
      expect(SwingTiming.now.batterScale, 1);
      expect(SwingTiming.now.fairLate, SwingTiming.shippedFairLate);
    });
  });

  group('the five pitch-test swings', () {
    const foul = LookDefaults.foulAngleDegrees;

    test('they play in order and then stop, and idle does not pitch', () {
      final timing = SwingTiming.shipped.copyWith(
        windUpSeconds: 0.05,
        pitchFlightSeconds: 0.30,
        pitchGap: 0.05,
        swingSeconds: 0.20,
      );
      final seq = PitchSequence();
      seq.tick(2, timing, mound: 11);
      expect(seq.running, isFalse);

      seq.go();
      final seen = <PitchShot>[];
      for (var i = 0; i < 4000 && seq.running; i++) {
        final shot = seq.shot!;
        if (seen.isEmpty || seen.last != shot) seen.add(shot);
        seq.tick(0.02, timing, mound: 11);
      }
      expect(seen, PitchShot.values);
      expect(seen, [
        PitchShot.earliestFoul,
        PitchShot.latestFoul,
        PitchShot.centre,
        PitchShot.fairThird,
        PitchShot.fairFirst,
      ]);
      expect(seq.running, isFalse);
    });

    test('the bat is at the calibrated phase when the rock arrives', () {
      final timing = SwingTiming.shipped.copyWith(
        earliestHit: 0.2,
        latestHit: 0.8,
        fairEarly: 0.33,
        fairLate: 0.6,
        centreHit: 0.45,
      );
      const mound = 11.273;
      for (final shot in PitchShot.values) {
        final clock = ShotClock(timing: timing, shot: shot, mound: mound);
        expect(
          clock.swingPhase(clock.contact),
          closeTo(phaseOf(shot, timing), 1e-9),
          reason: shot.label,
        );
      }
    });

    test('directions are foul left, foul right, centre, and the two lines', () {
      final shots = PitchShots();
      final early = shots[PitchShot.earliestFoul];
      final late = shots[PitchShot.latestFoul];
      final centre = shots[PitchShot.centre];
      final third = shots[PitchShot.fairThird];
      final first = shots[PitchShot.fairFirst];

      expect(early.swing.sprayDegrees, lessThan(-foul));
      expect(early.foul, isTrue);
      expect(late.swing.sprayDegrees, greaterThan(foul));
      expect(late.foul, isTrue);

      expect(centre.swing.sprayDegrees, closeTo(0, 1e-9));
      expect(centre.foul, isFalse);
      expect(centre.angleDegrees.abs(), lessThan(8));

      expect(third.swing.sprayDegrees, closeTo(-foul, 1e-6));
      expect(third.foul, isFalse);
      expect(first.swing.sprayDegrees, closeTo(foul, 1e-6));
      expect(first.foul, isFalse);
    });

    test('the pitch-test camera keeps both men on a phone stage', () {
      // The stage is the top half of the lab, not the whole phone.
      const width = 390.0;
      const height = 280.0;
      final span = stageWorldSpan(
        width: width,
        height: height,
        zoom: pitchTestZoom,
        look: pitchTestLook,
      );
      final mound = Schemes.wheel.thrower.depth;
      final pitcher = steadyManExtent(
        fieldY: mound,
        zoom: pitchTestZoom,
        scale: 1,
      );
      final batter = steadyManExtent(
        fieldY: CavemanBaseballGame.batterY,
        zoom: pitchTestZoom,
        scale: 1,
      );
      expect(pitcher.head, greaterThan(span.top));
      expect(pitcher.feet, lessThan(span.bottom));
      expect(batter.head, greaterThan(span.top));
      expect(batter.feet, lessThan(span.bottom));
      expect(pitchTestZoom, greaterThan(Ground.tightZoom));
      expect(pitchTestLook, greaterThan(Ground.tightLook));
    });
  });

  group('the lab is a debug and dev screen', () {
    test('release hides it unless the build was marked dev', () {
      expect(showSwingLab(debug: false, dev: false), isFalse);
      expect(showSwingLab(debug: true, dev: false), isTrue);
      expect(showSwingLab(debug: false, dev: true), isTrue);
      expect(swingLabAvailable, showSwingLab(debug: true, dev: false));
    });

    testWidgets('the match offers it, and a tap opens the pitch test', (
      t,
    ) async {
      await t.binding.setSurfaceSize(const Size(390, 844));
      await t.pumpWidget(const CavemanBaseballApp());
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('open-swing-lab')), findsOneWidget);

      await t.tap(find.byKey(const Key('open-swing-lab')));
      await t.pump();
      await _until(t, find.byKey(const Key('pitch-test-go')));
      expect(find.text('PITCH TEST'), findsOneWidget);
      expect(find.text('GO plays five pitches'), findsOneWidget);
      expect(find.text('earliest hit'), findsOneWidget);
      expect(find.text('TAP TO SWING'), findsNothing);
      expect(t.takeException(), isNull);

      await t.pumpWidget(const SizedBox.shrink());
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('GO starts the sequence and does not pitch before that', (
      t,
    ) async {
      SwingTiming.now = SwingTiming.shipped.copyWith(
        pitchGap: 0.05,
        windUpSeconds: 0.05,
        pitchFlightSeconds: 0.25,
        swingSeconds: 0.16,
      );
      await t.binding.setSurfaceSize(const Size(390, 844));
      await t.pumpWidget(const MaterialApp(home: SwingCalibrationScreen()));
      await t.pump();
      expect(find.text('GO plays five pitches'), findsOneWidget);
      expect(find.textContaining('1/5'), findsNothing);

      await t.tap(find.byKey(const Key('pitch-test-go')));
      await t.pump();
      final status = t.widget<Text>(find.byKey(const Key('pitch-test-status')));
      expect(status.data, contains('1/5'));
      expect(status.data, contains('foul left'));
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

      Future<void> setDial(Key list, Key key, double value) async {
        // Drag the dial list until the row is built. ensureVisible can wait
        // forever here: a playing sequence rebuilds every frame, so a scroll
        // animation never reports that it settled.
        final scrollable = find.descendant(
          of: find.byKey(list),
          matching: find.byType(Scrollable),
        );
        for (var i = 0; i < 16 && find.byKey(key).evaluate().isEmpty; i++) {
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

      await setDial(const Key('pitch-dials'), const Key('earliest-hit'), 0.2);
      expect(SwingTiming.now.earliestHit, closeTo(0.2, 1e-9));
      await setDial(const Key('pitch-dials'), const Key('pitcher-size'), 1.3);
      expect(SwingTiming.now.pitcherScale, closeTo(1.3, 1e-9));
      await setDial(
        const Key('pitch-dials'),
        const Key('pitch-speed-heavy'),
        1.8,
      );
      expect(SwingTiming.now.speedFor(Rocks.heavy.id), closeTo(1.8, 1e-9));
      expect(SwingTiming.now.speedFor(Rocks.plain.id), 1);
      expect(GameRules.timingWindow, 0.150);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(swingPresetKey), isNull);

      await t.tap(find.byKey(const Key('mode-bat')));
      await t.pump();
      await setDial(const Key('swing-dials'), const Key('window'), 0.40);
      expect(SwingTiming.now.window, closeTo(0.40, 1e-9));
      await setDial(
        const Key('swing-dials'),
        const Key('sprite-contact'),
        0.30,
      );
      expect(SwingTiming.now.spriteContactFrame, closeTo(0.30, 1e-9));

      await t.tap(find.text('SAVE CALIBRATION'));
      await t.pump();
      await t.pump();
      expect(find.text('saved'), findsOneWidget);
      expect(prefs.getString(swingPresetKey), contains('"window"'));
      expect(prefs.getString(swingPresetKey), contains('"earliestHit"'));
      expect(prefs.getString(swingPresetKey), contains('"pitcherScale"'));

      await t.tap(find.text('COPY'));
      await t.pump();
      final copied = await Clipboard.getData(Clipboard.kTextPlain);
      expect(copied?.text, contains('"spriteContactFrame"'));
      expect(copied?.text, contains('"whip"'));
      expect(copied?.text, contains('"batterScale"'));
      expect(copied?.text, contains('heavy'));

      await t.tap(find.text('RESET'));
      await t.pump();
      await t.pump();
      expect(SwingTiming.now.window, GameRules.timingWindow);
      expect(SwingTiming.now.spriteContactFrame, SwingCurve.shipped.contactAt);
      expect(SwingTiming.now.earliestHit, SwingTiming.shippedEarliestHit);
      expect(SwingTiming.now.pitcherScale, 1);
      expect(SwingTiming.now.rockPitchSpeed, isEmpty);
      expect(prefs.getString(swingPresetKey), isNull);
      expect(find.text('shipped swing'), findsOneWidget);

      await t.pumpWidget(const SizedBox.shrink());
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('every timing dial is on the screen', (t) async {
      await t.binding.setSurfaceSize(const Size(390, 844));
      await t.pumpWidget(const MaterialApp(home: SwingCalibrationScreen()));
      await t.pump();

      Future<void> expectLabels(Key list, List<String> labels) async {
        final scrollable = find.descendant(
          of: find.byKey(list),
          matching: find.byType(Scrollable),
        );
        for (final label in labels) {
          for (var i = 0; i < 20 && find.text(label).evaluate().isEmpty; i++) {
            await t.drag(scrollable, const Offset(0, -140));
            await t.pump();
          }
          expect(find.text(label), findsOneWidget, reason: label);
        }
      }

      await expectLabels(const Key('pitch-dials'), [
        'earliest hit',
        'latest hit',
        'fair, 3rd line',
        'fair, 1st line',
        'centre hit',
        'pitcher size',
        'batter size',
        for (final rock in Rocks.all) rock.name,
      ]);

      await t.tap(find.byKey(const Key('mode-bat')));
      await t.pump();
      expect(find.byKey(const Key('bat-swing')), findsOneWidget);
      expect(find.text('SWING plays the bat'), findsOneWidget);
      await expectLabels(const Key('swing-dials'), const [
        'swing duration',
        'swing speed',
        'window',
        'window offset',
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
      ]);
      expect(find.text('RESET'), findsOneWidget);
      expect(find.text('SAVE CALIBRATION'), findsOneWidget);
      expect(find.text('COPY'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.binding.setSurfaceSize(null);
    });
  });
}
