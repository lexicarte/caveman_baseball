// Where defenders stand, and the five schemes the thrower toggles between.
//
// Positions are polar from home plate: negative angle is left field, positive
// is right. Schemes are data so that the whole defensive shape is one constant
// to change, and so the matchup matrix can sweep them.
import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import '../model/player.dart';

class FielderSpec {
  const FielderSpec({
    required this.id,
    required this.name,
    required this.angleDegrees,
    required this.depth,
    this.closingSpeed = 6.5,
    this.reactionTime = 0.35,
    this.throwSpeed = 26.0,
    this.transferTime = 0.45,
    this.range = 6.76,
    this.chases = true,
  });

  final String id;
  final String name;

  /// Negative is toward left field, positive toward right.
  final double angleDegrees;

  /// Metres from home plate.
  final double depth;

  final double closingSpeed;
  final double reactionTime;
  final double throwSpeed;
  final double transferTime;

  /// Whether this man can be sent after the ball at all. The catcher cannot:
  /// he guards home and nothing else. That is not a UI convenience — he is
  /// the reason the bag arithmetic works, and a catcher who wanders leaves
  /// home open for every runner on the field.
  final bool chases;

  /// How far from his post this man can still reach a ball. Without a hard
  /// limit a fielder cuts off anything he could reach eventually, which closes
  /// every gap and makes offence impossible.
  final double range;

  /// Applies a player's stats to a post. Speed covers ground, power throws —
  /// so who you put where changes which gaps exist.
  FielderSpec withPlayer(Player p) => FielderSpec(
    id: id,
    name: p.name,
    angleDegrees: angleDegrees,
    depth: depth,
    closingSpeed: closingSpeed * p.speedScale,
    reactionTime: reactionTime,
    throwSpeed: throwSpeed * p.powerScale,
    transferTime: transferTime,
    range: range * p.speedScale,
    chases: chases,
  );

  /// Same man, standing somewhere else. The mound is a tuned distance —
  /// what is DRAWN and what the thrower delivers from have to be the same
  /// spot, or the rock leaves from a patch of empty dirt.
  FielderSpec atDepth(double newDepth) => FielderSpec(
    id: id,
    name: name,
    angleDegrees: angleDegrees,
    depth: newDepth,
    closingSpeed: closingSpeed,
    reactionTime: reactionTime,
    throwSpeed: throwSpeed,
    transferTime: transferTime,
    range: range,
    chases: chases,
  );

  FielderSpec copyWith({double? closingSpeed, double? rangeScale}) =>
      FielderSpec(
        id: id,
        name: name,
        angleDegrees: angleDegrees,
        depth: depth,
        closingSpeed: closingSpeed ?? this.closingSpeed,
        reactionTime: reactionTime,
        throwSpeed: throwSpeed,
        transferTime: transferTime,
        range: range * (rangeScale ?? 1.0),
        chases: chases,
      );

  Vector2 get position {
    final r = angleDegrees * math.pi / 180.0;
    return Vector2(math.sin(r) * depth, math.cos(r) * depth);
  }

  /// Earliest time this man could be standing on [point].
  double timeToReach(Vector2 point) =>
      reactionTime + (point - position).length / closingSpeed;
}

/// One defensive arrangement. Four men: the thrower plus three in the field.
class Scheme {
  const Scheme({
    required this.id,
    required this.name,
    required this.givesUp,
    required this.fielders,
  });

  final String id;
  final String name;

  /// What this scheme is deliberately open to. Player-facing, and the thing
  /// the batter is trying to work out during the pitch.
  final String givesUp;

  final List<FielderSpec> fielders;

  int get count => fielders.length;

  /// The man who delivers. He and `FieldSpec.moundDistance` used to
  /// disagree — 10 against 15 — and he won, because a rock leaving from a
  /// spot nobody stands on reads as a bug. They now agree, and [moundAt]
  /// is how a tuned mound distance reaches him.
  FielderSpec get thrower =>
      fielders.firstWhere((f) => f.id == 'p', orElse: () => fielders[1]);

  /// Moves the thrower to a tuned mound distance, leaving everyone else be.
  Scheme moundAt(double depth) => Scheme(
    id: id,
    name: name,
    givesUp: givesUp,
    fielders: [
      for (final f in fielders) f.id == 'p' ? f.atDepth(depth) : f,
    ],
  );

  /// Scales range rather than replacing it, so deliberate per-man differences
  /// — the thrower's short reach especially — survive a balance sweep.
  Scheme tuned({double? closingSpeed, double? rangeScale}) => Scheme(
    id: id,
    name: name,
    givesUp: givesUp,
    fielders: [
      for (final f in fielders)
        f.copyWith(closingSpeed: closingSpeed, rangeScale: rangeScale),
    ],
  );

  /// Puts real men on the posts, in the order given.
  Scheme staffed(List<Player> players) => Scheme(
    id: id,
    name: name,
    givesUp: givesUp,
    fielders: [
      for (var i = 0; i < fielders.length; i++)
        if (i < players.length)
          fielders[i].withPlayer(players[i])
        else
          fielders[i],
    ],
  );
}

class Schemes {
  /// The thrower is off balance after delivering, so he covers far less ground
  /// than a set fielder. Giving him a normal radius let him swallow everything
  /// hit up the middle — which is where good timing sends it — and that single
  /// detail made timing skill worthless.
  /// Stands on the plate. Low-mobility by design, which is exactly why the
  /// mighty archetype belongs here: he never has to cover ground, and his arm
  /// is useful on throws from home.
  ///
  /// His existence is what makes the bag arithmetic work — five defenders,
  /// one chases, four cover first, second, third and home with none left open.
  static const _catcher = FielderSpec(
    id: 'c',
    name: 'Catcher',
    angleDegrees: 0,
    depth: 0,
    range: 4.0,
    reactionTime: 0.45,
    chases: false,
  );

  // Depth tracks FieldSpec.compact.moundDistance. He is drawn standing on
  // the mound, so moving the dirt without moving him leaves the rock
  // leaving from a patch of empty ground.
  static const _thrower = FielderSpec(
    id: 'p',
    name: 'Thrower',
    angleDegrees: 0,
    depth: 11.273,
    range: 5.07,
    reactionTime: 0.55,
  );

  static const close = Scheme(
    id: 'close',
    name: 'CLOSE',
    givesUp: 'anything hit past them',
    fielders: [
      _catcher,
      _thrower,
      FielderSpec(id: 'lf', name: 'Left', angleDegrees: -35, depth: 15),
      FielderSpec(id: 'cf', name: 'Centre', angleDegrees: 0, depth: 16),
      FielderSpec(id: 'rf', name: 'Right', angleDegrees: 35, depth: 15),
    ],
  );

  static const deep = Scheme(
    id: 'deep',
    name: 'DEEP',
    givesUp: 'short balls and dinks',
    fielders: [
      _catcher,
      _thrower,
      FielderSpec(id: 'lf', name: 'Left', angleDegrees: -35, depth: 29),
      FielderSpec(id: 'cf', name: 'Centre', angleDegrees: 0, depth: 32),
      FielderSpec(id: 'rf', name: 'Right', angleDegrees: 35, depth: 29),
    ],
  );

  /// Flattened on purpose. Bunched AND staggered front-to-back, this covered
  /// 7 to 39 paces of a 44-pace field and was the one genuinely unbeatable
  /// scheme — nothing went through it and nothing went over it. All at one
  /// depth keeps the identity and makes the long ball the obvious answer.
  static const line = Scheme(
    id: 'line',
    name: 'LINE',
    givesUp: 'both lines, and the long ball',
    fielders: [
      _catcher,
      _thrower,
      FielderSpec(id: 'lf', name: 'Left', angleDegrees: -14, depth: 23),
      FielderSpec(id: 'cf', name: 'Centre', angleDegrees: 0, depth: 23),
      FielderSpec(id: 'rf', name: 'Right', angleDegrees: 14, depth: 23),
    ],
  );

  static const wide = Scheme(
    id: 'wide',
    name: 'WIDE',
    givesUp: 'the short middle',
    fielders: [
      _catcher,
      _thrower,
      FielderSpec(id: 'lf', name: 'Left', angleDegrees: -44, depth: 21),
      FielderSpec(id: 'cf', name: 'Deep', angleDegrees: 0, depth: 31),
      FielderSpec(id: 'rf', name: 'Right', angleDegrees: 44, depth: 21),
    ],
  );

  static const wheel = Scheme(
    id: 'wheel',
    name: 'WHEEL',
    givesUp: 'not much — the safe one',
    fielders: [
      _catcher,
      _thrower,
      // Spread wider than the others so its gaps are findable. Bunched at
      // the same depth the default club dies at, the "safe" scheme became
      // accidentally the hardest one in the game.
      FielderSpec(id: 'lf', name: 'Left', angleDegrees: -38, depth: 21),
      FielderSpec(id: 'cf', name: 'Centre', angleDegrees: 0, depth: 28),
      FielderSpec(id: 'rf', name: 'Right', angleDegrees: 38, depth: 21),
    ],
  );

  static const List<Scheme> all = [close, deep, line, wide, wheel];
}
