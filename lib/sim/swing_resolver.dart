// Turns one tap into a batted ball.
//
// The club decides the distance and the route; the tap decides the angle.
// Those are the only two dimensions the offence has.
//
// Contact quality still falls off as timing drifts, but how much of that costs
// you POWER is a per-club trait (Club.sideBite) rather than a universal
// penalty. That change closed the worst hole in the game: when direction and
// power both came from the same tap, every ball hit to a line arrived feeble,
// and a defence bunched on the middle could not be beaten by anything.
import 'dart:math' as math;

import '../model/club.dart';
import '../model/rock.dart';
import 'game_rules.dart';

enum SwingVerdict { whiff, contact, fouledOff }

class SwingOutcome {
  const SwingOutcome({
    required this.verdict,
    required this.timingError,
    required this.normalizedError,
    required this.quality,
    required this.exitSpeed,
    required this.sprayDegrees,
    this.carry = 0,
  });

  final SwingVerdict verdict;

  /// Seconds off ideal contact. Negative is early, positive is late.
  final double timingError;

  /// [timingError] scaled to the swing window; -1..1 is contact.
  final double normalizedError;

  /// 0..1 contact quality, 1 being dead on.
  final double quality;

  final double exitSpeed;

  /// Negative is pulled left, positive pushed right.
  final double sprayDegrees;

  /// Metres the ball flies before landing. Zero for a ground ball.
  final double carry;

  bool get isEarly => timingError < 0;
  bool get inPlay => verdict == SwingVerdict.contact;

  String get label => switch (verdict) {
    SwingVerdict.whiff => 'Miss',
    SwingVerdict.fouledOff => 'Foul',
    SwingVerdict.contact => timingError.abs() * 1000 <= 12 ? 'Dead on' : _offBy,
  };

  String get _offBy {
    final ms = (timingError * 1000).abs().round();
    return isEarly ? 'Early ${ms}ms' : 'Late ${ms}ms';
  }
}

class SwingResolver {
  const SwingResolver({
    this.referenceExitSpeed = 40.0,
    this.referenceMass = 0.25,
  });

  /// Exit speed for perfect contact with a 1.0-power club and a plain rock.
  final double referenceExitSpeed;

  final double referenceMass;

  SwingOutcome resolve({
    required double timingError,
    required Club club,
    required Rock rock,

    /// The batter's archetype multiplier.
    double powerScale = 1.0,

    /// Scales the club's swing-to-swing spread. Zero makes contact exact.
    double jitter = 1.0,

    /// Widens the window — a slow pitch gives longer to read it, which is
    /// what Nok Noggin buys.
    double windowScale = 1.0,
    math.Random? rng,
  }) {
    final window = GameRules.timingWindow * windowScale;
    final normalized = window <= 0 ? double.infinity : timingError / window;

    // Heavier rocks resist the club. The exponent is deliberately well below
    // 0.5: at a square root, light rocks were strictly better at everything
    // and the choice of rock collapsed.
    final massFactor = math
        .pow(referenceMass / rock.ball.mass, 0.30)
        .toDouble();

    // No two swings connect identically. Pass jitter: 0 to get the bare
    // deterministic mapping, which is what the timing tests assert against.
    final roll = rng ?? math.Random();
    double withSpread(double speed) {
      final band = club.spread * jitter;
      if (band <= 0) return speed;
      return speed * (1 + (roll.nextDouble() * 2 - 1) * band);
    }

    double angleFor(double n) {
      final noise = rock.sprayNoise == 0
          ? 0.0
          : (roll.nextDouble() * 2 - 1) * rock.sprayNoise;
      return n * club.maxSpray + rock.sprayBias + noise;
    }

    // A bunt makes contact whatever the timing, at a fixed feeble speed.
    if (club.cannotMiss) {
      final clamped = normalized.isFinite
          ? normalized.clamp(-1.0, 1.0).toDouble()
          : 0.0;
      return SwingOutcome(
        verdict: SwingVerdict.contact,
        timingError: timingError,
        normalizedError: clamped,
        quality: 1.0,
        exitSpeed: withSpread(
          referenceExitSpeed * club.power * massFactor * powerScale,
        ),
        sprayDegrees: angleFor(clamped),
        carry: club.carry,
      );
    }

    if (normalized.abs() > 1.0) {
      return SwingOutcome(
        verdict: SwingVerdict.whiff,
        timingError: timingError,
        normalizedError: normalized,
        quality: 0,
        exitSpeed: 0,
        sprayDegrees: 0,
      );
    }

    // Parabolic falloff: 1.0 dead on, 0.0 at the edge of the window.
    final quality = 1.0 - normalized * normalized;
    final powerFactor = club.sideBite + (1.0 - club.sideBite) * quality;

    return SwingOutcome(
      verdict: SwingVerdict.contact,
      timingError: timingError,
      normalizedError: normalized,
      quality: quality,
      exitSpeed: withSpread(
        referenceExitSpeed * club.power * powerFactor * massFactor * powerScale,
      ),
      sprayDegrees: angleFor(normalized),
      carry: club.carry,
    );
  }
}
