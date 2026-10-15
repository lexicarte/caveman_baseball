// Integrates a batted ball rolling across a 2D plane.
//
// There is no vertical axis anywhere in this game: every hit is a ground ball
// or a liner, so position is strictly (x, y) in metres from home plate with
// +y pointing toward centre field and +x toward right field.
//
// Deceleration has two terms:
//   - rollFriction: constant, mass-independent (real Coulomb friction)
//   - drag: quadratic in speed and divided by mass, so heavy balls carry
//
// Together they give a satisfying curve — a hard shot sheds speed fast at
// first, then settles into a long steady roll.
import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'ball_spec.dart';
import 'field_spec.dart';

class BallState {
  BallState({required this.position, required this.velocity});

  Vector2 position;
  Vector2 velocity;

  /// Seconds since the ball was put in play; drives wobble oscillation.
  double age = 0;

  bool atRest = false;

  /// Total ground distance covered, useful for tuning and for scoring later.
  double distanceTravelled = 0;

  bool hitWall = false;

  double get speed => velocity.length;

  BallState clone() =>
      BallState(position: position.clone(), velocity: velocity.clone())
        ..age = age
        ..atRest = atRest
        ..distanceTravelled = distanceTravelled
        ..hitWall = hitWall;
}

class BallPhysics {
  const BallPhysics({this.restSpeed = 0.35});

  /// Below this speed the ball is considered stopped.
  final double restSpeed;

  void step(BallState state, BallSpec spec, FieldSpec field, double dt) {
    if (state.atRest) return;

    state.age += dt;

    final speed = state.speed;
    if (speed <= restSpeed) {
      state.velocity.setZero();
      state.atRest = true;
      return;
    }

    final direction = state.velocity / speed;

    final dragAccel = (spec.drag * speed * speed) / spec.mass;
    final decel = (spec.rollFriction + dragAccel) * dt;

    // Never let deceleration push the ball backwards through zero.
    final newSpeed = math.max(0.0, speed - decel);
    state.velocity = direction * newSpeed;

    if (spec.wobble > 0 && newSpeed > restSpeed) {
      final lateral = Vector2(-direction.y, direction.x);
      final wander =
          spec.wobble * math.sin(state.age * spec.wobbleFreq) * newSpeed;
      state.velocity += lateral * (wander * dt);
    }

    final delta = state.velocity * dt;
    state.position += delta;
    state.distanceTravelled += delta.length;

    _bounceOffWall(state, spec, field);

    if (state.speed <= restSpeed) {
      state.velocity.setZero();
      state.atRest = true;
    }
  }

  /// Reflects the ball off the outfield arc. The wall only exists in fair
  /// territory — foul balls simply leave the field.
  void _bounceOffWall(BallState state, BallSpec spec, FieldSpec field) {
    final distance = state.position.length;
    if (distance < field.wallRadius) return;
    if (!field.isFair(state.position.x, state.position.y)) return;

    final normal = state.position.normalized();

    // Pull the ball back to the wall face so it cannot tunnel through.
    state.position = normal * (field.wallRadius - 0.01);

    final into = state.velocity.dot(normal);
    if (into > 0) {
      state.velocity -= normal * (into * (1.0 + spec.restitution));
    }
    state.hitWall = true;
  }

  /// Launches a ball from home plate given a swing result.
  BallState launch({required double exitSpeed, required double sprayDegrees}) {
    final radians = sprayDegrees * math.pi / 180.0;
    return BallState(
      position: Vector2.zero(),
      velocity: Vector2(math.sin(radians), math.cos(radians)) * exitSpeed,
    );
  }
}
