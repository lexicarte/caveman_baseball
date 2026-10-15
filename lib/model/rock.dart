// A rock: the defence card.
//
// The batter has exactly two variables and one action, so a rock has exactly
// three things it can attack — his distance, his angle, or the act of swinging
// itself. Nothing a rock could do falls outside those.
import '../sim/ball_spec.dart';
import 'tier.dart';

enum RockJob { plain, distance, angle, risk }

/// How readable the rock is in flight.
///
/// This is a balance dial in its own right, and it only exists because taking
/// a strike is a real-time read: an OBVIOUS rock can carry a nastier effect
/// because the batter can bail and pay a club and a strike for it, while a
/// SUBTLE one must be milder because he is committed before he knows.
enum RockTell { plain, subtle, obvious }

/// What a risk rock does to a club when the batter swings at it.
enum RiskEffect {
  /// The club is gummed up and gone for the rest of the at-bat.
  stick,

  /// The club chips: weaker for the rest of the at-bat.
  chip,
}

class Rock {
  const Rock({
    required this.id,
    required this.name,
    required this.blurb,
    required this.job,
    required this.tell,
    required this.ball,
    this.carryScale = 1.0,
    this.sprayBias = 0,
    this.sprayNoise = 0,
    this.risk,
    this.tier = Tier.stone,
  });

  final String id;
  final String name;
  final String blurb;

  final RockJob job;
  final RockTell tell;

  /// Physics. Kept as a separate value so the simulation layer never has to
  /// know that cards exist.
  final BallSpec ball;

  /// Multiplies a club's carry. Below 1 it guts the air club specifically.
  final double carryScale;

  /// Fixed degrees of bias added to the batted angle — the spinners. Readable,
  /// so a batter who spots it can compensate with his timing.
  final double sprayBias;

  /// Random degrees added to the batted angle — the bouncer. Unpredictable for
  /// the thrower too, so a good defensive read is wasted on it.
  final double sprayNoise;

  /// Non-null makes this a risk rock.
  final RiskEffect? risk;

  final Tier tier;

  bool get isRisk => risk != null;

  /// Risk rocks are too awkward to throw true: let one go and it costs the
  /// batter a club but does not advance the count. That is the gamble.
  bool get noStrikeOnTake => isRisk;
}
