// The rock roster.
//
// Nine rocks across three jobs. A rock can only attack the batter's distance,
// his angle, or the act of swinging — the batter has nothing else to attack.
import '../model/rock.dart';
import '../sim/ball_spec.dart';

class Rocks {
  /// What an empty slot throws. Mirrors the baseline club on offence.
  static const plain = Rock(
    id: 'plain',
    name: 'ROK',
    blurb: 'A rock. Does what rocks do.',
    job: RockJob.plain,
    tell: RockTell.plain,
    ball: BallSpec(
      id: 'plain',
      name: 'ROK',
      flavor: '',
      mass: 0.25,
      rollFriction: 26.4,
      drag: 0.0022,
      restitution: 0.30,
    ),
  );

  /// Starter junk. A gift to the batter, and most of what you own on day one.
  static const light = Rock(
    id: 'light',
    name: 'SMAL ROK',
    blurb: 'Flies off the club. They will hurt you with this.',
    job: RockJob.plain,
    tell: RockTell.plain,
    ball: BallSpec(
      id: 'light',
      name: 'SMAL ROK',
      flavor: '',
      mass: 0.15,
      rollFriction: 13.2,
      drag: 0.0006,
      restitution: 0.45,
    ),
  );

  static const heavy = Rock(
    id: 'heavy',
    name: 'FAT ROK',
    blurb: 'Comes off slow. Every club falls a step short.',
    job: RockJob.distance,
    tell: RockTell.obvious,
    ball: BallSpec(
      id: 'heavy',
      name: 'FAT ROK',
      flavor: '',
      mass: 0.70,
      rollFriction: 30.8,
      drag: 0.0030,
      restitution: 0.12,
    ),
  );

  /// Kills roll outright, so it guts the ground clubs and leaves air alone.
  /// Deliberately rare and obvious — strong enough that the batter has to be
  /// able to see it and bail.
  static const dirtBiter = Rock(
    id: 'dirt_biter',
    name: 'DIRT ROK',
    blurb: 'Bites in and stops dead. You can see it coming.',
    job: RockJob.distance,
    tell: RockTell.obvious,
    ball: BallSpec(
      id: 'dirt_biter',
      name: 'DIRT ROK',
      flavor: '',
      mass: 0.20,
      rollFriction: 44.0,
      drag: 0.0020,
      restitution: 0.15,
    ),
  );

  /// Random angle. Ruins their aim and your own read, so it is the rock you
  /// throw when you have no idea what is coming.
  static const bouncer = Rock(
    id: 'bouncer',
    name: 'FRUT ROK',
    blurb: 'Lumpy. Comes off somewhere nobody predicted.',
    job: RockJob.angle,
    tell: RockTell.obvious,
    sprayNoise: 14,
    ball: BallSpec(
      id: 'bouncer',
      name: 'FRUT ROK',
      flavor: '',
      mass: 0.28,
      rollFriction: 24.2,
      drag: 0.0022,
      restitution: 0.30,
      wobble: 0.06,
      wobbleFreq: 7,
    ),
  );

  static const spinLeft = Rock(
    id: 'spin_left',
    name: 'KRAZY ROK (L)',
    blurb: 'Turns the hit left. Watch it and swing against it.',
    job: RockJob.angle,
    tell: RockTell.subtle,
    sprayBias: -16,
    ball: BallSpec(
      id: 'spin_left',
      name: 'KRAZY ROK (L)',
      flavor: '',
      mass: 0.26,
      rollFriction: 24.2,
      drag: 0.0021,
      restitution: 0.30,
    ),
  );

  static const spinRight = Rock(
    id: 'spin_right',
    name: 'KRAZY ROK (R)',
    blurb: 'Turns the hit right. Watch it and swing against it.',
    job: RockJob.angle,
    tell: RockTell.subtle,
    sprayBias: 16,
    ball: BallSpec(
      id: 'spin_right',
      name: 'KRAZY ROK (R)',
      flavor: '',
      mass: 0.26,
      rollFriction: 24.2,
      drag: 0.0021,
      restitution: 0.30,
    ),
  );

  /// The one risk rock. Exactly what it does on a swing is still open — the
  /// chip-the-club variant was cut, so TAR carries the whole job for now.
  static const sticky = Rock(
    id: 'sticky',
    name: 'TAR',
    blurb: 'Swing and your club is stuck. Let it go and it is no strike.',
    job: RockJob.risk,
    tell: RockTell.obvious,
    risk: RiskEffect.stick,
    ball: BallSpec(
      id: 'sticky',
      name: 'TAR',
      flavor: '',
      mass: 0.27,
      rollFriction: 28.6,
      drag: 0.0022,
      restitution: 0.20,
    ),
  );

  static const List<Rock> all = [
    plain,
    light,
    heavy,
    dirtBiter,
    bouncer,
    spinLeft,
    spinRight,
    sticky,
  ];

  static const List<Rock> collectable = [
    heavy,
    dirtBiter,
    bouncer,
    spinLeft,
    spinRight,
    sticky,
  ];
}
