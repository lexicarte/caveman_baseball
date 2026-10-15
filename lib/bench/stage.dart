// The one place the benches turn a camera into pixels.
//
// Every tab draws THE GAME'S OWN renderers through this: the same
// FieldComponent, the same caveman painter, the same BallComponent, the
// same world transform the game sets up in Flame. A bench that drew its
// own approximation of the view would be a bench you could tune to look
// right while the game still looked wrong.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/caveman_baseball_game.dart';
import '../game/components/ball_component.dart';
import '../game/components/caveman.dart';
import '../game/components/caveman_cartoon.dart';
import '../game/components/field_component.dart';
import '../game/ground.dart';
import '../game/look.dart';
import '../model/player.dart';
import '../model/rock.dart';

/// Somebody standing on the field.
class StageFigure {
  const StageFigure({
    required this.x,
    required this.y,
    this.pose = const Pose.still(),
    this.club = false,
    this.archetype = Archetype.steady,
  });

  /// Field paces, not render units.
  final double x;
  final double y;
  final Pose pose;
  final bool club;
  final Archetype archetype;
}

/// The rock, where it is right now.
class StageRock {
  const StageRock({
    required this.x,
    required this.y,
    required this.lift,
    required this.rock,
  });

  final double x;
  final double y;
  final double lift;
  final Rock rock;
}

/// Draws the world at a given camera.
///
/// [cropToBand] frames it the way the game does — the strip of screen
/// between the scoreboard and the cards — so what you tune is what the
/// player gets. Off, it fills the box, which is how you find out what is
/// just out of shot.
class StagePainter extends CustomPainter {
  StagePainter({
    required this.zoom,
    required this.look,
    required this.figures,
    this.rock,
    this.cropToBand = true,
    this.swingArc,
    this.curve = SwingCurve.shipped,
    this.background = const Color(0xFF161210),
  });

  final double zoom;
  final double look;
  final List<StageFigure> figures;
  final StageRock? rock;
  final bool cropToBand;

  /// Where to draw the bat's path, if anywhere: the batter's field
  /// position. Shaping an arc you cannot see is guesswork.
  final Offset? swingArc;
  final SwingCurve curve;
  final Color background;

  static final _field = FieldComponent(spec: Look.now.fieldSpec);
  static const _man = CartoonCavemanPainter();
  static final _ball = BallComponent();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    // The playing BAND, at the game's aspect: the full screen width by the
    // fraction of its height that is not scoreboard or cards.
    const bandH = Ground.bandBottom - Ground.bandTop;
    final aspect = cropToBand ? (390 / 844) / bandH : size.width / size.height;
    final boxW = math.min(size.width, size.height * aspect);
    final boxH = boxW / aspect;
    final left = (size.width - boxW) / 2;
    final top = (size.height - boxH) / 2;

    final unit = boxW * zoom / Ground.viewportWidth;
    // The band's centre is not the screen's centre, so aim at the band.
    final worldCentre = cropToBand
        ? look +
              ((Ground.bandTop + Ground.bandBottom) / 2 - 0.5) *
                  (Ground.viewportHeight / zoom)
        : look;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(left, top, boxW, boxH));
    canvas.translate(left + boxW / 2, top + boxH / 2);
    canvas.scale(unit);
    canvas.translate(0, -worldCentre);

    _field
      ..spec = Look.now.fieldSpec
      ..zoom = zoom
      ..render(canvas);

    // Far men first, so a near one overlaps him rather than the reverse.
    final sorted = [...figures]..sort((a, b) => b.y.compareTo(a.y));
    for (final f in sorted) {
      _man.paint(
        canvas,
        ground: Offset(Ground.x(f.x, f.y), Ground.y(f.y)),
        archetype: f.archetype,
        height: Ground.figureHeightAt(zoom, f.y),
        holdingClub: f.club,
        detailed: true,
        pose: f.pose,
        curve: curve,
      );
    }

    if (swingArc != null) {
      final batterHeight = Ground.figureHeightAt(zoom, swingArc!.dy);
      final path = Path();
      for (var i = 0; i <= 90; i++) {
        final g = CartoonCavemanPainter.swingGeometry(
          batterHeight,
          Archetype.steady,
          i / 90,
          curve: curve,
        );
        final p = Offset(
          Ground.x(swingArc!.dx, swingArc!.dy) + g.tip.dx,
          Ground.y(swingArc!.dy) + g.tip.dy,
        );
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFD08B3A).withValues(alpha: 0.45)
          ..strokeWidth = batterHeight * 0.04
          ..style = PaintingStyle.stroke,
      );
    }

    if (rock != null) {
      _ball
        ..modelScale = Ground.modelScaleFor(zoom)
        ..hide()
        ..syncTo(rock!.x, rock!.y, rock!.rock, lift: rock!.lift)
        ..render(canvas);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StagePainter old) => true;
}

/// The batter, where the game draws him. Every tab needs him and none of
/// them should be guessing at his position.
StageFigure batterFigure({double? swingPhase}) => StageFigure(
  x: CavemanBaseballGame.batterX,
  y: CavemanBaseballGame.batterY,
  pose: swingPhase == null ? const Pose.still() : Pose.swing(swingPhase),
  club: true,
);
