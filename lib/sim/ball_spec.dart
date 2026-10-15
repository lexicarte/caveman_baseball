// Defines the physical personality of a throwable "ball".
//
// This is the knob-set that makes a coconut feel different from a boulder.
// Pure data — no Flame, no rendering, no Firestore.
class BallSpec {
  const BallSpec({
    required this.id,
    required this.name,
    required this.flavor,
    required this.mass,
    required this.rollFriction,
    required this.drag,
    required this.restitution,
    this.wobble = 0,
    this.wobbleFreq = 0,
  });

  final String id;
  final String name;
  final String flavor;

  /// Kilograms. Heavier balls come off the bat slower but shrug off air drag.
  final double mass;

  /// Constant ground deceleration (m/s^2). Mass-independent, like real
  /// Coulomb friction. High values make a ball die where it lands.
  final double rollFriction;

  /// Quadratic drag coefficient. Applied as (drag * speed^2) / mass, so heavy
  /// balls carry and light balls bleed speed quickly.
  final double drag;

  /// Wall bounce energy retained, 0..1.
  final double restitution;

  /// Lateral wander amplitude. Non-zero makes the ball curve unpredictably —
  /// this is what sells an egg or a skull as "not round".
  final double wobble;

  /// Wander oscillation rate (rad/s). Low = long lazy curve, high = jitter.
  final double wobbleFreq;

  BallSpec copyWith({double? rollFriction, double? drag}) => BallSpec(
    id: id,
    name: name,
    flavor: flavor,
    mass: mass,
    rollFriction: rollFriction ?? this.rollFriction,
    drag: drag ?? this.drag,
    restitution: restitution,
    wobble: wobble,
    wobbleFreq: wobbleFreq,
  );
}
