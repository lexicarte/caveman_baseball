// The fake 3D.
//
// `Ground` is the only place field coordinates become screen coordinates,
// and the perspective lives entirely in one factor. These assertions ARE
// the view: if one breaks, the camera has moved and that should be a
// decision rather than a surprise.
import 'package:caveman_baseball/game/ground.dart';
import 'package:caveman_baseball/game/look.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(Look.now.reset);
  tearDown(Look.now.reset);

  group('the camera is behind the plate, looking down the field', () {
    test('home plate does not move whatever the camera does', () {
      final at38 = Ground.y(0);
      Look.now.camDepth = 14;
      expect(Ground.y(0), closeTo(at38, 1e-9));
      Look.now.camDepth = 150;
      expect(Ground.y(0), closeTo(at38, 1e-9));
    });

    test('depth compresses: equal paces take less screen the further out', () {
      final near = Ground.y(0) - Ground.y(10);
      final far = Ground.y(30) - Ground.y(40);
      expect(far, lessThan(near * 0.75), reason: 'no perspective in depth');
      expect(far, greaterThan(0), reason: 'the field folded over itself');
    });

    test('width converges: the foul lines lean in', () {
      // Ten paces across is worth fewer render units at the wall than at
      // the plate. This is the cue that reads as "standing behind home".
      expect(Ground.x(10, 38).abs(), lessThan(Ground.x(10, 0).abs() * 0.75));
    });

    test('things in FRONT of the plate are nearer, so bigger', () {
      // The backstop really is closer to the camera than the batter is.
      expect(Ground.depthScale(-2.2), greaterThan(1.0));
    });

    test('a man is drawn smaller the further out he stands', () {
      final batter = Ground.figureHeightAt(Ground.tightZoom, 0);
      final pitcher = Ground.figureHeightAt(
        Ground.tightZoom,
        Look.now.moundDistance,
      );
      final deep = Ground.figureHeightAt(Ground.tightZoom, 38);
      expect(pitcher, lessThan(batter));
      expect(deep, lessThan(pitcher));
      // ...but still worth drawing. A man who renders at a third of the
      // batter has lost the eyes the cartoon style needs.
      expect(deep / batter, greaterThan(0.35));
    });
  });

  group('the horizon', () {
    test('every point on the field lands below it', () {
      for (final d in [0.0, 10.0, 38.0, 200.0, 1e6]) {
        expect(
          Ground.y(d),
          greaterThan(Ground.horizonY),
          reason: 'depth $d is at or above the horizon',
        );
      }
    });

    test('the far field converges ON it rather than past it', () {
      expect(Ground.y(1e9), closeTo(Ground.horizonY, 0.01));
    });

    test('a tap above it is nowhere on the field', () {
      expect(Ground.fieldY(Ground.horizonY - 1).isFinite, isFalse);
    });
  });

  group('the projection inverts', () {
    test('a depth survives the round trip', () {
      for (final d in [-2.0, 0.0, 1.0, 11.273, 23.0, 38.0]) {
        expect(Ground.fieldY(Ground.y(d)), closeTo(d, 1e-6), reason: '$d');
      }
    });

    test('so does a point off the middle', () {
      for (final d in [0.0, 12.0, 30.0]) {
        for (final fx in [-14.0, 0.0, 9.5]) {
          expect(
            Ground.fieldX(Ground.x(fx, d), d),
            closeTo(fx, 1e-6),
            reason: '($fx, $d)',
          );
        }
      }
    });
  });

  test('setting the camera far back IS the old flat shear', () {
    // The dial spans both looks, so there is no second mode to maintain
    // and no way for the two to disagree.
    Look.now.camDepth = 1e7;
    for (final d in [0.0, 10.0, 38.0]) {
      expect(
        Ground.y(d),
        closeTo(Look.now.plateY - Look.now.squash * d, 1e-3),
        reason: '$d',
      );
      expect(Ground.x(10, d), closeTo(10, 1e-3), reason: '$d');
    }
  });

  test('model size does not follow the fielding camera', () {
    // `modelScaleFor` divided by `figureHeightWide` once, which made
    // re-aiming the wide camera resize every bag and the rock with it.
    Look.now.reset();
    final atBat = Ground.modelScaleFor(Ground.tightZoom);
    Look.now.figureHeightWide = Look.now.figureHeightWide * 2;
    expect(Ground.modelScaleFor(Ground.tightZoom), closeTo(atBat, 1e-9));
  });

  test('nothing divides by zero at or behind the camera', () {
    for (final d in [-Look.now.camDepth, -1e6, -0.0]) {
      expect(Ground.depthScale(d).isFinite, isTrue, reason: '$d');
      expect(Ground.y(d).isFinite, isTrue, reason: '$d');
    }
  });
}
