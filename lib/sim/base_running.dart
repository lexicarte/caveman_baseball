// Runners, covered bases, and whether a throw beats a man to the bag.
//
// Replaces a single "bases earned" number with a per-runner race. The geometry
// does the work: a ball fielded at third is nothing from third and eighteen
// paces from first, so the lead runner is dead and the batter strolls in —
// with no special case written for it.
//
// This is also what makes tap-to-field worth playing. With nobody on, tapping
// a fielder then throwing to first is a dexterity check with no choice in it.
// With runners, choosing WHICH base is the whole decision.
import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import '../model/player.dart';
import 'field_spec.dart';
import 'fielder_spec.dart';

/// 0 is home. Runners head for 1, 2 or 3; reaching 4 scores.
const int homePlate = 0;
const int firstBase = 1;
const int secondBase = 2;
const int thirdBase = 3;

/// Reaching this scores. There is no catcher, so home is a bag like any
/// other — and with three men covering it is one of FOUR that might need
/// protecting, which is why somebody always goes unguarded.
const int homeBase = 4;

/// The corners of the diamond.
///
/// First and third sit on the 45s at [FieldSpec.baseDistance]; second sits
/// straight out at [FieldSpec.secondDistance], which is its OWN number
/// rather than `d * sqrt2`. It used to be `d`, which made home-to-first 13
/// paces but first-to-second only 9.95 — not a diamond at all — and parked
/// the bag three paces behind the thrower so the two read as one cluster.
/// Second is separate because the view is from behind the plate: how deep
/// the diamond looks is a drawing decision, and the simulation has to run
/// on whatever shape that decision produces rather than on a shape of its
/// own.
Vector2 basePosition(int base, FieldSpec field) {
  final d = field.baseDistance;
  final leg = d / math.sqrt2;
  return switch (base) {
    firstBase => Vector2(leg, leg),
    secondBase => Vector2(0, field.secondDistance),
    thirdBase => Vector2(-leg, leg),
    // home, and anything past it
    _ => Vector2.zero(),
  };
}

class Runner {
  Runner({required this.player, required this.from, required this.to});

  final Player player;

  /// Base he is standing on as this play begins. 0 means he is the batter.
  ///
  /// Must be updated to [to] once a play settles, or a runner is recomputed
  /// from the plate on every subsequent pitch and can never advance past
  /// first.
  int from;

  /// Base he is trying to reach.
  int to;

  bool out = false;
  bool scored = false;
}

class ThrowResult {
  const ThrowResult({
    required this.targetBase,
    required this.throwArrives,
    required this.coverArrives,
    required this.runnerArrives,
    required this.isOut,
    required this.coverReachedBag,
  });

  final int targetBase;
  final double throwArrives;
  final double coverArrives;
  final double runnerArrives;
  final bool isOut;

  /// False when the throw beat the runner but nobody was there to take it.
  final bool coverReachedBag;

  String get label {
    if (isOut) return 'Out at ${_baseName(targetBase)}';
    if (!coverReachedBag) return 'Nobody covering ${_baseName(targetBase)}';
    return 'Safe at ${_baseName(targetBase)}';
  }

  static String _baseName(int b) => switch (b) {
    firstBase => 'first',
    secondBase => 'second',
    thirdBase => 'third',
    _ => 'home',
  };
}

class BaseRunning {
  const BaseRunning({this.secondsPerBase = 2.58});

  /// How long an average runner takes to cover one base. A player's speed
  /// scales it.
  final double secondsPerBase;

  double runnerArrival(Runner r) =>
      (r.to - r.from) * secondsPerBase / r.player.speedScale;

  /// Assigns the men who are not chasing to the bags that actually matter.
  ///
  /// [needed] is where runners are heading, which with the bases loaded is
  /// four bags — first, second, third and home — against three available men.
  /// One is always left open, and which one is a real decision: leave home
  /// and the run scores, leave first and the batter is safe.
  ///
  /// Solved as a set rather than each man grabbing his nearest, because greedy
  /// assignment happily leaves a bag empty while two men converge on the same
  /// one. Small enough to just try every arrangement.
  Map<int, FielderSpec> assignCoverage(
    List<FielderSpec> covers,
    FieldSpec field, {
    List<int> needed = const [firstBase, secondBase, thirdBase],
  }) {
    if (covers.isEmpty || needed.isEmpty) return const {};

    final men = covers.toList();
    final bags = needed.toList();

    // Prefer to guard the bags nearest scoring: a run is worth more than a
    // base. Then take as many as there are men for.
    bags.sort((a, b) => b.compareTo(a));
    final guarded = bags.take(men.length).toList();

    List<List<int>> permutations(int n) {
      if (n <= 1) return [List.generate(n, (i) => i)];
      final out = <List<int>>[];
      for (var i = 0; i < n; i++) {
        for (final rest in permutations(n - 1)) {
          out.add([i, ...rest.map((r) => r >= i ? r + 1 : r)]);
        }
      }
      return out;
    }

    Map<int, FielderSpec>? best;
    var bestWorst = double.infinity;
    for (final perm in permutations(men.length)) {
      var worst = 0.0;
      final trial = <int, FielderSpec>{};
      for (var b = 0; b < guarded.length; b++) {
        final man = men[perm[b]];
        final t = man.timeToReach(basePosition(guarded[b], field));
        if (t > worst) worst = t;
        trial[guarded[b]] = man;
      }
      // Minimise the WORST arrival: one bag nobody can reach in time is far
      // more damaging than every bag being slightly slow.
      if (worst < bestWorst) {
        bestWorst = worst;
        best = trial;
      }
    }
    return best ?? const {};
  }

  /// Plays the throw the defender chose.
  ///
  /// An out needs two things to line up: the throw beats the runner, AND the
  /// cover man got to the bag in time to take it. Throw to a base nobody has
  /// reached and the rock sails through into the dirt.
  ThrowResult resolveThrow({
    required int targetBase,
    required Vector2 fieldedAt,
    required double fieldedTime,
    required FielderSpec thrower,
    required FielderSpec? coverMan,
    required Runner? runner,
    required FieldSpec field,
  }) {
    final bag = basePosition(targetBase, field);
    final throwArrives =
        fieldedTime +
        thrower.transferTime +
        (bag - fieldedAt).length / thrower.throwSpeed;
    final coverArrives = coverMan?.timeToReach(bag) ?? double.infinity;
    final ready = math.max(throwArrives, coverArrives);
    final runnerArrives = runner == null
        ? double.infinity
        : runnerArrival(runner);

    final covered = coverArrives <= throwArrives;
    final isOut = runner != null && ready < runnerArrives;

    return ThrowResult(
      targetBase: targetBase,
      throwArrives: throwArrives,
      coverArrives: coverArrives,
      runnerArrives: runnerArrives,
      isOut: isOut,
      coverReachedBag: covered,
    );
  }

  /// How far every runner gets once the ball is dead, given when the defence
  /// got it back under control.
  void advanceAll(List<Runner> runners, double ballControlledAt) {
    for (final r in runners) {
      if (r.out) continue;
      final perBase = secondsPerBase / r.player.speedScale;
      final reached = r.from + (ballControlledAt / perBase).floor();
      r.to = math.max(r.to, math.min(reached, 4));
      if (r.to >= 4) {
        r.scored = true;
        r.to = 4;
      }
    }
  }
}
