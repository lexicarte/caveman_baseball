// Dimensions and fielder count for a playfield.
//
// Deliberately small relative to real baseball: the whole game is ground
// balls, so the field only needs to be as big as a ball can realistically
// roll. Fielder count is a tunable so 3-man and 4-man defense can be
// compared side by side.
import 'dart:math' as math;

class FieldSpec {
  const FieldSpec({
    required this.wallRadius,
    required this.foulAngleDegrees,
    required this.baseDistance,
    required this.secondDistance,
    required this.moundDistance,
  });

  /// Metres from home plate to the outfield wall.
  final double wallRadius;

  /// Half-angle of fair territory, measured from straightaway centre.
  final double foulAngleDegrees;

  /// Home to FIRST and THIRD. Those two are symmetric, so one number does
  /// both; second gets its own because the diamond is seen from behind the
  /// plate and how deep it looks is a separate decision from how wide.
  final double baseDistance;

  /// Home to SECOND, straight out. A true square diamond wants
  /// `baseDistance * sqrt2`; anything less pulls second toward the mound
  /// and anything more pushes it toward the outfield.
  final double secondDistance;

  final double moundDistance;

  double get foulAngleRadians => foulAngleDegrees * math.pi / 180.0;

  /// True if a point (x metres right of plate, y metres toward centre) is fair.
  bool isFair(double x, double y) {
    if (y <= 0) return false;
    return (math.atan2(x, y)).abs() <= foulAngleRadians;
  }

  /// The shipped field. Mirrors `LookDefaults`, which is where the tuning
  /// bench drags these — but stated here as a const so the pure simulation
  /// and its headless tools never have to reach into the render layer.
  static const FieldSpec compact = FieldSpec(
    wallRadius: 54,
    foulAngleDegrees: 48,
    baseDistance: 16.364,
    secondDistance: 18.764,
    moundDistance: 11.273,
  );
}
