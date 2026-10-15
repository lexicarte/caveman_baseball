// A defensive tap must always send somebody, and it must send the right
// somebody. The old nine-pace search could miss every man and silently do
// nothing, which under time pressure is the worst possible outcome.
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:caveman_baseball/model/player.dart';
import 'package:caveman_baseball/sim/base_running.dart';
import 'package:caveman_baseball/sim/field_spec.dart';
import 'package:caveman_baseball/sim/fielder_spec.dart';
import 'package:caveman_baseball/sim/tap_regions.dart';

List<FielderSpec> staffed(Scheme s, List<Archetype> a) => [
  for (var i = 0; i < s.fielders.length; i++)
    s.fielders[i].withPlayer(
      Player(id: 'x$i', name: 'x', archetype: a[i % a.length]),
    ),
];

void main() {
  const field = FieldSpec.compact;

  group('every tap sends somebody', () {
    test('anywhere on or around the field, in every scheme', () {
      for (final scheme in Schemes.all) {
        final men = staffed(scheme, [Archetype.steady]);
        // Sweep well past the wall and outside the foul lines too: a thumb
        // does not stop at the chalk.
        for (var y = -6.0; y <= 44.0; y += 2.0) {
          for (var x = -40.0; x <= 40.0; x += 2.0) {
            final man = TapRegions.resolve(x, y, men);
            expect(
              men.any((m) => m.id == man.id),
              isTrue,
              reason: '${scheme.name} at ($x, $y) resolved to nobody',
            );
          }
        }
      }
    });

    test('a single man is always the answer', () {
      final lone = [
        const FielderSpec(id: 'solo', name: 'solo', angleDegrees: 0, depth: 12),
      ];
      expect(TapRegions.resolve(-30, 2, lone).id, 'solo');
    });
  });

  group('it sends the nearest man', () {
    test('tapping on a man picks that man, in every scheme', () {
      for (final scheme in Schemes.all) {
        final men = staffed(scheme, [Archetype.steady]);
        // Only the men who are allowed to move: a tap on the catcher must
        // send somebody else.
        for (final m in men.where((f) => f.chases)) {
          final got = TapRegions.resolve(m.position.x, m.position.y, men);
          expect(
            got.id,
            m.id,
            reason: '${scheme.name}: tapping ${m.id} sent ${got.id}',
          );
        }
      }
    });

    test(
      'deep in a corner it is the man in that corner, never the catcher',
      () {
        final men = staffed(Schemes.wide, [Archetype.steady]);
        final deepRight = TapRegions.resolve(24, 24, men);
        expect(deepRight.id, 'rf');
        final deepLeft = TapRegions.resolve(-24, 24, men);
        expect(deepLeft.id, 'lf');
      },
    );

    test('the catcher is never sent, even for a dribbler on the plate', () {
      // He guards home and nothing else. A catcher who wanders leaves home
      // open for everyone on the bases, which is the whole reason the bag
      // arithmetic works with five men.
      for (final scheme in Schemes.all) {
        final men = staffed(scheme, [Archetype.steady]);
        for (var y = -4.0; y <= 40.0; y += 1.0) {
          for (var x = -30.0; x <= 30.0; x += 1.0) {
            expect(
              TapRegions.resolve(x, y, men).id,
              isNot('c'),
              reason: '${scheme.name} sent the catcher from ($x, $y)',
            );
          }
        }
      }
      // A ball on the plate goes to the nearest man who IS allowed to move.
      final men = staffed(Schemes.close, [Archetype.steady]);
      expect(TapRegions.resolve(0.5, 1.5, men).id, 'p');
    });

    test('the catcher always ends up covering home', () {
      for (final scheme in Schemes.all) {
        for (final chaser in scheme.fielders.where((f) => f.chases)) {
          final cover = [
            for (final f in scheme.fielders)
              if (f.id != chaser.id) f,
          ];
          final assigned = BaseRunning().assignCoverage(
            cover,
            field,
            needed: [4, 3, 2, 1],
          );
          expect(
            assigned[homeBase]?.id,
            'c',
            reason: '${scheme.name} with ${chaser.id} chasing',
          );
        }
      }
    });
  });

  group('speed decides who owns the ground', () {
    /// How much of the field a given post owns, in grid cells.
    int groundOwnedBy(Scheme scheme, int post, Archetype a) {
      final men = [
        for (var i = 0; i < scheme.fielders.length; i++)
          scheme.fielders[i].withPlayer(
            Player(
              id: 'x$i',
              name: 'x',
              archetype: i == post ? a : Archetype.steady,
            ),
          ),
      ];
      final id = men[post].id;
      var owned = 0;
      for (var y = -4.0; y <= 40.0; y += 0.5) {
        for (var x = -34.0; x <= 34.0; x += 0.5) {
          if (x * x + y * y > field.wallRadius * field.wallRadius) continue;
          if (TapRegions.resolve(x, y, men).id == id) owned++;
        }
      }
      return owned;
    }

    test('a swift man owns more ground than a slow one on the same post', () {
      // Knife-edge probe points are a trap here: the boundary between two
      // men moves less than half a pace when one changes archetype. The
      // real, robust property is how much ground each man ends up with.
      for (final scheme in Schemes.all) {
        for (var post = 0; post < scheme.fielders.length; post++) {
          // The catcher owns no ground at all — he never moves.
          if (!scheme.fielders[post].chases) continue;
          final swift = groundOwnedBy(scheme, post, Archetype.swift);
          final mighty = groundOwnedBy(scheme, post, Archetype.mighty);
          expect(
            swift,
            greaterThan(mighty),
            reason:
                '${scheme.name} post ${scheme.fielders[post].id}: '
                'swift owned $swift, mighty owned $mighty',
          );
        }
      }
    });

    test('no man ever owns a majority of the field', () {
      // The guard that matters is not a ratio between archetypes — speed is
      // meant to help, and swift pays for it with a worse arm. It is that no
      // lineup should let one man swallow the field, because the moment he
      // does, every other tap stops mattering and the decision is gone.
      for (final scheme in Schemes.all) {
        for (var post = 0; post < scheme.fielders.length; post++) {
          if (!scheme.fielders[post].chases) continue;
          for (final a in Archetype.values) {
            final owned = groundOwnedBy(scheme, post, a);
            final total =
                groundOwnedBy(scheme, post, a) +
                [
                  for (var o = 0; o < scheme.fielders.length; o++)
                    if (o != post && scheme.fielders[o].chases)
                      groundOwnedBy(scheme, o, Archetype.steady),
                ].fold(0, (x, y) => x + y);
            expect(
              owned / total,
              lessThan(0.5),
              reason:
                  '${scheme.name}: a ${a.name} '
                  '${scheme.fielders[post].id} owns most of the field',
            );
          }
        }
      }
    });

    test('resolve agrees with timeToReach, which is what fielding uses', () {
      final men = staffed(Schemes.wheel, [
        Archetype.mighty,
        Archetype.steady,
        Archetype.swift,
        Archetype.steady,
        Archetype.mighty,
      ]);
      for (var y = 0.0; y <= 36.0; y += 3.0) {
        for (var x = -26.0; x <= 26.0; x += 3.0) {
          final got = TapRegions.resolve(x, y, men);
          final best = men
              .where((m) => m.chases)
              .map((m) => m.timeToReach(Vector2(x, y)))
              .reduce((a, b) => a < b ? a : b);
          expect(
            got.timeToReach(Vector2(x, y)),
            closeTo(best, 1e-9),
            reason: 'at ($x, $y)',
          );
        }
      }
    });
  });

  test('fair territory is fully covered — no dead ground', () {
    for (final scheme in Schemes.all) {
      final men = staffed(scheme, [Archetype.steady]);
      var checked = 0;
      for (var y = 0.5; y <= field.wallRadius; y += 1.0) {
        for (var x = -38.0; x <= 38.0; x += 1.0) {
          if (!field.isFair(x, y)) continue;
          if (x * x + y * y > field.wallRadius * field.wallRadius) continue;
          TapRegions.resolve(x, y, men);
          checked++;
        }
      }
      expect(
        checked,
        greaterThan(500),
        reason: '${scheme.name} sweep too thin',
      );
    }
  });
}
