// Shared at-bat harness for the balance tools.
//
// One place where a swing becomes an outcome, so the matrix, the baseline
// check and the sweep cannot quietly disagree about how the game works. Bases
// are empty: the question is whether the batter reaches, and how far.
import 'dart:math' as math;

import 'package:caveman_baseball/model/club.dart';
import 'package:caveman_baseball/model/player.dart';
import 'package:caveman_baseball/model/rock.dart';
import 'package:caveman_baseball/sim/ball_flight.dart';
import 'package:caveman_baseball/sim/base_running.dart';
import 'package:caveman_baseball/sim/field_spec.dart';
import 'package:caveman_baseball/sim/fielder_spec.dart';
import 'package:caveman_baseball/sim/swing_resolver.dart';

const field = FieldSpec.compact;
const swingResolver = SwingResolver();
const flightSim = BallFlightSim();
const baseRunning = BaseRunning();

const steadyBatter = Player(
  id: 'x',
  name: 'Batter',
  archetype: Archetype.steady,
);

/// What one swing was worth. -1 means it never became an at-bat (a foul).
class AtBatResult {
  const AtBatResult(this.bases, this.label);
  final int bases;
  final String label;

  bool get counted => bases >= 0;
  bool get onBase => bases > 0;

  static const foul = AtBatResult(-1, 'foul');
}

AtBatResult playAtBat({
  required Club club,
  required Rock rock,
  required Scheme scheme,
  required double timingError,
  Player batter = steadyBatter,
  math.Random? rng,
}) {
  final r = rng ?? math.Random(17);

  final swing = swingResolver.resolve(
    timingError: timingError,
    club: club,
    rock: rock,
    powerScale: batter.powerScale,
    rng: r,
  );
  if (swing.verdict != SwingVerdict.contact) {
    return const AtBatResult(0, 'miss');
  }

  final flight = flightSim.fly(
    exitSpeed: swing.exitSpeed,
    sprayDegrees: swing.sprayDegrees,
    nominalCarry: swing.carry,
    rock: rock,
    field: field,
    rng: r,
  );
  if (flight.foul) return AtBatResult.foul;

  // The defence chases with whoever gets there soonest — and the catcher is
  // not an option. He guards home and nothing else, so pricing cards against
  // a catcher who roams would value every club against a defence the game
  // does not actually field.
  Interception? best;
  for (final post in scheme.fielders) {
    if (!post.chases) continue;
    final grab = flightSim.chaseBy(post, flight);
    if (best == null || grab.time < best.time) best = grab;
  }
  final grab = best!;
  if (grab.caught) return const AtBatResult(0, 'caught');

  final covers = [
    for (final f in scheme.fielders)
      if (f.id != grab.fielder.id) f,
  ];
  // Bases are empty, so only first needs guarding. Asking for second and
  // third as well lets the optimiser strand a slow man on first.
  final coverage = baseRunning.assignCoverage(
    covers,
    field,
    needed: const [firstBase],
  );

  final runner = Runner(player: batter, from: homePlate, to: firstBase);
  final play = baseRunning.resolveThrow(
    targetBase: firstBase,
    fieldedAt: grab.point,
    fieldedTime: grab.time,
    thrower: grab.fielder,
    coverMan: coverage[firstBase],
    runner: runner,
    field: field,
  );
  if (play.isOut) return const AtBatResult(0, 'out');

  baseRunning.advanceAll([runner], play.throwArrives);
  final bases = runner.scored ? 4 : runner.to;
  return AtBatResult(bases, switch (bases) {
    1 => '1B',
    2 => '2B',
    3 => '3B',
    _ => 'HR?',
  });
}

/// Average total bases per at-bat over a realistic spread of swing timing.
///
/// A uniform sweep of exit speeds badly misrepresents the game: real contact
/// clusters around the player's accuracy, so this is the number that predicts
/// how a matchup will actually feel.
double totalBasesPerAtBat({
  required Club club,
  required Rock rock,
  required Scheme scheme,
  double sigmaMs = 35,
  int trials = 700,
  int seed = 31,
  Player batter = steadyBatter,
}) {
  final rng = math.Random(seed);
  var atBats = 0, bases = 0;
  for (var i = 0; i < trials; i++) {
    final u1 = 1.0 - rng.nextDouble();
    final u2 = rng.nextDouble();
    final g = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
    final res = playAtBat(
      club: club,
      rock: rock,
      scheme: scheme,
      timingError: g * (sigmaMs / 1000.0),
      batter: batter,
      rng: rng,
    );
    if (!res.counted) continue;
    atBats++;
    bases += res.bases;
  }
  return atBats == 0 ? 0 : bases / atBats;
}
