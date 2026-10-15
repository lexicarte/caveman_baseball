// Simulates a batted ball, and answers "if this man chases it, when does he
// get it?"
//
// Split deliberately from who does the chasing. The old resolver picked the
// interceptor itself and returned a bases-earned number, which cannot work now
// that the PLAYER taps a fielder to chase and then taps a base to throw to.
// So this produces the flight; the controller asks about chasers; and
// base_running.dart decides who is out.
import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import '../model/rock.dart';
import 'ball_physics.dart';
import 'field_spec.dart';
import 'fielder_spec.dart';

class BallSample {
  const BallSample(this.time, this.position);
  final double time;
  final Vector2 position;
}

class BallFlight {
  const BallFlight({
    required this.path,
    required this.foul,
    required this.carry,
    required this.maxDepth,
    required this.reachedWall,
    required this.restPoint,
    required this.restTime,
  });

  final List<BallSample> path;
  final bool foul;

  /// Metres actually carried through the air, after the rock's weight, how
  /// well it was struck, and jitter all had their say.
  final double carry;

  final double maxDepth;
  final bool reachedWall;

  /// Where and when the ball stopped, if nobody intercepts it.
  final Vector2 restPoint;
  final double restTime;

  bool get airborne => carry > 0;
}

class Interception {
  const Interception({
    required this.fielder,
    required this.time,
    required this.point,
    required this.caught,
  });

  final FielderSpec fielder;
  final double time;
  final Vector2 point;

  /// Taken out of the air before it landed.
  final bool caught;
}

class BallFlightSim {
  const BallFlightSim({
    this.physics = const BallPhysics(),
    this.step = 1 / 120,
    this.maxSeconds = 20,
    this.landingSpeedRetention = 0.28,
    this.smakReferenceSpeed = 32.0,
    this.smakJitter = 0.03,
    this.catchReachScale = 1.0,
    this.airSpeedScale = 0.60,
  });

  final BallPhysics physics;
  final double step;
  final double maxSeconds;

  /// A dropping ball thuds into the dirt rather than skipping. Without this it
  /// arrived at full speed and rolled straight to an outfielder, which made
  /// every air club useless.
  final double landingSpeedRetention;

  /// Exit speed at which a club's nominal carry is achieved exactly.
  final double smakReferenceSpeed;

  /// Fractional spread on carry.
  ///
  /// Small, because exit speed already carries the club's own spread into
  /// this calculation — the two compound, and at 0.10 a smak varied twice as
  /// much as every other club.
  final double smakJitter;

  /// Reach on a dropping ball, relative to fielding a roller. A man standing
  /// under one is not worse off than a man charging a grounder.
  final double catchReachScale;

  /// A lofted ball trades horizontal speed for height, so it HANGS. Without
  /// this an air ball crossed the field at ground speed and no fielder could
  /// ever converge on it, which is what made the air route strictly better
  /// than the ground one.
  final double airSpeedScale;

  /// How far this swing actually carries. A club asks for a distance; the
  /// heavy rock and a mistimed swing both change it.
  double effectiveCarry({
    required double nominalCarry,
    required Rock rock,
    required double exitSpeed,
    required math.Random rng,
  }) {
    if (nominalCarry <= 0) return 0;
    // Heavier carries further per unit speed — drag fights momentum — and the
    // mass penalty is already paid once in exit speed.
    final massFactor = math.pow(rock.ball.mass / 0.25, 0.25).toDouble();
    // Square-rooted: a powerful air club already gets its power from the
    // club, and letting that ALSO scale carry linearly sent SMAK past every
    // scheme's deepest man, which left it with no counter at all.
    final speedFactor = math
        .sqrt((exitSpeed / smakReferenceSpeed).clamp(0.20, 2.90))
        .toDouble();
    final jitter = 1.0 + (rng.nextDouble() * 2 - 1) * smakJitter;
    return nominalCarry * massFactor * speedFactor * jitter * rock.carryScale;
  }

  BallFlight fly({
    required double exitSpeed,
    required double sprayDegrees,
    required double nominalCarry,
    required Rock rock,
    required FieldSpec field,
    math.Random? rng,
  }) {
    final r = rng ?? math.Random();
    final carry = effectiveCarry(
      nominalCarry: nominalCarry,
      rock: rock,
      exitSpeed: exitSpeed,
      rng: r,
    );

    final launchSpeed = carry > 0 ? exitSpeed * airSpeedScale : exitSpeed;
    final state = physics.launch(
      exitSpeed: launchSpeed,
      sprayDegrees: sprayDegrees,
    );
    final path = <BallSample>[BallSample(0, state.position.clone())];

    // While airborne the ball only fights air, not grass.
    final airSpec = rock.ball.copyWith(rollFriction: 0);
    var landed = carry <= 0;
    var t = 0.0;
    var maxDepth = 0.0;

    while (t < maxSeconds) {
      final inAir = !landed;
      physics.step(state, inAir ? airSpec : rock.ball, field, step);
      t += step;
      path.add(BallSample(t, state.position.clone()));

      final depth = state.position.length;
      if (depth > maxDepth) maxDepth = depth;

      if (!field.isFair(state.position.x, state.position.y) && depth > 4) {
        return BallFlight(
          path: path,
          foul: true,
          carry: carry,
          maxDepth: maxDepth,
          reachedWall: state.hitWall,
          restPoint: state.position.clone(),
          restTime: t,
        );
      }

      if (inAir) {
        // Three ways an air ball's flight ends.
        //
        // It reaches its carry; or it runs out of speed and falls short
        // (without this a weak smak hovered until the clock ran out); or it
        // reaches the wall, which is the one that mattered — a carry longer
        // than the field bounced the ball off the wall in mid-air, sent it
        // sailing back over the infield, and scored it foul behind the plate.
        final atWall = depth >= field.wallRadius - 0.6;
        if (depth < carry && state.speed > 2.0 && !atWall) continue;
        landed = true;
        state.velocity.scale(landingSpeedRetention);
        continue;
      }

      if (state.atRest) break;
    }

    return BallFlight(
      path: path,
      foul: false,
      carry: carry,
      maxDepth: maxDepth,
      reachedWall: state.hitWall,
      restPoint: state.position.clone(),
      restTime: t,
    );
  }

  /// When the chosen man gets to the ball.
  ///
  /// He cuts it off the moment it reaches a point within his range that he has
  /// had time to get to. If it never comes near him he has to go and fetch it
  /// where it stopped. A ball still in the air is untouchable, except at the
  /// moment it lands — which is the only way a SMAK is caught.
  Interception chaseBy(FielderSpec man, BallFlight flight) {
    final landsAt = flight.airborne ? flight.carry : 0.0;

    for (final s in flight.path) {
      final depth = s.position.length;
      if (flight.airborne && depth < landsAt) continue;

      final justLanded = flight.airborne && depth >= landsAt;
      final reach = justLanded ? man.range * catchReachScale : man.range;

      if ((s.position - man.position).length <= reach &&
          man.timeToReach(s.position) <= s.time) {
        return Interception(
          fielder: man,
          time: s.time,
          point: s.position.clone(),
          caught: justLanded && _isLandingSample(flight, s),
        );
      }
    }

    // Nobody cut it off — go and fetch it.
    final fetch = man.timeToReach(flight.restPoint);
    return Interception(
      fielder: man,
      time: math.max(fetch, flight.restTime),
      point: flight.restPoint.clone(),
      caught: false,
    );
  }

  bool _isLandingSample(BallFlight flight, BallSample s) {
    // The first sample at or past the carry distance is the landing.
    for (final p in flight.path) {
      if (p.position.length >= flight.carry) return identical(p, s);
    }
    return false;
  }
}
