// Draws the playfield on the tilted ground plane.
//
// The wedge, the infield and the bases are all squashed vertically; only the
// figures standing on them are not.
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../sim/base_running.dart';
import '../../sim/field_spec.dart';
import '../art/art_style.dart';
import '../ground.dart';
import '../look.dart';

class FieldComponent extends PositionComponent {
  FieldComponent({required this.spec}) : super(priority: 0);

  /// Replaceable so the tuning bench can hand it a new field every frame
  /// as the distance sliders move.
  FieldSpec spec;

  /// The camera's zoom. Bases and standing stones are MODELS and scale with
  /// the figures; the wedge, the chalk and the base paths are the field
  /// itself and do not.
  double zoom = Ground.wideZoom;

  double get _model => Ground.modelScaleFor(zoom);

  /// The mound, in paces across. It is ground, not a model, so it does NOT
  /// scale with the figures — but it was sized by eye against figures three
  /// times bigger than they are now, and at 8 paces it swallowed the whole
  /// infield. A real mound is about 18 feet across against a 60-foot walk
  /// to the plate; this is the same fraction of ten paces.
  static const double moundWidth = 3.2;

  /// The dirt apron. Has to clear second base with room, or the bag sits
  /// on the grass line and the diamond looks too big for the infield it is
  /// drawn in. Tuned, like every other distance on this field.
  static double get infieldRadius => Look.now.infieldRadius;

  /// A bag, in paces across, before the zoom and the distance have their
  /// say. Deliberately oversized — they are landmarks, not scale models —
  /// but 3.4 was set against a man drawn three times taller than he is
  /// now, and read as paving slabs.
  static const double bagWidth = 2.6;

  /// Where the painted backdrop meets the ground: a little behind the
  /// wall, which is as far as anyone can see from the plate. See the note
  /// in `_renderCartoon` for why this is not `Ground.horizonY`.
  double get _skyline =>
      Ground.y(spec.wallRadius) - 3.0 * Ground.depthScale(spec.wallRadius);

  /// Everything painted on the backdrop — mesas, the sun — is sized
  /// against the WALL, by scaling it the same way the wall is scaled.
  /// These were laid out in absolute paces back when the plane was a flat
  /// shear; with the camera set back, the wall shrinks to half its width
  /// and a mesa that does not shrink with it becomes a brown slab across
  /// the whole frame.
  double get _backdrop => Ground.depthScale(spec.wallRadius);

  /// The fair wedge, squashed. Built from points rather than an arc command
  /// because an ellipse arc through a squash is easier to get right by
  /// sampling than by trusting the sweep flags.
  Path _wedge(double radius) {
    final foul = spec.foulAngleRadians;
    final p = Path()..moveTo(Ground.x(0), Ground.y(0));
    const steps = 48;
    for (var i = 0; i <= steps; i++) {
      final a = -foul + (2 * foul) * (i / steps);
      p.lineTo(
        Ground.x(math.sin(a) * radius, math.cos(a) * radius),
        Ground.y(math.cos(a) * radius),
      );
    }
    return p..close();
  }

  // --- cartoon ------------------------------------------------------
  static const _ink = Color(0xFF1E1710);
  static const _cGrass = Color(0xFF7FA845);
  static const _cGrassDeep = Color(0xFF6B9239);
  static const _cDirt = Color(0xFFC98D4E);
  static const _cChalk = Color(0xFFFFF6E0);
  static const _cPath = Color(0xFFE0B87E);
  static const _cStone = Color(0xFF9A9183);
  static const _cStoneTop = Color(0xFFB6AD9C);
  static const _cPlain = Color(0xFFD9A45E);
  static const _cMesa = Color(0xFFA9714F);
  static const _cMesaFar = Color(0xFFC79C86);
  static const _cSky = Color(0xFFF2C878);
  static const _cSun = Color(0xFFFBE6B0);

  /// A point on the field, given as a distance and a bearing from home.
  /// Goes through the full projection, so the further out it is the
  /// nearer the middle and the nearer the horizon it lands.
  Offset _at(double r, double aDeg) {
    final a = aDeg * math.pi / 180;
    final depth = math.cos(a) * r;
    return Offset(Ground.x(math.sin(a) * r, depth), Ground.y(depth));
  }

  /// Flat fills, one heavy outline, and the four cues that make a wedge of
  /// green read as a ball field: foul lines, a diamond with its base paths
  /// drawn in, a wall on the arc, and standing stones behind the plate.
  void _renderCartoon(Canvas canvas) {
    final ink = Paint()
      ..color = _ink
      ..strokeWidth = 0.28
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Rock country behind the wall. Deliberately far larger than the
    // camera ever shows: it pushes in to 1.72x during a pitch, and a
    // backdrop that stops leaves a black band across the screen.
    const far = 400.0;
    // A PAINTED skyline sitting just behind the wall, not the projection's
    // true horizon.
    //
    // `Ground.horizonY` is where ground infinitely far away converges, and
    // with the camera set back it is a long way off the top of the frame —
    // so drawing the sky above it means the player never sees sky at all,
    // only an enormous apron of desert floor above the wall. The wall is
    // what actually occludes the horizon here, exactly as a real outfield
    // wall does, so the backdrop starts there. The margin shrinks with
    // distance like everything else.
    final horizon = _skyline;
    canvas.drawRect(
      Rect.fromLTRB(-far, -far, far, horizon + 1),
      Paint()..color = _cSky,
    );
    final b = _backdrop;
    canvas.drawCircle(
      Offset(16 * b, horizon - 13 * b),
      5.5 * b,
      Paint()..color = _cSun,
    );
    canvas.drawRect(
      Rect.fromLTRB(-far, horizon, far, far),
      Paint()..color = _cPlain,
    );
    for (final m in const [
      [-96.0, -82.0, -62.0, -50.0, 13.0],
      [-54.0, -40.0, -26.0, -18.0, 11.0],
      [-22.0, -12.0, 8.0, 16.0, 7.0],
      [18.0, 27.0, 45.0, 54.0, 12.0],
      [50.0, 62.0, 84.0, 98.0, 9.0],
    ]) {
      final top = horizon - m[4] * b;
      canvas.drawPath(
        Path()
          ..moveTo(m[0] * b, horizon + 1)
          ..lineTo(m[1] * b, top)
          ..lineTo(m[2] * b, top - 0.8 * b)
          ..lineTo(m[3] * b, horizon + 1)
          ..close(),
        Paint()..color = m[4] > 10 ? _cMesaFar : _cMesa,
      );
    }

    canvas.drawPath(_wedge(spec.wallRadius), Paint()..color = _cGrass);
    final deep = Path.combine(
      PathOperation.difference,
      _wedge(spec.wallRadius),
      _wedge(spec.wallRadius * 0.70),
    );
    canvas.drawPath(deep, Paint()..color = _cGrassDeep);
    canvas.drawPath(_wedge(spec.wallRadius), ink);

    canvas.drawPath(_wedge(infieldRadius), Paint()..color = _cDirt);
    canvas.drawPath(_wedge(infieldRadius), ink);

    // Chalk down both lines.
    final chalk = Paint()
      ..color = _cChalk
      ..strokeWidth = 0.34
      ..strokeCap = StrokeCap.round;
    for (final sign in [-1.0, 1.0]) {
      canvas.drawLine(
        _at(0, 0),
        _at(spec.wallRadius, sign * spec.foulAngleDegrees),
        chalk,
      );
    }

    // The diamond, with its base paths actually drawn in. This is the cue
    // that does the most work — without it the wedge reads as nothing.
    final diamond = Path()..moveTo(Ground.x(0), Ground.y(0));
    for (final b in [firstBase, secondBase, thirdBase]) {
      final p = basePosition(b, spec);
      diamond.lineTo(Ground.x(p.x, p.y), Ground.y(p.y));
    }
    diamond.close();
    canvas.drawPath(
      diamond,
      Paint()
        ..color = _cPath
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      diamond,
      Paint()
        ..color = _cChalk
        ..strokeWidth = 0.3
        ..style = PaintingStyle.stroke,
    );

    // The mound, drawn where the thrower actually stands. `Scheme.moundAt`
    // puts him here; these two must be given the same number or he floats
    // beside the dirt.
    final mound = Ground.groundOval(0, spec.moundDistance, moundWidth / 2);
    canvas.drawOval(mound, Paint()..color = _cDirt);
    canvas.drawOval(mound, ink);

    // Boulder wall along the arc.
    const boulders = 18;
    for (var i = 0; i <= boulders; i++) {
      final a =
          -spec.foulAngleDegrees + 2 * spec.foulAngleDegrees * (i / boulders);
      final c = _at(spec.wallRadius, a);
      final k = Ground.depthScale(
        math.cos(a * math.pi / 180) * spec.wallRadius,
      );
      final w = (2.3 + (i % 3) * 0.22) * k;
      final r = Rect.fromCenter(center: c, width: w * 2, height: w * 1.2);
      canvas.drawOval(r, Paint()..color = _cStone);
      canvas.drawOval(r, ink);
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(-w * 0.16, -w * 0.22),
          width: w,
          height: w * 0.5,
        ),
        Paint()..color = _cStoneTop,
      );
    }

    // Standing stones behind the plate.
    for (var i = 0; i < 7; i++) {
      final a = (-72 + 144 * i / 6) * math.pi / 180;
      final depth = -2.2 - math.cos(a) * 0.7;
      final x = Ground.x(math.sin(a) * 5.4, depth);
      final yb = Ground.y(depth);
      // In FRONT of the plate, so they are drawn bigger, not smaller.
      final k = Ground.depthScale(depth);
      final w = (0.8 + (i % 3) * 0.15) * k;
      final hgt = (1.3 + (i % 4) * 0.28) * k;
      final stone = Path()
        ..moveTo(x - w, yb)
        ..lineTo(x - w * 0.72, yb - hgt)
        ..lineTo(x + w * 0.5, yb - hgt * 0.9)
        ..lineTo(x + w, yb)
        ..close();
      canvas.drawPath(stone, Paint()..color = _cStone);
      canvas.drawPath(stone, ink);
    }

    // Oversized chunky bags.
    for (final b in [firstBase, secondBase, thirdBase, homeBase]) {
      final p = basePosition(b, spec);
      final m = _model * Ground.depthScale(p.y);
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(Ground.x(p.x, p.y), Ground.y(p.y)),
          width: bagWidth * m,
          height: bagWidth * m * Ground.squash,
        ),
        Radius.circular(0.4 * m),
      );
      canvas.drawRRect(r, Paint()..color = _cChalk);
      canvas.drawRRect(r, ink);
    }
  }

  // --- pixel --------------------------------------------------------
  static const _pGrass = Color(0xFF5E8038);
  static const _pGrassDeep = Color(0xFF4F6B2E);
  static const _pDirt = Color(0xFFA9713F);
  static const _pDirtDeep = Color(0xFF8E5C32);
  static const _pChalk = Color(0xFFEFE3C2);
  static const _pStone = Color(0xFF6E6256);
  static const _pStoneTop = Color(0xFF9A8C7A);
  static const _pSky = Color(0xFFD9B27A);
  static const _pPlain = Color(0xFFB0824E);
  static const _pPath = Color(0xFFC59A63);

  /// One pixel cell, in world units. A figure is 14 cells tall, so this is
  /// the grid everything else has to sit on or the style falls apart.
  double get _cell => Ground.figureHeight * 1.04 / 14;

  /// Fills [path] with horizontal bands that step between two tones. A
  /// tilted plane in pixel art IS the stepping — it is the style, not an
  /// artefact of drawing it badly.
  void _banded(Canvas canvas, Path path, Color a, Color b) {
    final r = path.getBounds();
    final band = _cell * 2;
    canvas.save();
    canvas.clipPath(path);
    var y = r.top;
    var i = 0;
    while (y < r.bottom) {
      canvas.drawRect(
        Rect.fromLTWH(r.left, y, r.width, band + 0.02),
        Paint()..color = i.isEven ? a : b,
      );
      y += band;
      i++;
    }
    canvas.restore();
  }

  void _block(
    Canvas canvas,
    double cx,
    double cy,
    double w,
    double h,
    Color fill,
  ) {
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
      Paint()..color = fill,
    );
  }

  void _renderPixel(Canvas canvas) {
    const far = 400.0;
    final horizon = _skyline;
    canvas.drawRect(
      Rect.fromLTRB(-far, -far, far, horizon + 1),
      Paint()..color = _pSky,
    );
    canvas.drawRect(
      Rect.fromLTRB(-far, horizon, far, far),
      Paint()..color = _pPlain,
    );
    // Mesas, stepped rather than sloped.
    final b = _backdrop;
    for (final m in const [
      [-46.0, 13.0],
      [-14.0, 8.0],
      [22.0, 12.0],
      [52.0, 9.0],
    ]) {
      final steps = (m[1] * b / (_cell * 2)).round().clamp(2, 14);
      for (var i = 0; i < steps; i++) {
        final w = (26.0 - i * (18.0 / steps)) * b;
        _block(
          canvas,
          m[0] * b,
          horizon - i * _cell * 2,
          w,
          _cell * 2.05,
          i > steps * 0.6 ? const Color(0xFFC19C83) : const Color(0xFF9E7D6E),
        );
      }
    }

    _banded(canvas, _wedge(spec.wallRadius), _pGrass, _pGrassDeep);
    _banded(canvas, _wedge(infieldRadius), _pDirt, _pDirtDeep);

    final chalk = Paint()
      ..color = _pChalk
      ..strokeWidth = _cell
      ..style = PaintingStyle.stroke;
    for (final sign in [-1.0, 1.0]) {
      final a = sign * spec.foulAngleRadians;
      final depth = math.cos(a) * spec.wallRadius;
      canvas.drawLine(
        Offset(Ground.x(0), Ground.y(0)),
        Offset(Ground.x(math.sin(a) * spec.wallRadius, depth), Ground.y(depth)),
        chalk,
      );
    }

    // The diamond, with its base paths drawn in — the cue that makes a
    // wedge of green read as a ball field at all.
    final diamond = Path()..moveTo(Ground.x(0), Ground.y(0));
    for (final b in [firstBase, secondBase, thirdBase]) {
      final p = basePosition(b, spec);
      diamond.lineTo(Ground.x(p.x, p.y), Ground.y(p.y));
    }
    diamond.close();
    canvas.drawPath(
      diamond,
      Paint()
        ..color = _pPath
        ..strokeWidth = _cell * 4
        ..style = PaintingStyle.stroke,
    );

    // Wall: square blocks on the arc, not smooth boulders.
    const blocks = 22;
    for (var i = 0; i <= blocks; i++) {
      final a =
          -spec.foulAngleRadians + 2 * spec.foulAngleRadians * (i / blocks);
      final depth = math.cos(a) * spec.wallRadius;
      final cx = Ground.x(math.sin(a) * spec.wallRadius, depth);
      final cy = Ground.y(depth);
      final k = Ground.depthScale(depth);
      _block(canvas, cx, cy, _cell * 7 * k, _cell * 4 * k, _pStone);
      _block(canvas, cx, cy - _cell * k, _cell * 5 * k, _cell * 2 * k,
          _pStoneTop);
    }

    // Standing stones behind the plate.
    for (var i = 0; i < 7; i++) {
      final a = (-72 + 144 * i / 6) * math.pi / 180;
      final depth = -2.2 - math.cos(a) * 0.7;
      final cx = Ground.x(math.sin(a) * 5.4, depth);
      final cy = Ground.y(depth);
      final k = Ground.depthScale(depth);
      final hgt = _cell * (4 + (i % 3) * 2) * k;
      _block(canvas, cx, cy - hgt / 2, _cell * 3 * k, hgt, _pStone);
    }

    for (final b in [firstBase, secondBase, thirdBase, homeBase]) {
      final p = basePosition(b, spec);
      final m = _model * Ground.depthScale(p.y);
      _block(
        canvas,
        Ground.x(p.x, p.y),
        Ground.y(p.y),
        _cell * 4 * m,
        _cell * 2.4 * m,
        _pChalk,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    if (artStyle.value == ArtStyle.cartoon) {
      _renderCartoon(canvas);
    } else {
      _renderPixel(canvas);
    }
  }
}
