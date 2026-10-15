// A fielder who arrives at the wrong moment, or who slides without moving
// his legs, makes a play unreadable — and neither shows up in a screenshot.
import 'package:flutter_test/flutter_test.dart';

import 'package:caveman_baseball/game/components/caveman.dart';
import 'package:caveman_baseball/game/field_motion.dart';
import 'package:caveman_baseball/model/player.dart';

Placement at(double playback, {double arriveAt = 2.0, double react = 0.35}) =>
    placeFielder(
      fromX: 0,
      fromY: 20,
      toX: 12,
      toY: 8,
      reactionTime: react,
      arriveAt: arriveAt,
      playback: playback,
      stride: CavemanPainter.strideFor(Archetype.steady, 4.6),
    );

void main() {
  group('a fielder gets there exactly when the simulation says', () {
    test('he has not moved before his reaction time is up', () {
      for (final t in [0.0, 0.2, 0.349]) {
        final p = at(t);
        expect(p.x, 0, reason: 'moved at $t');
        expect(p.y, 20, reason: 'moved at $t');
        expect(p.pose.act, Act.still);
      }
    });

    test('he is standing on the ball at the interception time, not after', () {
      final p = at(2.0);
      expect(p.x, closeTo(12, 1e-9));
      expect(p.y, closeTo(8, 1e-9));
    });

    test('he stays put once he has arrived', () {
      final late1 = at(2.5), late2 = at(9.0);
      expect(late1.x, closeTo(12, 1e-9));
      expect(late2.x, closeTo(12, 1e-9));
      expect(late2.pose.act, Act.still);
    });

    test('he covers ground steadily in between', () {
      final a = at(0.35 + (2.0 - 0.35) * 0.25);
      final b = at(0.35 + (2.0 - 0.35) * 0.50);
      final c = at(0.35 + (2.0 - 0.35) * 0.75);
      expect(a.x, closeTo(3, 1e-6));
      expect(b.x, closeTo(6, 1e-6));
      expect(c.x, closeTo(9, 1e-6));
    });

    test('an arrival inside the reaction window snaps him there', () {
      final p = at(0.1, arriveAt: 0.2);
      expect(p.x, closeTo(12, 1e-9));
    });
  });

  group('his legs move while he does', () {
    test('he is running whenever he is between post and ball', () {
      for (final f in [0.1, 0.3, 0.5, 0.7, 0.9]) {
        final p = at(0.35 + (2.0 - 0.35) * f);
        expect(p.pose.act, Act.run, reason: 'standing still at $f');
        expect(p.pose.t, inInclusiveRange(0.0, 1.0));
      }
    });

    test('a man with nowhere to go never breaks into a run', () {
      final p = placeFielder(
        fromX: 4,
        fromY: 4,
        toX: 4,
        toY: 4,
        reactionTime: 0.35,
        arriveAt: 2.0,
        playback: 1.0,
        stride: 6,
      );
      expect(p.pose.act, Act.still);
    });

    test('the stride is driven by distance, so he cannot skate', () {
      // Two samples the same distance apart must advance the cycle by the
      // same amount, whatever the clock is doing.
      const stride = 6.0;
      Placement s(double f) => placeFielder(
        fromX: 0,
        fromY: 0,
        toX: 30,
        toY: 0,
        reactionTime: 0,
        arriveAt: 1,
        playback: f,
        stride: stride,
      );
      // 0.1 of the journey is 3 units, which is half a 6-unit stride.
      expect(s(0.1).pose.t, closeTo(0.5, 1e-9));
      expect(s(0.2).pose.t, closeTo(0.0, 1e-9));
      expect(s(0.3).pose.t, closeTo(0.5, 1e-9));
    });
  });
}
