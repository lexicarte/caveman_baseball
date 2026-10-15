// The same man, drawn flat.
//
// One heavy outline, solid fills, nothing shaded inside the line. Original
// tribe: sun-baked tan skin, not the yellow of any show.
//
// Proportions are deliberately NOT the classic painter's. A cartoon head is
// about a fifth of the body and the eyes are enormous, which is what makes a
// silhouette read at speed. The one thing that is shared is the leg swing:
// stride amplitude comes from CavemanPainter so the foot-slip arithmetic in
// runCycleSecondsFor stays true for both styles.
import 'dart:math' as math;
import 'dart:ui';

import '../../model/player.dart';
import 'caveman.dart';

/// The shape of a swing.
///
/// Pulled out of the painter so the arc can be tuned without editing a
/// curve by hand and rebuilding. The six numbers are the whole shape:
/// where the bat starts and ends, where in that sweep it meets the ball,
/// what fraction of the TIME is spent getting there, and how the speed
/// ramps on either side of it.
class SwingCurve {
  const SwingCurve({
    this.back = -2.7,
    this.through = -5.7,
    this.contactAt = 0.67,
    this.whip = 0.30,
    this.approach = 0.72,
    this.follow = 1.05,
  });

  /// Club angle at the load and at the end of the follow-through, in
  /// radians, zero straight up and +x at +pi/2. DECREASING is
  /// counterclockwise on screen, which is what a right-hander does.
  final double back;
  final double through;

  /// How far through the ARC the bat meets the ball.
  final double contactAt;

  /// How much of the swing's TIME is spent reaching that point.
  ///
  /// This is the lag between the tap and the bat visibly arriving. Easing
  /// into the swing once put it at 180ms and a perfectly timed swing
  /// looked late; the honest response to that is to swing earlier and
  /// miss.
  final double whip;

  /// Speed ramp before contact (below 1 whips, above 1 drags) and after.
  /// The follow-through wants to stay near 1: ease it hard and seven of
  /// every eight frames are the same picture of a bat already stopped.
  final double approach;
  final double follow;

  static const shipped = SwingCurve();

  double ease(double t) {
    if (t < whip) {
      return contactAt * math.pow(t / whip, approach).toDouble();
    }
    final u = (t - whip) / (1 - whip);
    return contactAt + (1 - contactAt) * math.pow(u, follow).toDouble();
  }

  double angleAt(double t) => back + (through - back) * ease(t);

  SwingCurve copyWith({
    double? back,
    double? through,
    double? contactAt,
    double? whip,
    double? approach,
    double? follow,
  }) => SwingCurve(
    back: back ?? this.back,
    through: through ?? this.through,
    contactAt: contactAt ?? this.contactAt,
    whip: whip ?? this.whip,
    approach: approach ?? this.approach,
    follow: follow ?? this.follow,
  );
}

class CartoonCavemanPainter {
  const CartoonCavemanPainter();

  static const ink = Color(0xFF1E1710);
  static const _skin = Color(0xFFD99A5B);
  static const _club = Color(0xFF8A5A32);
  static const _rock = Color(0xFFDED6C4);
  static const _ochre = Color(0xFFC4692A);
  static const _shadow = Color(0x3A1E1710);

  static Color hideFor(Archetype a) => switch (a) {
    Archetype.swift => const Color(0xFFD8C79E),
    Archetype.steady => const Color(0xFFA8794A),
    Archetype.mighty => const Color(0xFF5E4028),
  };

  static Color hairFor(Archetype a) => switch (a) {
    Archetype.swift => const Color(0xFF6B4A2E),
    Archetype.steady => const Color(0xFF3B2A1C),
    Archetype.mighty => const Color(0xFF2A1C12),
  };

  /// Body width, head size, limb thickness and beard size by build.
  static ({double body, double head, double limb, double beard}) _dims(
    Archetype a,
  ) => switch (a) {
    Archetype.swift => (body: 0.74, head: 0.92, limb: 0.82, beard: 0.80),
    Archetype.steady => (body: 1.00, head: 1.00, limb: 1.00, beard: 1.00),
    Archetype.mighty => (body: 1.34, head: 1.04, limb: 1.22, beard: 1.22),
  };

  /// Where the club's hand and tip are at swing phase [t], as offsets from
  /// the man's FEET. Exposed so the calibration chart measures the real arc
  /// instead of a second copy of these numbers that can drift from it.
  static ({Offset hand, Offset tip}) swingGeometry(
    double height,
    Archetype archetype,
    double t, {
    SwingCurve curve = SwingCurve.shipped,
  }) {
    final build = CavemanPainter.buildFor(archetype);
    final h = height * (0.92 + 0.12 * build);
    final d = _dims(archetype);
    final bodyHalf = h * 0.17 * d.body;
    final shoulderDy = -h + 0.44 * h;
    final a = curve.angleAt(t);
    final hand = Offset(
      math.sin(a) * h * 0.20 + h * 0.06,
      shoulderDy + h * 0.11,
    );
    // bodyHalf is unused here but keeps the shoulder maths honest if the
    // arms are ever anchored differently.
    assert(bodyHalf > 0);
    return (
      hand: hand,
      tip: Offset(
        hand.dx + math.sin(a) * h * 0.62,
        hand.dy - math.cos(a) * h * 0.62,
      ),
    );
  }

  void paint(
    Canvas canvas, {
    required Offset ground,
    required Archetype archetype,
    required double height,
    Color? tint,
    bool holdingClub = false,
    bool detailed = false,
    Pose pose = const Pose.still(),
    SwingCurve curve = SwingCurve.shipped,
  }) {
    final d = _dims(archetype);
    final build = CavemanPainter.buildFor(archetype);
    // Same overall height as the classic painter, so swapping styles does
    // not change how big anyone is on the field.
    final h = height * (0.92 + 0.12 * build);
    final hide = tint ?? hideFor(archetype);
    final hair = hairFor(archetype);
    final sw = h * 0.030;
    final top = ground.dy - h;
    double y(double v) => top + v * h;

    final stroke = Paint()
      ..color = ink
      ..strokeWidth = sw
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    void shape(Path p, Color fill, {bool outline = true}) {
      canvas.drawPath(p, Paint()..color = fill);
      if (outline) canvas.drawPath(p, stroke);
    }

    void capsule(Offset a, Offset b, double w, Color fill) {
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = ink
          ..strokeWidth = w + sw * 2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = fill
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round,
      );
    }

    void oval(
      Offset c,
      double rx,
      double ry,
      Color fill, {
      bool outline = true,
    }) {
      shape(
        Path()
          ..addOval(Rect.fromCenter(center: c, width: rx * 2, height: ry * 2)),
        fill,
        outline: outline,
      );
    }

    // Running lifts the body twice a stride and tips it forward.
    var bob = 0.0;
    var lean = 0.0;
    if (pose.act == Act.run) {
      bob = math.sin(4 * math.pi * pose.t).abs() * h * 0.035;
      lean = h * 0.06;
    }

    final cx = ground.dx;
    final headCy = y(0.22) - bob;
    final headRx = h * 0.20 * d.head;
    final headRy = h * 0.19 * d.head;
    final shoulderY = y(0.44) - bob;
    final hemY = y(0.72) - bob;
    final bodyHalf = h * 0.17 * d.body;
    final limbW = h * 0.074 * d.limb;

    canvas.drawOval(
      Rect.fromCenter(
        center: ground,
        width: bodyHalf * 2.3,
        height: bodyHalf * 0.8,
      ),
      Paint()..color = _shadow,
    );

    // --- legs ---------------------------------------------------------
    // Amplitude borrowed from the classic rig on purpose: it is what
    // CavemanPainter.strideFor measures, and that is what keeps the run
    // cycle from skating.
    final legX = h * 0.075 * d.body;
    if (pose.act == Act.run) {
      final phase = pose.t * 2 * math.pi;
      final amp = 0.95 * h * 0.34 * build;
      for (final s in [-1.0, 1.0]) {
        final p = phase + (s < 0 ? 0.0 : math.pi);
        final hipX = cx + s * legX * 0.6 + lean * 0.4;
        capsule(
          Offset(hipX, hemY),
          Offset(
            hipX - math.cos(p) * amp,
            ground.dy - math.max(0.0, math.sin(p)) * h * 0.16,
          ),
          limbW,
          _skin,
        );
      }
    } else {
      for (final s in [-1.0, 1.0]) {
        capsule(
          Offset(cx + s * legX, hemY - h * 0.02),
          Offset(cx + s * legX, ground.dy - h * 0.05),
          limbW,
          _skin,
        );
        oval(
          Offset(cx + s * legX + s * h * 0.015, ground.dy - h * 0.032),
          h * 0.074 * d.limb,
          h * 0.040 * d.limb,
          _skin,
        );
      }
    }

    // --- arms, and whatever is in them --------------------------------
    final shX = bodyHalf * 0.94;

    // The swing is drawn LAST, over the top of everything. Drawn in order
    // with the other limbs it sweeps across the chest and spends most of
    // its arc hidden behind the tunic and the beard, which is the whole
    // reason it looked like nothing happened at all.
    void Function()? swingOverlay;

    switch (pose.act) {
      case Act.swing:
        final t = curve.ease(pose.t);
        // A right-hander on the third-base side — screen LEFT, with the
        // plate to his right. His bat is cocked over his back shoulder,
        // which faces the catcher, so the tip starts pointing DOWN-screen;
        // it sweeps down through the zone, out to the right at contact, and
        // wraps up over his front shoulder. In this angle convention
        // (0 = straight up, +x at +pi/2) that is a DECREASING angle, which
        // is counterclockwise on screen. Increasing it sends the bat round
        // the wrong way, over his head and away from the plate.
        final a = curve.back + (curve.through - curve.back) * t;
        final hand = Offset(
          cx + math.sin(a) * h * 0.20 + h * 0.06,
          shoulderY + h * 0.11,
        );
        swingOverlay = () {
          // A smear of where the club has just been, so the swing reads at
          // speed instead of being one frame nobody sees.
          if (pose.t > 0.04 && pose.t < 0.9) {
            final trail = Path();
            for (var i = 0; i <= 7; i++) {
              final tt = (t - 0.3 * (i / 7)).clamp(0.0, 1.0);
              final aa = curve.back + (curve.through - curve.back) * tt;
              final p = Offset(
                hand.dx + math.sin(aa) * h * 0.62,
                hand.dy - math.cos(aa) * h * 0.62,
              );
              if (i == 0) {
                trail.moveTo(p.dx, p.dy);
              } else {
                trail.lineTo(p.dx, p.dy);
              }
            }
            canvas.drawPath(
              trail,
              Paint()
                ..color = const Color(0xFFFFF4D8).withValues(alpha: 0.45)
                ..strokeWidth = h * 0.09
                ..strokeCap = StrokeCap.round
                ..style = PaintingStyle.stroke,
            );
          }
          final tip = Offset(
            hand.dx + math.sin(a) * h * 0.62,
            hand.dy - math.cos(a) * h * 0.62,
          );
          capsule(Offset(cx - shX, shoulderY + h * 0.05), hand, limbW, _skin);
          capsule(Offset(cx + shX, shoulderY + h * 0.05), hand, limbW, _skin);
          capsule(hand, tip, h * 0.075, _club);
          oval(tip, h * 0.11, h * 0.10, _club);
          oval(hand, h * 0.062 * d.limb, h * 0.058 * d.limb, _skin);
        };
      case Act.throwing:
        final a = _throwArm(pose.t);
        final sh = Offset(cx + shX, shoulderY + h * 0.03);
        final hand = Offset(
          sh.dx + math.sin(a) * h * 0.30,
          sh.dy - math.cos(a) * h * 0.30,
        );
        capsule(
          Offset(cx - shX, shoulderY + h * 0.03),
          Offset(cx - bodyHalf - h * 0.05, hemY),
          limbW,
          _skin,
        );
        capsule(sh, hand, limbW, _skin);
        oval(hand, h * 0.062 * d.limb, h * 0.058 * d.limb, _skin);
        if (pose.t < 0.62) oval(hand, h * 0.075, h * 0.070, _rock);
      case Act.run:
        final phase = pose.t * 2 * math.pi;
        for (final s in [-1.0, 1.0]) {
          final p = phase + (s < 0 ? math.pi : 0.0);
          final from = Offset(cx + s * shX + lean * 0.8, shoulderY + h * 0.04);
          capsule(
            from,
            Offset(
              from.dx + math.cos(p) * bodyHalf * 0.8,
              from.dy + h * 0.17 - math.sin(p).abs() * h * 0.05,
            ),
            limbW,
            _skin,
          );
        }
      case Act.still:
        for (final s in [-1.0, 1.0]) {
          final hx = cx + s * (bodyHalf + h * 0.05);
          capsule(
            Offset(cx + s * shX, shoulderY + h * 0.03),
            Offset(hx, hemY + h * 0.01),
            limbW,
            _skin,
          );
          oval(
            Offset(hx, hemY + h * 0.01),
            h * 0.060 * d.limb,
            h * 0.056 * d.limb,
            _skin,
          );
        }
        if (holdingClub) {
          final hx = cx + bodyHalf + h * 0.05;
          capsule(
            Offset(hx, hemY - h * 0.22),
            Offset(hx + h * 0.03, hemY + h * 0.06),
            h * 0.06,
            _club,
          );
          oval(
            Offset(hx + h * 0.01, hemY - h * 0.26),
            h * 0.09,
            h * 0.085,
            _club,
          );
        }
    }

    // --- the hide, with a ragged hem ----------------------------------
    final tunic = Path()
      ..moveTo(cx - bodyHalf, shoulderY)
      ..lineTo(cx + bodyHalf, shoulderY);
    const teeth = 10;
    for (var i = teeth; i >= 0; i--) {
      final t = i / teeth;
      tunic.lineTo(
        cx - bodyHalf + 2 * bodyHalf * t,
        hemY + (i.isEven ? 0 : h * 0.07),
      );
    }
    shape(tunic..close(), hide);

    // The tribe's mark. Flat, no shading.
    canvas.drawRect(
      Rect.fromLTRB(
        cx - bodyHalf * 0.42,
        shoulderY + h * 0.09,
        cx + bodyHalf * 0.42,
        shoulderY + h * 0.16,
      ),
      Paint()..color = _ochre,
    );

    // --- head ----------------------------------------------------------
    final head = Offset(cx + lean * 1.2, headCy);
    oval(head, headRx, headRy, _skin);

    // Jagged crown. Nothing else on the field has a ragged top edge, which
    // is most of what says "caveman" once he is small.
    final crown = Path()
      ..moveTo(head.dx - headRx * 0.98, head.dy - headRy * 0.22);
    const spikes = 7;
    for (var i = 0; i < spikes; i++) {
      final a0 = math.pi * (1 - i / spikes);
      final a1 = math.pi * (1 - (i + 0.5) / spikes);
      crown.lineTo(
        head.dx + math.cos(a1) * headRx * 1.16,
        head.dy - math.sin(a1) * headRy * 1.42,
      );
      crown.lineTo(
        head.dx + math.cos(a0 + (a1 - a0) * 2) * headRx * 0.9,
        head.dy - math.sin(a0 + (a1 - a0) * 2) * headRy * 0.96,
      );
    }
    crown.lineTo(head.dx + headRx * 0.98, head.dy - headRy * 0.22);
    shape(crown..close(), hair);

    // Beard: wider than the jaw and pointed.
    final bw = headRx * 1.12 * d.beard;
    shape(
      Path()
        ..moveTo(head.dx - bw, head.dy + headRy * 0.05)
        ..lineTo(head.dx - bw * 0.82, head.dy + headRy * 0.95)
        ..lineTo(head.dx, head.dy + headRy * 1.95 * d.beard)
        ..lineTo(head.dx + bw * 0.82, head.dy + headRy * 0.95)
        ..lineTo(head.dx + bw, head.dy + headRy * 0.05)
        ..lineTo(head.dx + bw * 0.6, head.dy + headRy * 0.42)
        ..lineTo(head.dx - bw * 0.6, head.dy + headRy * 0.42)
        ..close(),
      hair,
    );

    // Eyes, then the heavy brow over them.
    final eyeRx = headRx * 0.37;
    final eyeRy = headRy * 0.46;
    final eyeY = head.dy - headRy * 0.12;
    for (final s in [-1.0, 1.0]) {
      oval(
        Offset(head.dx + s * eyeRx * 0.96, eyeY),
        eyeRx,
        eyeRy,
        const Color(0xFFFFFFFF),
      );
    }
    for (final s in [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(head.dx + s * eyeRx * 0.96 + h * 0.008, eyeY + h * 0.008),
        headRx * 0.135,
        Paint()..color = ink,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(head.dx - eyeRx * 1.96, eyeY - eyeRy * 0.92)
        ..lineTo(head.dx + eyeRx * 1.96, eyeY - eyeRy * 0.92)
        ..lineTo(head.dx + eyeRx * 1.6, eyeY - eyeRy * 1.55)
        ..lineTo(head.dx - eyeRx * 1.6, eyeY - eyeRy * 1.55)
        ..close(),
      Paint()..color = hair,
    );

    oval(
      Offset(head.dx + h * 0.006, eyeY + eyeRy * 1.05),
      headRx * 0.23,
      headRx * 0.19,
      _skin,
    );

    // The overbite, sitting on top of the beard.
    final mY = eyeY + eyeRy * 2.0;
    shape(
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            head.dx - headRx * 0.31,
            mY,
            headRx * 0.62,
            headRx * 0.32,
          ),
          Radius.circular(h * 0.012),
        ),
      ),
      const Color(0xFFFFFFFF),
    );

    swingOverlay?.call();
  }

  // The arc's shape lives on SwingCurve now, so it can be tuned on the
  // bench instead of edited here and rebuilt. These forward to the shipped
  // curve for anything that just wants the default.
  static double swingEase(double t) => SwingCurve.shipped.ease(t);
  static double get contactAt => SwingCurve.shipped.contactAt;

  double _throwArm(double t) {
    if (t < 0.40) {
      final u = t / 0.40;
      return 0.30 + 2.10 * (1 - math.pow(1 - u, 2.0).toDouble());
    }
    return 2.40 - 3.70 * math.pow((t - 0.40) / 0.60, 0.55).toDouble();
  }
}
