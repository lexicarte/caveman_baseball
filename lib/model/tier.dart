// Card and player tiers, named for the ages they belong to.
//
// Upgrading raises absolute power, not just extremity: the player's whole team
// and the opposition both scale, so growth is what keeps pace. The constraint
// that matters is that upgrade magnitudes stay comparable across the roster,
// which the matchup matrix checks per tier.
enum Tier {
  stone,
  copper,
  bronze;

  /// Seasons the player must have played before this tier is available at all,
  /// so no amount of currency buys the top tier early.
  int get seasonsRequired => switch (this) {
    Tier.stone => 0,
    Tier.copper => 1,
    Tier.bronze => 2,
  };

  String get label => switch (this) {
    Tier.stone => 'Stone',
    Tier.copper => 'Copper',
    Tier.bronze => 'Bronze',
  };
}
