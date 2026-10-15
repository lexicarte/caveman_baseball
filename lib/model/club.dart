// A club: the offence card, and the swing itself.
//
// The club picks the DISTANCE and the route; the player's timing picks the
// ANGLE. Those are the only two dimensions the offence has, which is why an
// earlier roster of twelve bats built from abstract "dials" collapsed into
// near-duplicates.
//
// Replaces the old BatSpec plus the swing-card effect system. A club is the
// card, not a bag of modifiers applied to one.
import 'tier.dart';

/// Roughly where the ball ends up. Descriptive — the real behaviour comes from
/// [Club.power] and [Club.carry] — but it is what the card says and what the
/// defence is trying to guess.
enum ClubRange { bunt, short, mid, long, veryLong }

/// Air balls cannot be touched until they land, so they are a precise drop.
/// Ground balls run the gauntlet but keep rolling for extra bases.
enum ClubRoute { ground, air }

class Club {
  const Club({
    required this.id,
    required this.name,
    required this.blurb,
    required this.range,
    required this.route,
    required this.power,
    required this.maxSpray,
    required this.sideBite,
    this.carry = 0,
    this.cannotMiss = false,
    this.spread = 0.025,
    this.tier = Tier.stone,
  });

  final String id;

  /// Display name. Placeholder until the real names land; nothing in the
  /// simulation reads it.
  final String name;

  final String blurb;

  final ClubRange range;
  final ClubRoute route;

  /// Exit-speed multiplier.
  final double power;

  /// How far off-centre the player's timing can place the ball, in degrees.
  /// With direction coming only from timing, this is the club's whole reach.
  final double maxSpray;

  /// Fraction of power kept on a ball hit to the side, 0..1.
  ///
  /// This is the per-club replacement for a rule that used to be universal:
  /// timing decided direction AND contact quality, so every ball hit to a line
  /// arrived feeble and a defence packed on the middle could not be beaten.
  /// A low value now means "strong straight, weak at angles" as a character
  /// trait rather than a law of physics.
  final double sideBite;

  /// Metres carried through the air before landing. Zero for a ground club.
  final double carry;

  /// Fractional spread on exit speed, swing to swing.
  ///
  /// A club names a RANGE, not a number. Without this, dead-on contact with
  /// the same club produced exactly the same distance every time, which made
  /// the whole thing feel like a lookup rather than a swing. It is per-club
  /// so a wild club can be less reliable than a steady one.
  ///
  /// This is a band on SPEED. Distance goes as roughly the square of it, so
  /// 0.025 here lands as about five per cent on where the ball ends up.
  final double spread;

  /// Contact is guaranteed regardless of timing. The bunt's identity — not
  /// "shortest", which would just be a second short club.
  final bool cannotMiss;

  final Tier tier;

  bool get isAir => route == ClubRoute.air;
}
