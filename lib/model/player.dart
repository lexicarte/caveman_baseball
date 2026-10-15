// A player: one of the five men on a team.
//
// Two stats only, and the differences between them are deliberately SMALL.
// This is meant to shift where the gaps in a defence are and give the lineup
// some texture — it is not a stat check, and a better player must never be
// strictly better.
//
// Both stats do double duty, which is what makes placing men interesting:
// speed runs the bases AND covers ground in the field, power hits the ball
// further AND throws it further. So the fast weak man is your best fielder
// with the worst arm, and the slow strong man is the reverse.
import 'tier.dart';

enum Archetype {
  /// Fast, weak. Beats out infield hits, covers the most ground, poor arm.
  swift,

  /// Average at everything.
  steady,

  /// Slow, strong. Drives the ball, cannon arm, a statue in the field.
  mighty;

  String get label => switch (this) {
    Archetype.swift => 'Swift',
    Archetype.steady => 'Steady',
    Archetype.mighty => 'Mighty',
  };
}

class Player {
  const Player({
    required this.id,
    required this.name,
    required this.archetype,
    this.tier = Tier.stone,
  });

  final String id;
  final String name;
  final Archetype archetype;

  /// Drives how elaborate his gear looks, so investment is visible on the
  /// field rather than buried in a menu.
  final Tier tier;

  /// Multiplier on base-running pace and on how much ground he covers
  /// fielding. Kept within roughly a tenth of average on purpose.
  double get speedScale => switch (archetype) {
    Archetype.swift => 1.12,
    Archetype.steady => 1.00,
    Archetype.mighty => 0.90,
  };

  /// Multiplier on batted-ball speed and on throw speed.
  double get powerScale => switch (archetype) {
    Archetype.swift => 0.92,
    Archetype.steady => 1.00,
    Archetype.mighty => 1.10,
  };
}
