// An item: an offence card that bends a rule.
//
// Items never touch physics. That is precisely why they are explainable where
// the old swing cards were not — a swing card had to describe a change to how
// the ball behaves, an item describes a change to what you are allowed to do.
//
// Playing one costs the specialisation, not the swing: you still swing that
// pitch, just with the baseline club.
import 'tier.dart';

enum ItemEffect {
  /// See where their men stand before committing a club.
  spyDefence,

  /// A runner takes a base without a hit.
  stealBase,

  /// Guarantees a runner advances, at the cost of the out.
  sacrificeFly,

  /// A teammate bonks the thrower: the pitch arrives slowly, so there is
  /// longer to read the rock and the scheme.
  slowPitch,
}

class Item {
  const Item({
    required this.id,
    required this.name,
    required this.blurb,
    required this.effect,
    this.tier = Tier.stone,
  });

  final String id;
  final String name;
  final String blurb;
  final ItemEffect effect;
  final Tier tier;
}
