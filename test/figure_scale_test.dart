// The FIELD caveman is 48pt on the reference phone, and the portrait band
// still has room for him and for his swing.
import 'package:caveman_baseball/game/caveman_baseball_game.dart';
import 'package:caveman_baseball/game/components/caveman.dart';
import 'package:caveman_baseball/game/components/caveman_cartoon.dart';
import 'package:caveman_baseball/game/ground.dart';
import 'package:caveman_baseball/game/look.dart';
import 'package:caveman_baseball/model/player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(Look.now.reset);
  tearDown(Look.now.reset);

  test('a steady man is 48pt at the at-bat on a 390pt phone', () {
    expect(Ground.viewportWidth, 67);
    expect(CavemanPainter.steadyDrawnFactor, LookDefaults.steadyDrawnFactor);
    expect(
      CavemanPainter.drawnHeightFactor(Archetype.steady),
      LookDefaults.steadyDrawnFactor,
    );
    expect(
      LookDefaults.figureHeightTight,
      closeTo(
        LookDefaults.fieldFigurePoints *
            Ground.viewportWidth /
            (LookDefaults.steadyDrawnFactor *
                LookDefaults.referenceScreenWidth *
                LookDefaults.tightZoom),
        1e-9,
      ),
    );

    final points =
        Ground.figureHeightTight *
        CavemanPainter.drawnHeightFactor(Archetype.steady) *
        Ground.referencePixelsPerUnit(Ground.tightZoom);
    expect(points, closeTo(LookDefaults.fieldFigurePoints, 1e-6));
    expect(points, closeTo(48, 1e-6));
  });

  test('body widths stay SWIFT 0.74, STEADY 1, MIGHTY 1.34', () {
    expect(CartoonCavemanPainter.bodyWidthOf(Archetype.swift), 0.74);
    expect(CartoonCavemanPainter.bodyWidthOf(Archetype.steady), 1);
    expect(CartoonCavemanPainter.bodyWidthOf(Archetype.mighty), 1.34);
    // Build is a different knob. It still drives height and the stride.
    expect(CavemanPainter.buildFor(Archetype.swift), isNot(0.74));
    expect(CavemanPainter.buildFor(Archetype.mighty), isNot(1.34));
  });

  test('fielding men stay the size that keeps stacked fielders apart', () {
    // CLOSE's centre fielder stands just up the field from the thrower.
    // The gap between their feet is about one fielding-size body. Scaling
    // that size with the 48pt at-bat art puts the fielder's feet in the
    // thrower's head, so the wide height stays put.
    expect(LookDefaults.figureHeightWide, 2.1);
    final widePoints =
        Ground.figureHeightWide *
        CavemanPainter.drawnHeightFactor(Archetype.steady) *
        Ground.referencePixelsPerUnit(Ground.wideZoom);
    expect(widePoints, lessThan(LookDefaults.fieldFigurePoints));

    const throwerDepth = 11.273;
    const centreDepth = 16.0;
    final ppu = Ground.referencePixelsPerUnit(Ground.wideZoom);
    final gap = (Ground.y(throwerDepth) - Ground.y(centreDepth)) * ppu;
    final thrower = CavemanPainter.drawnHeight(
      Archetype.steady,
      Ground.figureHeightAt(Ground.wideZoom, throwerDepth),
    );
    expect(
      gap,
      greaterThan(thrower * ppu),
      reason: 'centre fielder overlaps the thrower at the fielding camera',
    );
  });

  test('the at-bat figure and his swing stay inside the field band', () {
    final zoom = Ground.tightZoom;
    final look = Ground.tightLook;
    final ppu = Ground.referencePixelsPerUnit(zoom);
    final top = Ground.worldYOnScreen(
      zoom: zoom,
      look: look,
      fractionDown: Ground.bandTop,
    );
    final bottom = Ground.worldYOnScreen(
      zoom: zoom,
      look: look,
      fractionDown: Ground.bandBottom,
    );

    final feetY = CavemanBaseballGame.batterY;
    final height = Ground.figureHeightAt(zoom, feetY);
    final h = CavemanPainter.drawnHeight(Archetype.steady, height);
    final feet = Ground.y(feetY);
    final head = feet - h;

    var low = feet;
    var widest = 0.0;
    final feetX = Ground.x(CavemanBaseballGame.batterX, feetY);
    for (final archetype in Archetype.values) {
      for (var i = 0; i <= 60; i++) {
        final g = CartoonCavemanPainter.swingGeometry(
          height,
          archetype,
          i / 60,
        );
        final tipY = feet + g.tip.dy;
        if (tipY > low) low = tipY;
        final tipX = (feetX + g.tip.dx).abs();
        if (tipX > widest) widest = tipX;
      }
    }

    // Points of air between the drawing and the HUD. The head grows up
    // into open field; the swing is what approaches the cards.
    const margin = 24.0;
    expect(
      (head - top) * ppu,
      greaterThan(margin),
      reason: 'head under the scoreboard',
    );
    expect(
      (bottom - low) * ppu,
      greaterThan(margin),
      reason: 'swing above the cards',
    );
    expect(
      (bottom - feet) * ppu,
      greaterThan(margin),
      reason: 'feet above the cards',
    );

    final half = Ground.viewportWidth / (2 * zoom);
    expect(half - widest, greaterThan(1), reason: 'club leaves the screen');

    // The thrower is the other man the at-bat has to show.
    final mound = Look.now.moundDistance;
    final pitcherFeet = Ground.y(mound);
    final pitcherHead =
        pitcherFeet -
        CavemanPainter.drawnHeight(
          Archetype.steady,
          Ground.figureHeightAt(zoom, mound),
        );
    expect(pitcherHead, greaterThan(top));
    expect(pitcherFeet, lessThan(bottom));
  });
}
