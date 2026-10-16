// The calibration model has to agree with the game, or the chart is a
// confident picture of something that is not happening.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caveman_baseball/data/clubs.dart';
import 'package:caveman_baseball/game/calibration.dart';
import 'package:caveman_baseball/game/caveman_baseball_game.dart';
import 'package:caveman_baseball/game/ground.dart';
import 'package:caveman_baseball/game/look.dart';
import 'package:caveman_baseball/sim/base_running.dart';
import 'package:caveman_baseball/sim/field_spec.dart';
import 'package:caveman_baseball/main_calibrate.dart';
import 'package:caveman_baseball/sim/fielder_spec.dart';
import 'package:caveman_baseball/sim/game_rules.dart';

void main() {
  const c = Calibration();

  test('it reads the live constants, not a copy of them', () {
    expect(c.flightSeconds, GameRules.pitchFlightSeconds);
    expect(c.batterX, CavemanBaseballGame.batterX);
    expect(c.batterY, CavemanBaseballGame.batterY);
    expect(c.handDrop, CavemanBaseballGame.handDrop);
    expect(c.throwerDepth, Schemes.line.thrower.depth);
  });

  test('its rock path matches the one the game draws', () {
    for (final depth in [10.0, 7.0, 4.0, 1.0, 0.0]) {
      final t = c.flightSeconds * (1 - depth / c.throwerDepth);
      final lift = CavemanBaseballGame.rockLift(depth, c.throwerDepth);
      final mine = c.rockAt(t);
      expect(
        mine.dy,
        closeTo(Ground.y(depth) - lift, 1e-6),
        reason: 'chart and game disagree about the rock at depth $depth',
      );
    }
  });

  test('its bat height matches the game', () {
    expect(c.batHeight, closeTo(CavemanBaseballGame.batHeight, 1e-9));
  });

  test('as shipped, the rock crosses the bat on time', () {
    final cross = c.crossing();
    expect(cross, isNotNull, reason: 'the rock never reaches the bat at all');
    final tightest = Clubs.all
        .map((x) => GameRules.timingWindow)
        .reduce((a, b) => a < b ? a : b);
    expect(
      cross!.errorMs.abs(),
      lessThan(tightest * 1000 * 0.25),
      reason:
          'crossing is ${cross.errorMs.toStringAsFixed(0)}ms off the '
          'scoring instant; the tightest window is '
          '+/-${(tightest * 1000).round()}ms',
    );
  });

  test('the club actually reaches across to the rock', () {
    // A swing that is perfectly timed but a pace short connects with air.
    expect(
      c.gapAtContact(),
      lessThan(1.2),
      reason:
          'the club tip never gets within '
          '${c.gapAtContact().toStringAsFixed(2)} units of the rock',
    );
  });

  test('moving the batter cannot break the crossing', () {
    // Worth stating: the rock's trajectory is DERIVED from the batter, so
    // the two move together and no batter position can pull them apart.
    // That is the property the fix bought.
    for (final y in [-0.5, 0.0, 0.15, 1.2, 2.5]) {
      final cross = c.copyWith(batterY: y).crossing();
      expect(cross, isNotNull, reason: 'batterY $y');
      expect(cross!.errorMs.abs(), lessThan(5), reason: 'batterY $y');
    }
  });

  test('it catches a trajectory that does not track the batter', () {
    // The real bug: a hard-coded lift, independent of where the bat is.
    // 2.8 at the hand and 0.8 at the plate were the shipped values. They
    // put the rock at the ankles and cost 214ms, later ~118ms after the
    // pitch sped up. At 48pt the bat has risen to about that same plate
    // height, so those two numbers are only ~10ms off and no longer the
    // miss. Aiming the arrival at the feet, still without consulting the
    // hands, is the same kind of trajectory.
    final atFeet = Ground.y(c.contactDepth) - Ground.y(c.batterY);
    final bad = c.copyWith(liftRelease: 2.8, liftPlate: atFeet);
    final cross = bad.crossing();

    // It has to cross. A null result would also be returned by an
    // instrument that never looks, and that is not a catch.
    expect(
      cross,
      isNotNull,
      reason: 'an ankle-high rock still passes the bat on the way down',
    );
    expect(
      cross!.errorMs.abs(),
      greaterThan(100),
      reason:
          'the instrument must report the bug it was built for, got '
          '${cross.errorMs.toStringAsFixed(0)}ms',
    );
  });

  group('the three swings', () {
    test('early pulls left, centre goes up the middle, late pushes right', () {
      // The whole game rests on this. A right-hander who is early pulls to
      // left field (negative x); late pushes to right. If the two extremes
      // did not separate there would be no aiming and no reason to choose
      // a club.
      for (final club in Clubs.all) {
        final cal = Calibration(club: club);
        final early = cal.outcomeFor(ContactCase.early);
        final centre = cal.outcomeFor(ContactCase.centre);
        final late = cal.outcomeFor(ContactCase.late);
        expect(early.angleDegrees, lessThan(-5), reason: club.name);
        expect(centre.angleDegrees.abs(), lessThan(1), reason: club.name);
        expect(late.angleDegrees, greaterThan(5), reason: club.name);
      }
    });

    test('a centred swing is the longest one', () {
      for (final club in Clubs.all) {
        final cal = Calibration(club: club);
        final centre = cal.outcomeFor(ContactCase.centre);
        for (final k in [ContactCase.early, ContactCase.late]) {
          expect(
            cal.outcomeFor(k).distance,
            lessThan(centre.distance),
            reason: '${club.name} ${k.label} travels no shorter than centre',
          );
        }
      }
    });

    test('the extremes mirror each other', () {
      for (final club in Clubs.all) {
        final cal = Calibration(club: club);
        final early = cal.outcomeFor(ContactCase.early);
        final late = cal.outcomeFor(ContactCase.late);
        expect(
          early.distance,
          closeTo(late.distance, 0.5),
          reason: '${club.name} is lopsided',
        );
        expect(
          early.angleDegrees,
          closeTo(-late.angleDegrees, 1.0),
          reason: '${club.name} sprays unevenly',
        );
      }
    });

    test('nothing is simulated with the dice in', () {
      // Same picture every time you look at it, or the bench is telling
      // you about its random number generator.
      final cal = Calibration(club: Clubs.kwik);
      for (var i = 0; i < 5; i++) {
        expect(
          cal.outcomeFor(ContactCase.early).distance,
          closeTo(cal.outcomeFor(ContactCase.early).distance, 1e-9),
        );
      }
    });
  });

  group('the replay is shot on the game camera', () {
    final clip = PlayClip(c, c.outcomeFor(ContactCase.centre), Schemes.line);

    test('it holds tight for the whole at-bat', () {
      for (final t in [0.0, 0.4, 0.9, clip.contactMoment - 0.01]) {
        final cam = clip.cameraAt(t);
        expect(cam.zoom, CavemanBaseballGame.tightZoom, reason: 't=$t');
        expect(cam.look, CavemanBaseballGame.tightLook, reason: 't=$t');
      }
    });

    test('it eases out once the rock is struck, and never snaps', () {
      final at = [
        for (final d in [0.0, 0.1, 0.3, 0.6, 1.2, 2.5])
          clip.cameraAt(clip.contactMoment + d).zoom,
      ];
      for (var i = 1; i < at.length; i++) {
        expect(at[i], lessThan(at[i - 1]), reason: 'zoom must keep opening');
      }
      // A third of a second in it should be well on its way, and a couple
      // of seconds later effectively wide.
      expect(at[2], lessThan(CavemanBaseballGame.tightZoom * 0.8));
      expect(at.last, closeTo(CavemanBaseballGame.wideZoom, 0.05));
    });

    test('scrubbing lands on the same frame as playing', () {
      // The game smooths frame by frame; the bench uses the closed form.
      // If they disagreed, a scrubbed frame would depend on how you got
      // there and the bench would be unreliable exactly when you lean on it.
      var zoom = CavemanBaseballGame.tightZoom;
      const dt = 1 / 120;
      var t = clip.contactMoment;
      for (var i = 0; i < 120; i++) {
        t += dt;
        final rate = (CavemanBaseballGame.zoomOutRate * dt).clamp(0.0, 1.0);
        zoom += (CavemanBaseballGame.wideZoom - zoom) * rate;
      }
      expect(clip.cameraAt(t).zoom, closeTo(zoom, 0.03));
    });
  });

  group('the bench launches and draws', () {
    Future<void> openTab(WidgetTester t, String tab) async {
      await t.binding.setSurfaceSize(const Size(900, 1400));
      await t.pumpWidget(const BenchApp());
      await t.pump(const Duration(milliseconds: 16));
      await t.tap(find.text(tab));
      // Not pumpAndSettle: the swing and pitch benches hold a Ticker open
      // for the whole of their life, so nothing ever settles. Pump the
      // tab transition by hand instead.
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 32));
      }
      expect(TestWidgetsFlutterBinding.instance.takeException(), isNull);
    }

    /// The dial lists scroll, so a label can exist and still not be built.
    Future<void> expectDial(WidgetTester t, String label) async {
      await t.scrollUntilVisible(
        find.text(label),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(label), findsOneWidget, reason: label);
    }

    testWidgets('UI tab offers every look dial', (t) async {
      await openTab(t, 'UI');
      // The dial table IS the tab: if a dial exists it has a slider, and
      // if it does not, nothing can tune it.
      for (final d in Look.dials) {
        await expectDial(t, d.label);
      }
      // And both ends of the zoom, which is the thing being scrubbed
      // between.
      expect(find.text('FIELDING'), findsOneWidget);
      expect(find.text('BATTING'), findsOneWidget);
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('SWING tab owns the bat, PITCH tab does not', (t) async {
      await openTab(t, 'SWING');
      for (final lever in ['bat swing', 'load', 'finish', 'meets at', 'whip']) {
        await expectDial(t, lever);
      }
      expect(find.text('window'), findsNothing);
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('PITCH tab owns the timing, and no longer the bat', (t) async {
      await openTab(t, 'PITCH');
      for (final k in ContactCase.values) {
        expect(find.text(k.label), findsWidgets, reason: k.label);
      }
      expect(find.text('LIVE'), findsOneWidget);
      for (final lever in ['window', 'pitch', 'slow x']) {
        await expectDial(t, lever);
      }
      // Moved to the swing bench. Tuning the arc beside a timing window
      // made every change to one look like a change to the other.
      expect(find.text('bat swing'), findsNothing);
      await t.binding.setSurfaceSize(null);
    });

    test('every dial is filed under exactly one heading', () {
      final filed = [for (final g in Look.groups) ...Look.inGroup(g)];
      expect(filed.length, Look.dials.length);
      expect(filed.toSet().length, Look.dials.length);
    });
  });

  group('the look is tunable without touching the simulation', () {
    tearDown(Look.now.reset);

    test('every dial round-trips through save and load', () {
      for (final d in Look.dials) {
        d.set(Look.now, (d.min + d.max) / 2);
      }
      final saved = Look.now.toMap();
      Look.now.reset();
      Look.now.applyMap(saved);
      for (final d in Look.dials) {
        expect(d.get(Look.now), closeTo((d.min + d.max) / 2, 1e-9));
      }
    });

    test('the shipped look is the shipped field', () {
      // `FieldSpec.compact` is a const so the pure simulation and its
      // headless tools never reach into the render layer — which means
      // the two can drift, and this is what stops them.
      Look.now.reset();
      final f = Look.now.fieldSpec;
      expect(f.baseDistance, FieldSpec.compact.baseDistance);
      expect(f.secondDistance, closeTo(FieldSpec.compact.secondDistance, 1e-9));
      expect(f.wallRadius, FieldSpec.compact.wallRadius);
      expect(f.moundDistance, FieldSpec.compact.moundDistance);
      // And the man has to stand on the dirt he is drawn on.
      expect(Schemes.line.thrower.depth, closeTo(f.moundDistance, 1e-9));
    });

    test('the distances actually move the bases', () {
      Look.now.reset();
      final near = basePosition(secondBase, Look.now.fieldSpec).y;
      Look.now.secondDistance = 30;
      final far = basePosition(secondBase, Look.now.fieldSpec).y;
      expect(far, greaterThan(near));
      expect(far, closeTo(30, 1e-9));
    });

    test('squash alone decides the diamond aspect', () {
      Look.now.reset();
      // Width is fixed by the corners, height by second times squash, so
      // the ratio a player reads as "how far over the field am I" is one
      // dial. Flatten the ground and the diamond gets wider, always.
      Look.now.squash = 0.5;
      final flat = Look.now.diamondAspect;
      Look.now.squash = 1.0;
      expect(Look.now.diamondAspect, lessThan(flat));
    });
  });
}
