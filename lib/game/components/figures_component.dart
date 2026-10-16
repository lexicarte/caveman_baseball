// Every person on the field, standing up.
//
// Drawn back to front so near men overlap far ones — without that the tilt
// reads as a flat pattern rather than a field with depth.
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../model/player.dart';
import '../../sim/base_running.dart';
import '../art/art_style.dart';
import '../ground.dart';
import '../look.dart';
import '../sprites/field_figure.dart';
import '../sprites/sprite_library.dart';
import 'caveman.dart';

/// One person to draw, at a place on the field.
class Figure {
  const Figure({
    required this.fieldX,
    required this.fieldY,
    required this.archetype,
    this.chasing = false,
    this.holdingClub = false,
    this.reach = 0,
    this.pose = const Pose.still(),
  });

  final double fieldX;
  final double fieldY;
  final Archetype archetype;
  final bool chasing;
  final bool holdingClub;

  /// What he is doing: standing, swinging, or running somewhere.
  final Pose pose;

  /// How far this man can reach, in paces. Drawn flat on the ground so the
  /// gaps between the defence are visible — that is the thing the batter is
  /// reading during the pitch.
  final double reach;
}

class FiguresComponent extends PositionComponent {
  FiguresComponent({SpriteLibrary? sprites})
    : sprites = sprites ?? SpriteLibrary(),
      super(priority: 10);

  final SpriteLibrary sprites;

  List<Figure> figures = const [];

  /// Bags someone is covering, ringed so an unguarded one is visible.
  Set<int> coveredBases = const {};

  /// The camera's current zoom. Men SHRINK as it pushes in — see
  /// Ground.figureHeightFor. Without that the mound sits less than two body
  /// heights from the plate and nothing about the at-bat reads as baseball.
  double zoom = Ground.wideZoom;

  /// Idle sheets bob on their own clock. Swings and runs are driven by the
  /// pose, which the game already times.
  double idleSeconds = 0;

  static const _chaserTint = Color(0xFF7A4034);
  static const _cartoonChaserTint = Color(0xFFC4452C);

  @override
  void update(double dt) {
    super.update(dt);
    idleSeconds += dt;
  }

  @override
  void render(Canvas canvas) {
    for (final base in [firstBase, secondBase, thirdBase, homeBase]) {
      if (!coveredBases.contains(base)) continue;
      final p = basePosition(base, Look.now.fieldSpec);
      canvas.drawOval(
        Ground.groundOval(p.x, p.y, 1.8),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.45)
          ..strokeWidth = 0.22
          ..style = PaintingStyle.stroke,
      );
    }

    // Far men first.
    final ordered = [...figures]..sort((a, b) => b.fieldY.compareTo(a.fieldY));

    for (final f in ordered) {
      if (f.reach > 0) {
        canvas.drawOval(
          Ground.groundOval(f.fieldX, f.fieldY, f.reach),
          Paint()
            ..color = (f.chasing ? const Color(0xFFE07A5F) : Colors.white)
                .withValues(alpha: f.chasing ? 0.16 : 0.06),
        );
      }
    }

    final cartoon = artStyle.value == ArtStyle.cartoon;
    for (final f in ordered) {
      final pose = f.pose;
      // Height is per MAN, not per frame: he is as tall as his distance
      // says he is. A deep fielder drawn the same size as the batter was
      // the loudest thing saying "this is a board, not a field".
      final figureHeight = Ground.figureHeightAt(zoom, f.fieldY);
      paintFieldFigure(
        canvas,
        sprites: sprites,
        ground: Offset(Ground.x(f.fieldX, f.fieldY), Ground.y(f.fieldY)),
        archetype: f.archetype,
        height: figureHeight,
        tint: f.chasing ? (cartoon ? _cartoonChaserTint : _chaserTint) : null,
        holdingClub: f.holdingClub,
        pose: pose,
        detailed: true,
        idleSeconds: idleSeconds,
      );
    }
  }
}
