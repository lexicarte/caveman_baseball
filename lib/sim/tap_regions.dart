// Which man a defensive tap sends.
//
// Tapping the man himself does not survive contact with the schemes: a
// fielder is about 28px of sprite, and CLOSE puts the thrower and the centre
// fielder six paces apart, which the ground squash turns into a couple of
// dozen pixels. Two men under one thumb is a coin flip, and the old
// nine-pace search could also miss everybody and do nothing at all.
//
// So a tap anywhere on the field sends the nearest man, full stop. No
// cutoff, no dead ground, no miss. Effectively the field is partitioned and
// every patch belongs to somebody; tool/tap_regions.dart draws and measures
// that partition.
//
// "Nearest" is nearest in TIME, not in paces — FielderSpec.timeToReach,
// which is what the rest of the simulation already uses to decide who gets
// to a ball. It differs from raw distance by about a pace, and it is the
// difference that makes speed matter: your swift man visibly owns more
// ground than the statue at the plate.
import 'package:vector_math/vector_math_64.dart';

import 'fielder_spec.dart';

class TapRegions {
  const TapRegions._();

  /// Who chases a ball tapped at ([x], [y]) in field paces.
  ///
  /// Takes plain doubles rather than a Vector2 on purpose: Flame and the
  /// simulation use two different Vector2 classes out of the same package,
  /// so nothing vector-shaped crosses the boundary from the game layer.
  ///
  /// [men] must already be staffed — a swift man owns more ground than a
  /// slow one standing on the same post.
  static FielderSpec resolve(double x, double y, List<FielderSpec> men) {
    final point = Vector2(x, y);
    FielderSpec? best;
    var bestTime = double.infinity;
    for (final m in men) {
      // The catcher is not a chase option. Filtered here rather than at the
      // call sites so nothing can forget and send him wandering off home.
      if (!m.chases) continue;
      final t = m.timeToReach(point);
      if (t < bestTime) {
        bestTime = t;
        best = m;
      }
    }
    return best ?? men.first;
  }
}
