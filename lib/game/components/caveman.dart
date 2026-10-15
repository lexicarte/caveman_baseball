// Draws one upright caveman standing on the ground plane.
//
// Shared by every figure on the field so a man looks the same whether he is
// fielding, batting or running. Archetype has to read from silhouette and
// colour at about twenty points tall, so the differences are width, height
// and hue — the shaggy detail is for when he is drawn large.
import 'dart:math' as math;
import 'dart:ui';

import '../../model/player.dart';

/// What a man is doing. One value instead of a nullable double per action,
/// so adding the next animation does not add another parameter.
enum Act { still, swing, run, throwing }

class Pose {
  const Pose.still() : act = Act.still, t = 0;

  /// 0 to 1 through a swing.
  const Pose.swing(this.t) : act = Act.swing;

  /// 0 to 1 through ONE stride cycle, and it wraps.
  const Pose.run(this.t) : act = Act.run;

  /// 0 to 1 through a wind-up and release.
  const Pose.throwing(this.t) : act = Act.throwing;

  final Act act;
  final double t;

  bool get isRunning => act == Act.run;
}

class CavemanPainter {
  const CavemanPainter();

  static const _shadow = Color(0x44000000);

  /// How long each action takes. Here rather than in the game so the preview
  /// harness and the real thing cannot disagree about it.
  /// Shorter than it was (0.42). With contact front-loaded, a long tail is
  /// just a bat sitting still at the end of the arc.
  static const double swingSeconds = 0.30;
  static const double throwSeconds = 0.60;

  /// Half the fore-and-aft travel of a foot, as a multiple of shoulder width.
  static const double _strideAmp = 0.95;

  /// How far one stride cycle carries him, in the same units as [height].
  ///
  /// Each foot is planted for half the cycle and sweeps the full stride in
  /// that time, and the two feet are half a cycle apart — so the body covers
  /// four amplitudes per cycle.
  static double strideFor(Archetype a, double height) {
    final build = buildFor(a);
    final h = height * (0.92 + 0.12 * build);
    return 4 * _strideAmp * h * 0.34 * build;
  }

  /// The ONLY cycle time that does not make him skate.
  ///
  /// Foot slip is the one run-cycle bug nobody forgives, and it is pure
  /// arithmetic: the stride has to be walked off in exactly the time the
  /// simulation says he needs to cover it. [pxPerUnit] converts a pace into
  /// whatever units [height] is in.
  static double runCycleSecondsFor(
    Archetype a,
    double height, {
    required double pxPerUnit,
    double secondsPerBase = 2.58,
    double baseDistance = 13.0,
  }) {
    final speed = baseDistance / secondsPerBase; // paces per second
    final p = Player(id: '_', name: '_', archetype: a);
    final pxPerSecond = speed * p.speedScale * pxPerUnit;
    return strideFor(a, height) / pxPerSecond;
  }

  /// Hide colour by archetype. Light and slight through to dark and heavy.
  static Color hideFor(Archetype a) => switch (a) {
    Archetype.swift => const Color(0xFF6E6354),
    Archetype.steady => const Color(0xFF4F463B),
    Archetype.mighty => const Color(0xFF362F27),
  };

  static Color skinFor(Archetype a) => switch (a) {
    Archetype.swift => const Color(0xFFBE9A6E),
    Archetype.steady => const Color(0xFFA8845C),
    Archetype.mighty => const Color(0xFF8E6E4A),
  };

  /// Relative build. Swift is slight, mighty is a slab.
  static double buildFor(Archetype a) => switch (a) {
    Archetype.swift => 0.86,
    Archetype.steady => 1.0,
    Archetype.mighty => 1.22,
  };

  /// [ground] is where his feet are, in render space. He is drawn upward from
  /// there and never squashed.
  void paint(
    Canvas canvas, {
    required Offset ground,
    required Archetype archetype,
    required double height,
    Color? tint,
    bool holdingClub = false,
    bool detailed = false,

    /// What he is doing. This is the only feedback connecting a tap to what
    /// happened, so it matters more than anything else drawn here.
    Pose pose = const Pose.still(),
  }) {
    final build = buildFor(archetype);
    final h = height * (0.92 + 0.12 * build);
    final shoulder = h * 0.34 * build;
    final headR = h * 0.17;
    final hide = tint ?? hideFor(archetype);
    final skin = skinFor(archetype);
    final swing = pose.act == Act.swing ? pose.t : null;

    canvas.drawOval(
      Rect.fromCenter(
        center: ground,
        width: shoulder * 2.1,
        height: shoulder * 0.8,
      ),
      Paint()..color = _shadow,
    );

    // Running lifts the whole body twice a stride and tips it forward. The
    // feet stay on the ground line; everything above it moves.
    var bob = 0.0;
    var lean = 0.0;
    if (pose.act == Act.run) {
      final phase = pose.t * 2 * math.pi;
      bob = math.sin(2 * phase).abs() * h * 0.035;
      lean = h * 0.07;
    } else if (pose.act == Act.throwing) {
      lean = h * 0.05 * _throwLean(pose.t);
    }

    final hipY = ground.dy - h * 0.30 - bob;
    final shoulderY = ground.dy - h + headR * 1.7 - bob;
    final hidePaint = Paint()..color = hide;
    final legW = shoulder * 0.34;

    if (pose.act == Act.run) {
      // Each foot travels an oval: forward through the air, back along the
      // ground. Two bones would be better, but at twenty points tall the
      // stride length and the lift are the whole of what reads.
      final phase = pose.t * 2 * math.pi;
      for (final side in [-1.0, 1.0]) {
        final p = phase + (side < 0 ? 0.0 : math.pi);
        final hipX = ground.dx + side * shoulder * 0.34 + lean * 0.4;
        final footX = hipX - math.cos(p) * _strideAmp * shoulder;
        final footY = ground.dy - math.max(0.0, math.sin(p)) * h * 0.16;
        canvas.drawLine(
          Offset(hipX, hipY),
          Offset(footX, footY),
          Paint()
            ..color = hide
            ..strokeWidth = legW
            ..strokeCap = StrokeCap.round,
        );
      }
    } else {
      // Standing: two stubs, splayed slightly so he reads as planted.
      for (final side in [-1.0, 1.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              ground.dx + side * shoulder * 0.46 - legW / 2,
              hipY,
              ground.dx + side * shoulder * 0.46 + legW / 2,
              ground.dy,
            ),
            Radius.circular(legW * 0.4),
          ),
          hidePaint,
        );
      }
    }

    // Torso: wider at the shoulders than the hips.
    final torso = Path()
      ..moveTo(ground.dx - shoulder + lean, shoulderY)
      ..lineTo(ground.dx + shoulder + lean, shoulderY)
      ..lineTo(ground.dx + shoulder * 0.62, hipY)
      ..lineTo(ground.dx - shoulder * 0.62, hipY)
      ..close();
    canvas.drawPath(torso, hidePaint);

    // Arms, angled out so the silhouette is not a plain rectangle.
    final armW = shoulder * 0.3;
    final armPaint = Paint()
      ..color = hide
      ..strokeWidth = armW
      ..strokeCap = StrokeCap.round;

    if (pose.act == Act.run) {
      // Counter-swing: each arm opposes the leg on its own side, which is
      // what stops a run cycle looking like a man being dragged.
      final phase = pose.t * 2 * math.pi;
      for (final side in [-1.0, 1.0]) {
        final p = phase + (side < 0 ? math.pi : 0.0);
        final from = Offset(
          ground.dx + side * shoulder * 0.85 + lean * 0.8,
          shoulderY + h * 0.05,
        );
        canvas.drawLine(
          from,
          Offset(
            from.dx + math.cos(p) * shoulder * 0.75 + lean * 0.5,
            from.dy + h * 0.17 - math.sin(p).abs() * h * 0.05,
          ),
          armPaint,
        );
      }
    } else if (pose.act == Act.throwing) {
      final a = _throwArm(pose.t);
      final sh = Offset(
        ground.dx + shoulder * 0.7 + lean,
        shoulderY + h * 0.05,
      );
      final hand = Offset(
        sh.dx + math.sin(a) * h * 0.30,
        sh.dy - math.cos(a) * h * 0.30,
      );
      // Trailing arm, then the throwing arm over the top of the torso.
      canvas.drawLine(
        Offset(ground.dx - shoulder * 0.85 + lean, shoulderY + h * 0.05),
        Offset(ground.dx - shoulder * 1.3, shoulderY + h * 0.26),
        armPaint,
      );
      canvas.drawLine(sh, hand, armPaint);
      if (pose.t < 0.62) {
        canvas.drawCircle(
          hand,
          h * 0.055,
          Paint()..color = const Color(0xFFD8C7A4),
        );
      }
    } else {
      for (final side in [-1.0, 1.0]) {
        canvas.drawLine(
          Offset(ground.dx + side * shoulder * 0.9, shoulderY + h * 0.04),
          Offset(ground.dx + side * shoulder * 1.35, shoulderY + h * 0.30),
          armPaint,
        );
      }
    }

    // Shaggy hem, only worth drawing when he is big enough for it to read.
    if (detailed) {
      final hem = Path()..moveTo(ground.dx - shoulder * 0.62, hipY);
      const notches = 5;
      for (var i = 0; i <= notches; i++) {
        final t = i / notches;
        final px = ground.dx + (t - 0.5) * shoulder * 1.24;
        final py = hipY + (i.isEven ? h * 0.05 : h * 0.01);
        hem.lineTo(px, py);
      }
      hem
        ..lineTo(ground.dx + shoulder * 0.62, hipY)
        ..close();
      canvas.drawPath(hem, hidePaint);
    }

    final head = Offset(ground.dx + lean * 1.4, shoulderY - headR * 0.55);
    canvas.drawCircle(head, headR, Paint()..color = skin);
    // Hair as a cap over the top half, which is what gives him a face side.
    canvas.drawArc(
      Rect.fromCircle(center: head, radius: headR),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFF241F1A),
    );

    if (holdingClub) {
      // Back over the shoulder, through, and round. Eased so it whips
      // through contact rather than sweeping at a constant rate.
      const back = 1.35;
      const through = -2.05;
      final t = swing == null ? 0.0 : _ease(swing);
      final angle = back + (through - back) * t;
      final pivot = Offset(ground.dx + shoulder * 0.55, shoulderY + h * 0.16);

      if (swing != null && swing > 0.02 && swing < 0.85) {
        // A smear of where the club has just been, so the swing reads at
        // speed instead of being a single frame nobody sees.
        final trail = Path();
        const steps = 7;
        for (var i = 0; i <= steps; i++) {
          final tt = (t - 0.22 * (i / steps)).clamp(0.0, 1.0);
          final a = back + (through - back) * tt;
          final p = Offset(
            pivot.dx + math.sin(a) * h * 0.46,
            pivot.dy - math.cos(a) * h * 0.46,
          );
          i == 0 ? trail.moveTo(p.dx, p.dy) : trail.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(
          trail,
          Paint()
            ..color = const Color(0xFFD8C7A4).withValues(alpha: 0.35)
            ..strokeWidth = h * 0.05
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
      }

      canvas.save();
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-h * 0.035, -h * 0.48, h * 0.075, h * 0.50),
          Radius.circular(h * 0.035),
        ),
        Paint()..color = const Color(0xFF8C6239),
      );
      canvas.restore();
    }
  }

  /// Arm angle through a throw: up and back, then whipped over. Radians,
  /// zero straight up, positive behind him.
  double _throwArm(double t) {
    if (t < 0.40) {
      final u = t / 0.40;
      return 0.30 + 2.10 * (1 - math.pow(1 - u, 2.0).toDouble());
    }
    final u = (t - 0.40) / 0.60;
    return 2.40 - 3.70 * math.pow(u, 0.55).toDouble();
  }

  /// Weight: back over the rear foot during the wind-up, over the front one
  /// after release.
  double _throwLean(double t) {
    if (t < 0.40) return -(t / 0.40);
    return -1.0 + 2.3 * math.pow((t - 0.40) / 0.60, 0.7).toDouble();
  }

  /// Slow out of the load, fast through the ball, slow on the follow.
  double _ease(double t) {
    if (t < 0.45) return 0.55 * math.pow(t / 0.45, 2.1).toDouble();
    final u = (t - 0.45) / 0.55;
    return 0.55 + 0.45 * (1 - math.pow(1 - u, 2.4).toDouble());
  }
}
