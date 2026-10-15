// Where a fielder is partway through a play, and whether he is running.
//
// Pulled out of the render loop so it can be tested: it is the one piece of
// the fielding animation that can be silently wrong — a man who arrives at
// the wrong time, or who slides along the ground without his legs moving,
// makes the whole play unreadable and neither shows up in a screenshot.
import 'dart:math' as math;

import 'components/caveman.dart';

class Placement {
  const Placement(this.x, this.y, this.pose);
  final double x;
  final double y;
  final Pose pose;
}

/// Interpolates a man from [fromX], [fromY] toward [toX], [toY], standing
/// still for [reactionTime] and arriving exactly at [arriveAt].
///
/// That is the same model `FielderSpec.timeToReach` scores the play with, so
/// what you watch is the arrival the simulation actually used — not an
/// animation that happens to look about right.
Placement placeFielder({
  required double fromX,
  required double fromY,
  required double toX,
  required double toY,
  required double reactionTime,
  required double arriveAt,
  required double playback,
  required double stride,
}) {
  final window = arriveAt - reactionTime;
  final f = window <= 0
      ? 1.0
      : ((playback - reactionTime) / window).clamp(0.0, 1.0);
  final x = fromX + (toX - fromX) * f;
  final y = fromY + (toY - fromY) * f;

  // Moving, not arrived, and actually going somewhere.
  final moving = f > 0 && f < 1 && (toX != fromX || toY != fromY);
  if (!moving || stride <= 0) return Placement(x, y, const Pose.still());

  // Drive the stride from DISTANCE COVERED, never from a timer. Do it this
  // way and foot slip is arithmetically impossible; do it the other way and
  // it is only ever approximately right.
  final gone = math.sqrt(
    math.pow(x - fromX, 2).toDouble() + math.pow(y - fromY, 2).toDouble(),
  );
  return Placement(x, y, Pose.run((gone / stride) % 1.0));
}
