import 'dart:ui';

import '../../model/player.dart';
import '../art/art_style.dart';
import '../components/caveman.dart';
import '../components/caveman_cartoon.dart';
import '../components/caveman_pixel.dart';
import 'sprite_library.dart';
import 'sprite_strip.dart';

const _pixel = PixelCavemanPainter();
const _cartoon = CartoonCavemanPainter();

/// One man on the field. A loaded strip wins; otherwise the code-drawn
/// figure for the current art style is what ships.
///
/// A chaser tint has no palette swap yet, so a tinted man stays code-drawn.
/// The highlight would otherwise disappear the moment the first sheet landed.
void paintFieldFigure(
  Canvas canvas, {
  required SpriteLibrary sprites,
  required Offset ground,
  required Archetype archetype,
  required double height,
  Color? tint,
  bool holdingClub = false,
  bool detailed = false,
  Pose pose = const Pose.still(),
  SwingCurve curve = SwingCurve.shipped,
  double idleSeconds = 0,
  double? devicePixelRatio,
}) {
  final strip = tint == null
      ? sprites.forFigure(archetype, pose, holdingClub: holdingClub)
      : null;
  if (strip != null) {
    // Every FIELD caveman is 48 art pixels tall. Width lives in the sheet.
    // That 48 is steady's drawn height. The painter makes mighty a little
    // taller; a sheet does not.
    final body = CavemanPainter.drawnHeight(Archetype.steady, height);
    final cell = body * strip.spec.cellH / SpriteStripSpec.figureArtPixels;
    final phase = pose.act == Act.still
        ? strip.spec.loopPhase(idleSeconds)
        : pose.t;
    strip.draw(
      canvas,
      ground: ground,
      cellWorldHeight: cell,
      phase: phase,
      devicePixelRatio:
          devicePixelRatio ??
          PlatformDispatcher.instance.implicitView?.devicePixelRatio ??
          1.0,
    );
    return;
  }

  if (artStyle.value == ArtStyle.cartoon) {
    _cartoon.paint(
      canvas,
      ground: ground,
      archetype: archetype,
      height: height,
      tint: tint,
      holdingClub: holdingClub,
      detailed: detailed,
      pose: pose,
      curve: curve,
    );
  } else {
    _pixel.paint(
      canvas,
      ground: ground,
      archetype: archetype,
      height: height,
      tint: tint,
      holdingClub: holdingClub,
      detailed: detailed,
      pose: pose,
    );
  }
}
