// Locks in the core input mapping: one tap becomes a direction and a power.
//
// These assertions ARE the design. If one breaks, the feel of the game has
// changed and that should be a deliberate decision rather than a surprise.
import 'package:caveman_baseball/data/clubs.dart';
import 'package:caveman_baseball/sim/game_rules.dart';
import 'package:caveman_baseball/data/rocks.dart';
import 'package:caveman_baseball/model/club.dart';
import 'package:caveman_baseball/model/rock.dart';
import 'package:caveman_baseball/sim/swing_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = SwingResolver();

  /// Deterministic by default: jitter 0 strips the swing-to-swing spread so
  /// these assertions measure the mapping rather than the noise on top of it.
  /// Without this they pass or fail on the roll of a die.
  SwingOutcome swing(
    double error, {
    Club? club,
    Rock? rock,
    double jitter = 0,
  }) => resolver.resolve(
    timingError: error,
    club: club ?? Clubs.stik,
    rock: rock ?? Rocks.plain,
    jitter: jitter,
  );

  group('timing picks the angle', () {
    test('dead on goes up the middle', () {
      final o = swing(0);
      expect(o.verdict, SwingVerdict.contact);
      expect(o.sprayDegrees, closeTo(0, 0.001));
      expect(o.quality, closeTo(1.0, 0.001));
    });

    test('early pulls left, late pushes right', () {
      expect(swing(-0.04).sprayDegrees, lessThan(0));
      expect(swing(0.04).sprayDegrees, greaterThan(0));
    });

    test('spray is symmetric about dead on', () {
      expect(
        swing(-0.05).sprayDegrees,
        closeTo(-swing(0.05).sprayDegrees, 1e-9),
      );
    });

    test('the window edge reaches the club full reach', () {
      expect(
        swing(GameRules.timingWindow).sprayDegrees,
        closeTo(Clubs.stik.maxSpray, 1e-9),
      );
    });
  });

  group('power does not fall off with angle', () {
    // The single most important fix in this project's history: when direction
    // and power both came from the same tap, every ball hit to a line arrived
    // feeble and a defence bunched on the middle could not be beaten at all.
    test('a ball pulled to the line keeps most of its bite', () {
      final middle = swing(0).exitSpeed;
      final line = swing(GameRules.timingWindow).exitSpeed;
      expect(line / middle, greaterThan(0.70));
    });

    test('side bite is a per-club trait, not a universal rule', () {
      double retention(Club c) =>
          swing(GameRules.timingWindow, club: c).exitSpeed /
          swing(0, club: c).exitSpeed;
      // WUNDERBAT is deliberately strong straight and weak at angles.
      expect(retention(Clubs.wunderbat), lessThan(retention(Clubs.stik)));
    });
  });

  group('window boundaries', () {
    test('just inside is contact, just outside is a miss', () {
      expect(
        swing(GameRules.timingWindow * 0.999).verdict,
        SwingVerdict.contact,
      );
      expect(swing(GameRules.timingWindow * 1.001).verdict, SwingVerdict.whiff);
    });

    test('EVERY club has the same window', () {
      // Timing is one skill, learned once. Clubs differ in power, spray,
      // carry and how hard an off-centre hit is punished — all of which
      // are choices — not in how hard they are to connect with at all,
      // which only made some of them worse.
      const inside = GameRules.timingWindow * 0.999;
      const outside = GameRules.timingWindow * 1.001;
      for (final club in Clubs.all) {
        expect(
          swing(inside, club: club).verdict,
          SwingVerdict.contact,
          reason: '${club.name} misses inside the window',
        );
        expect(
          swing(outside, club: club).verdict,
          SwingVerdict.whiff,
          reason: '${club.name} connects outside the window',
        );
      }
    });

    test('a slow pitch widens the window', () {
      final tight = resolver.resolve(
        timingError: 0.20,
        club: Clubs.stik,
        rock: Rocks.plain,
      );
      final slow = resolver.resolve(
        timingError: 0.20,
        club: Clubs.stik,
        rock: Rocks.plain,
        windowScale: 1.35,
      );
      expect(tight.verdict, SwingVerdict.whiff);
      expect(slow.verdict, SwingVerdict.contact);
    });
  });

  group('rocks change the swing', () {
    test('a heavy rock comes off the club slower', () {
      expect(
        swing(0, rock: Rocks.heavy).exitSpeed,
        lessThan(swing(0, rock: Rocks.light).exitSpeed),
      );
    });

    test('spinners bias the angle, and the two mirror each other', () {
      final left = swing(0, rock: Rocks.spinLeft).sprayDegrees;
      final right = swing(0, rock: Rocks.spinRight).sprayDegrees;
      expect(left, lessThan(0));
      expect(right, greaterThan(0));
      expect(left, closeTo(-right, 1e-9));
    });
  });

  group('a club names a range, not a number', () {
    test('the same swing does not always go the same distance', () {
      final speeds = {
        for (var i = 0; i < 40; i++)
          swing(0, jitter: 1).exitSpeed.toStringAsFixed(3),
      };
      expect(
        speeds.length,
        greaterThan(1),
        reason: 'identical swings produced identical contact',
      );
    });

    test('spread stays inside its band', () {
      final exact = swing(0).exitSpeed;
      for (var i = 0; i < 200; i++) {
        final v = swing(0, jitter: 1).exitSpeed;
        expect(
          (v - exact).abs() / exact,
          lessThanOrEqualTo(Clubs.stik.spread + 1e-9),
        );
      }
    });

    test('spread is a per-club property, not a global constant', () {
      // So a club can be made more or less reliable than another later,
      // without touching the resolver.
      expect(Clubs.all.every((c) => c.spread > 0), isTrue);
    });

    test('the straight club is much weaker off the line than any other', () {
      // WUNDERBAT reaches the wall on nearly any swing, so its distance
      // cannot vary. Its variation lives in the ANGLE instead: a low side
      // bite makes anything off the line feeble. It must own the lowest
      // side bite in the game, and clearly.
      final others = Clubs.all
          .where((c) => c != Clubs.wunderbat)
          .map((c) => c.sideBite);
      expect(
        Clubs.wunderbat.sideBite,
        lessThan(others.reduce((a, b) => a < b ? a : b) - 0.2),
      );
    });

    test('but a mis-timed swing still goes somewhere', () {
      // It used to be 0.30, which put a mis-timed WUNDERBAT six paces from
      // the plate — not "feeble off the line" but visibly broken, a huge
      // club producing a ball that dies at the batter's feet. sideBite is
      // the FLOOR on a swing (powerFactor == sideBite at the edge of the
      // window), so it decides how bad the worst contact looks.
      final edge = swing(
        GameRules.timingWindow,
        club: Clubs.wunderbat,
      ).exitSpeed;
      final centred = swing(0, club: Clubs.wunderbat).exitSpeed;
      expect(edge, lessThan(centred * 0.55), reason: 'identity lost');
      expect(
        edge,
        greaterThan(swing(0, club: Clubs.twig).exitSpeed * 0.9),
        reason: 'the worst WUNDERBAT should still outrun a centred TWIG',
      );
    });
  });

  group('clubs carry their identity', () {
    test('only the air club carries', () {
      expect(swing(0, club: Clubs.smak).carry, greaterThan(0));
      expect(swing(0, club: Clubs.kwik).carry, 0);
    });

    test('an air club is weaker than the ground clubs', () {
      // It cannot be cut off on the way, only where it lands, so it pays for
      // that safety in power — or it is never a bad pick.
      expect(Clubs.smak.power, lessThan(Clubs.kwik.power));
      expect(Clubs.smak.power, lessThan(Clubs.wunderbat.power));
    });
  });
}
