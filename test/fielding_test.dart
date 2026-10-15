// Ball flight, chasing, and base running.
//
// The air branch shipped dead once already — an edit silently failed to apply
// and every air club resolved as a ground ball while the suite stayed green.
// These exist so that cannot happen quietly again.
import 'dart:math';

import 'package:caveman_baseball/data/clubs.dart';
import 'package:caveman_baseball/data/rocks.dart';
import 'package:caveman_baseball/model/player.dart';
import 'package:caveman_baseball/sim/ball_flight.dart';
import 'package:caveman_baseball/sim/base_running.dart';
import 'package:caveman_baseball/sim/field_spec.dart';
import 'package:caveman_baseball/sim/fielder_spec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sim = BallFlightSim();
  const field = FieldSpec.compact;
  const running = BaseRunning();

  BallFlight fly({
    double speed = 36,
    double spray = 0,
    double carry = 0,
    rock,
    int seed = 5,
  }) => sim.fly(
    exitSpeed: speed,
    sprayDegrees: spray,
    nominalCarry: carry,
    rock: rock ?? Rocks.plain,
    field: field,
    rng: Random(seed),
  );

  group('ball flight', () {
    test('a ground ball comes to rest inside the wall', () {
      final f = fly(speed: 60);
      expect(f.maxDepth, lessThanOrEqualTo(field.wallRadius + 0.05));
    });

    test('a foul down the line is reported as foul', () {
      final f = fly(speed: 36, spray: 60);
      expect(f.foul, isTrue);
    });
  });

  group('air balls', () {
    test('carry is reported, and varies', () {
      final carries = [
        for (var i = 0; i < 30; i++) fly(carry: 30, seed: i).carry,
      ];
      expect(carries.every((c) => c > 0), isTrue);
      expect(
        carries.toSet().length,
        greaterThan(1),
        reason: 'carry must vary, or it is a memorisable lookup',
      );
      expect(fly().carry, 0, reason: 'a ground ball carries nothing');
    });

    test('different carries do not all resolve identically', () {
      final depths = [
        for (final c in [0.0, 12.0, 24.0, 36.0]) fly(carry: c).restPoint.length,
      ];
      expect(
        depths.toSet().length,
        greaterThan(1),
        reason: 'carry must actually influence the flight',
      );
    });

    test('an air ball hangs longer than a grounder of the same strength', () {
      // Without hang time no fielder can ever converge on one, which made the
      // air route strictly better than the ground route.
      final air = fly(carry: 30);
      final ground = fly();
      final airToCarry = air.path
          .firstWhere((s) => s.position.length >= air.carry)
          .time;
      final groundToSame = ground.path
          .firstWhere(
            (s) => s.position.length >= air.carry,
            orElse: () => ground.path.last,
          )
          .time;
      expect(airToCarry, greaterThan(groundToSame));
    });

    test('nobody touches it before it lands', () {
      // A deep air ball clears the infield entirely, so the thrower — who
      // covers only the short middle — can never be the one who gathers it.
      final f = fly(carry: 34, speed: 38);
      final grab = sim.chaseBy(Schemes.wheel.fielders[1], f);
      expect(grab.point.length, greaterThan(20));
    });
  });

  group('base coverage', () {
    test('every needed bag gets a man when there are enough', () {
      final covers = Schemes.wheel.fielders.take(3).toList();
      final map = running.assignCoverage(
        covers,
        field,
        needed: const [firstBase, secondBase, thirdBase],
      );
      expect(map.keys.toSet(), {firstBase, secondBase, thirdBase});
    });

    test('with more bags than men, the ones nearest scoring are guarded', () {
      // No catcher means four bags and three men; home must not be the one
      // left open, or every runner on third walks in.
      final covers = Schemes.wheel.fielders.take(3).toList();
      final map = running.assignCoverage(
        covers,
        field,
        needed: const [firstBase, secondBase, thirdBase, homeBase],
      );
      expect(map.length, 3);
      expect(map.containsKey(homeBase), isTrue);
      expect(map.containsKey(firstBase), isFalse);
    });
  });

  group('throws', () {
    const quick = Player(id: 'q', name: 'Q', archetype: Archetype.swift);

    test('a throw to a bag nobody reached sails through', () {
      final r = running.resolveThrow(
        targetBase: firstBase,
        fieldedAt: basePosition(secondBase, field),
        fieldedTime: 0.5,
        thrower: Schemes.wheel.fielders[1],
        coverMan: null,
        runner: Runner(player: quick, from: homePlate, to: firstBase),
        field: field,
      );
      expect(r.coverReachedBag, isFalse);
      expect(r.isOut, isFalse);
      expect(r.label, contains('Nobody covering'));
    });

    test('a quick gather near the bag retires the runner', () {
      // Somebody already standing on the bag. The gather is what is being
      // measured here, so the cover must not be the slow part.
      final atTheBag = FielderSpec(
        id: 'x',
        name: 'On the bag',
        angleDegrees: 45,
        depth: field.baseDistance,
      );
      final r = running.resolveThrow(
        targetBase: firstBase,
        fieldedAt: basePosition(firstBase, field),
        fieldedTime: 0.2,
        thrower: Schemes.wheel.fielders[1],
        coverMan: atTheBag,
        runner: Runner(player: quick, from: homePlate, to: firstBase),
        field: field,
      );
      expect(r.isOut, isTrue);
    });

    test('the thrower can no longer cover first against a quick runner', () {
      // NOT a regression — a consequence of the wider diamond tuned on
      // 2026-10-11. Home to first went 13 -> 16.36 paces, so the walk
      // from the mound to the bag went 9.2 -> 11.6 while `secondsPerBase`
      // did not move, and the runner now wins that race. Recorded rather
      // than fixed because base running is deliberately NOT distance
      // based; if this reads as too generous to the offence, the lever is
      // `secondsPerBase`, and it has to go through the balance tools.
      final r = running.resolveThrow(
        targetBase: firstBase,
        fieldedAt: basePosition(firstBase, field),
        fieldedTime: 0.2,
        thrower: Schemes.wheel.fielders[1],
        coverMan: Schemes.wheel.fielders[1],
        runner: Runner(player: quick, from: homePlate, to: firstBase),
        field: field,
      );
      expect(r.isOut, isFalse);
      expect(r.coverArrives, greaterThan(r.throwArrives));
    });

    test('a faster runner is harder to retire', () {
      const slow = Player(id: 's', name: 'S', archetype: Archetype.mighty);
      expect(
        running.runnerArrival(
          Runner(player: quick, from: homePlate, to: firstBase),
        ),
        lessThan(
          running.runnerArrival(
            Runner(player: slow, from: homePlate, to: firstBase),
          ),
        ),
      );
    });
  });

  group('defensive shape', () {
    test('every scheme fields five men, including a catcher', () {
      for (final s in Schemes.all) {
        expect(s.fielders.length, 5, reason: s.name);
        expect(s.fielders.any((f) => f.id == 'c'), isTrue, reason: s.name);
      }
    });

    test('LINE leaves both lines open', () {
      // Its whole identity: a knot on the middle that concedes the lines.
      for (final f in Schemes.line.fielders) {
        expect(f.angleDegrees.abs(), lessThan(20), reason: f.name);
      }
    });

    test('a club exists for every range', () {
      final ranges = Clubs.all.map((c) => c.range).toSet();
      expect(ranges.length, greaterThanOrEqualTo(4));
    });
  });
}
