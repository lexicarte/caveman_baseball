// ignore_for_file: avoid_print
//
// Can a player with no cards at all get on base against every scheme?
//
// REQUIREMENT: STIK with the bases empty must never be blanked. Hitting to a
// line, into any gap, or at a slow fielder has to be able to reach first.
// Strategy is supposed to arrive when there is a runner on — an early-game
// at-bat that is lost before it starts is a bug, not difficulty.
//
// Angle and power both come from the same tap, so this sweeps TIMING rather
// than sweeping angle independently.
import 'dart:math' as math;

import 'package:caveman_baseball/data/clubs.dart';
import 'package:caveman_baseball/sim/game_rules.dart';
import 'package:caveman_baseball/data/rocks.dart';
import 'package:caveman_baseball/model/rock.dart';
import 'package:caveman_baseball/sim/fielder_spec.dart';

import 'harness.dart';

const points = [
  -0.95,
  -0.75,
  -0.55,
  -0.35,
  -0.15,
  0.15,
  0.35,
  0.55,
  0.75,
  0.95,
];

void sweep(Rock rock) {
  print('');
  print('STIK vs ${rock.name}, bases empty');
  print(
    'timing  ${points.map((p) => (p * 100).round().toString().padLeft(6)).join()}',
  );
  print(
    'angle   ${points.map((p) => (p * Clubs.stik.maxSpray).round().toString().padLeft(6)).join()}',
  );
  print('-' * 72);

  // Several swings per timing point. A club now has swing-to-swing spread,
  // so a single sample with a fixed seed measures one particular roll rather
  // than what that timing is worth.
  const trialsPerPoint = 40;

  for (final scheme in Schemes.all) {
    final labels = <String>[];
    var ways = 0;
    for (final p in points) {
      final rng = math.Random(5);
      var on = 0, counted = 0;
      for (var i = 0; i < trialsPerPoint; i++) {
        final res = playAtBat(
          club: Clubs.stik,
          rock: rock,
          scheme: scheme,
          timingError: p * GameRules.timingWindow,
          rng: rng,
        );
        if (!res.counted) continue;
        counted++;
        if (res.onBase) on++;
      }
      final rate = counted == 0 ? 0.0 : on / counted;
      labels.add(rate == 0 ? 'out' : '${(rate * 100).round()}%');
      // A timing point counts as a way on if it reaches base more often
      // than not.
      if (rate >= 0.5) ways++;
    }
    final verdict = ways == 0
        ? '  <-- BLANKED'
        : ways == 1
        ? '  (only one way on)'
        : '';
    print(
      '${scheme.name.padRight(7)} '
      '${labels.map((l) => l.padLeft(6)).join()}  $ways/10$verdict',
    );
  }
}

void main() {
  for (final rock in [Rocks.plain, Rocks.heavy, Rocks.dirtBiter]) {
    sweep(rock);
  }
}
