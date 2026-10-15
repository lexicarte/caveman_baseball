// The rock, with a shadow that keeps it attached to the ground.
//
// Now that the plane is tilted, an air ball can actually rise: the rock lifts
// off its shadow and comes back down, which is the only honest way to show
// that a SMAK went over their heads.
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../model/rock.dart';
import '../ground.dart';

class BallComponent extends PositionComponent {
  BallComponent() : super(priority: 20);

  double? fieldX;
  double? fieldY;

  /// Metres above the ground. Zero for anything rolling.
  double lift = 0;

  Rock? rock;

  /// Scales with the figures. A rock that stayed one size while everyone
  /// shrank would read as a boulder.
  double modelScale = 1.0;

  final List<Offset> _trail = [];
  static const _maxTrail = 24;

  void clearTrail() => _trail.clear();

  void hide() {
    fieldX = null;
    fieldY = null;
    _trail.clear();
  }

  void syncTo(double x, double y, Rock r, {double lift = 0}) {
    fieldX = x;
    fieldY = y;
    this.lift = lift;
    rock = r;
    _trail.add(Offset(Ground.x(x, y), Ground.y(y) - lift));
    if (_trail.length > _maxTrail) _trail.removeAt(0);
  }

  @override
  void render(Canvas canvas) {
    final x = fieldX;
    final y = fieldY;
    final r = rock;
    if (x == null || y == null || r == null) return;

    // The trail is what makes the rock read as MOVING rather than as a dot
    // that teleports. With the timing meter gone it is doing real work, so
    // it is drawn far stronger than a garnish would be.
    for (var i = 0; i < _trail.length; i++) {
      final t = i / _trail.length;
      canvas.drawCircle(
        _trail[i],
        0.35 + 0.55 * t,
        Paint()
          ..color = const Color(0xFFFFF4D8).withValues(alpha: 0.10 + 0.4 * t),
      );
    }

    final groundAt = Offset(Ground.x(x, y), Ground.y(y));
    // Deliberately oversized. The rock is the whole interface now — but
    // it still has to get smaller as it travels, or a ball hit to the
    // wall arrives there the size of the batter's head.
    final radius = (1.35 + r.ball.mass * 0.9) * modelScale * Ground.depthScale(y);

    // Shadow stays on the ground and shrinks as the rock climbs.
    final shrink = (1 - lift * 0.08).clamp(0.45, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: groundAt,
        width: radius * 2 * shrink,
        height: radius * 2 * shrink * Ground.squash,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.34 * shrink),
    );

    final at = groundAt.translate(0, -lift);
    canvas.drawCircle(at, radius, Paint()..color = const Color(0xFFFFF4D8));
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..color = const Color(0xFF241A10)
        ..strokeWidth = 0.3
        ..style = PaintingStyle.stroke,
    );
  }
}
