// The one place field coordinates become screen coordinates.
//
// The simulation works on a flat plane: (x, y) in paces, +y toward the
// outfield. Rendering squashes that plane vertically and draws everything
// standing ON it — figures stay upright, with a shadow to pin them down.
//
// Pure top-down was the problem: from directly above a person is a head and
// two shoulders, with no silhouette to recognise. Tilting the ground costs
// the simulation nothing and makes people look like people.
import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'look.dart';

class Ground {
  // THE NUMBERS LIVE IN `Look`, not here. These are getters so the tuning
  // bench can drag them and every renderer sees the new value on the next
  // frame; `LookDefaults` holds what each one ships at.

  /// How far the ground plane is tilted away. 1.0 is pure top-down.
  ///
  /// This single number IS the diamond's aspect: a square diamond renders
  /// at 1/squash to 1. At 0.8 it came out 1.25:1, near enough to square
  /// that it read as a flat-on overhead shot of a board game. 0.70 gives
  /// 1.43:1 — clearly a diamond seen from behind the plate, without the
  /// 1.77:1 letterbox it had when second base was sitting too close.
  static double get squash => Look.now.squash;

  /// Home plate's y in render space, which puts the plate near the bottom.
  static double get plateY => Look.now.plateY;

  // --- the camera ----------------------------------------------------
  //
  // Here rather than on the game so that everything which has to agree
  // with it — the figure scale below, and the swing bench's replay — can
  // read it without importing the game.

  /// Portrait-shaped on purpose: the field is a wedge 56 paces across and
  /// only 38 deep, so a landscape viewport letterboxes it.
  static const double viewportWidth = 67;
  static const double viewportHeight = 145;

  static double get wideZoom => Look.now.wideZoom;
  static double get tightZoom => Look.now.tightZoom;
  // The playing view is a BAND between the scoreboard and the cards, not
  // the whole screen, so the camera has to aim at the middle of that band
  // rather than the middle of the glass. Aim at the screen centre and the
  // batter ends up behind the cards.
  static double get wideLook => Look.now.wideLook;
  static double get tightLook => Look.now.tightLook;

  /// Out is slower than in; snapping out of a close-up reads as a cut.
  static const double zoomOutRate = 3.2;
  static const double zoomInRate = 5.0;

  /// Where the HUD's opaque bands fall, as fractions of the screen height.
  ///
  /// The playing view is a BAND: scoreboard above, cards and the tap area
  /// below, field between. The game gets these from Flutter layout; they
  /// are stated here so the swing bench can frame its replay the same way
  /// and so [tightLook] has something to be derived against.
  ///
  /// A 48pt at-bat figure still clears both edges (head well below the
  /// scoreboard, the low point of the swing above the cards — see
  /// figure_scale_test). The art checklist's 120/554 split would put those
  /// feet behind the cards at this camera, so the bands stay where the
  /// HUD actually is.
  static const double bandTop = 0.235;
  static const double bandBottom = 0.787;

  /// Logical pixels per world unit at [zoom] on the reference phone.
  static double referencePixelsPerUnit(double zoom) =>
      LookDefaults.referenceScreenWidth * zoom / viewportWidth;

  /// World y at [fractionDown] of the full portrait screen (0 is the top),
  /// with the camera aimed at [look]. This is the game's viewfinder, which
  /// centres the whole screen, not the band.
  static double worldYOnScreen({
    required double zoom,
    required double look,
    required double fractionDown,
  }) => look + (fractionDown - 0.5) * (viewportHeight / zoom);

  // --- how big a man is ------------------------------------------------
  //
  // FIGURES SHRINK AS THE CAMERA PUSHES IN. This is the thing that makes
  // the mound look like it is sixty feet away instead of two paces.
  //
  // Held at one size, a figure is 1.65 body heights from the plate to the
  // mound; real baseball is ten or eleven. Drawn small at the close view
  // and large at the wide one, the close view gets to about five while the
  // wide view keeps men big enough to read as markers for WHERE PEOPLE
  // ARE, which is all they need to be when you are picking a scheme.
  //
  // It costs nothing in the simulation: not one of these numbers is read
  // by anything that decides an outcome.

  /// A man at the wide view: deliberately oversized, 16% of the field's
  /// depth, so he reads at a glance.
  static double get figureHeightWide => Look.now.figureHeightWide;

  /// A man at the at-bat view. 48 points tall on a 390pt screen — one art
  /// pixel per point, the native FIELD caveman. Was 34pt (1.56 world units).
  static double get figureHeightTight => Look.now.figureHeightTight;

  /// Kept for anything that wants the unzoomed size.
  static double get figureHeight => figureHeightWide;

  static double figureHeightFor(double zoom) {
    final t = ((zoom - wideZoom) / (tightZoom - wideZoom)).clamp(0.0, 1.0);
    return figureHeightWide + (figureHeightTight - figureHeightWide) * t;
  }

  /// How tall a man standing at [fieldY] is drawn. The zoom decides the
  /// near size; the distance does the rest. A deep fielder at the old
  /// uniform height was the single loudest thing saying "this is a board,
  /// not a field".
  static double figureHeightAt(double zoom, double fieldY) =>
      figureHeightFor(zoom) * depthScale(fieldY);

  /// Models — bags, the rock, standing stones — at a place on the field.
  static double modelScaleAt(double zoom, double fieldY) =>
      modelScaleFor(zoom) * depthScale(fieldY);

  /// The man-height the models — bags, the rock, standing stones — were
  /// drawn against. A CONSTANT, deliberately.
  ///
  /// [modelScaleFor] used to divide by `figureHeightWide`, which looks
  /// equivalent and is not: that number is a CAMERA setting, so re-aiming
  /// the fielding view silently resized every object on the field. It was
  /// dropped 4.6 -> 2.1 when the camera was set back and the rock came
  /// out nearly as big as the thrower.
  static const double modelsDrawnAgainst = 4.6;

  /// Everything drawn as a MODEL rather than as a marking on the ground
  /// scales with the figures — bases, the rock, the standing stones. The
  /// wedge, the chalk and the base paths do not: those are the field
  /// itself, and the field does not change size.
  static double modelScaleFor(double zoom) =>
      figureHeightFor(zoom) / modelsDrawnAgainst;

  // --- the projection --------------------------------------------------
  //
  // FAKE 3D. The camera sits [Look.camDepth] paces behind home plate and
  // looks down the field, so everything is divided by how far away it is:
  //
  //     k(d) = camDepth / (camDepth + d)
  //
  // and the whole projection is the old flat shear with `d` replaced by
  // `d * k(d)`. That single substitution buys all three cues at once —
  // the foul lines CONVERGE, the deep field COMPRESSES, and men standing
  // far away are DRAWN SMALLER — which is what lets the camera be pushed
  // in on the batter and still show the outfield behind him.
  //
  // As camDepth goes to infinity k goes to 1 and this is exactly the flat
  // shear it replaced, so the dial spans both looks with no second mode.

  /// How much the world shrinks at [fieldY]. 1 at the plate, falling
  /// toward 0 at the horizon, and GREATER than 1 in front of the plate —
  /// the backstop really is nearer the camera than the batter is.
  ///
  /// Clamped short of the camera itself: without it, anything at or
  /// behind `-camDepth` divides by zero and takes the frame with it.
  static double depthScale(double fieldY) {
    final camera = Look.now.camDepth;
    return camera / math.max(camera + fieldY, camera * 0.2);
  }

  /// Screen y of the horizon: where ground infinitely far away lands.
  /// Nothing on the field may be drawn at or above it.
  static double get horizonY => plateY - squash * Look.now.camDepth;

  /// Across the field. Needs the DEPTH as well, because how wide a pace
  /// is depends on how far away it is — that convergence is most of what
  /// makes the view read as three dimensional.
  static double x(double fieldX, [double fieldY = 0]) =>
      fieldX * depthScale(fieldY);

  static double y(double fieldY) =>
      plateY - squash * fieldY * depthScale(fieldY);

  /// Inverse, for turning a tap back into a place on the field.
  ///
  /// Solving `u = squash * d * c / (c + d)` for d, where `u` is how far
  /// above the plate the tap landed. At `u = squash * c` the ray is
  /// parallel to the ground and there is no answer — that is the horizon.
  static double fieldY(double renderY) {
    final c = Look.now.camDepth;
    final u = plateY - renderY;
    final limit = squash * c;
    if (u >= limit) return double.infinity;
    return u * c / (limit - u);
  }

  /// Inverse of [x]. The depth has to be known first, because a pace is
  /// worth fewer render units the further out it is.
  static double fieldX(double renderX, [double atFieldY = 0]) =>
      renderX / depthScale(atFieldY);

  /// An ellipse lying FLAT on the ground at [fieldY], [radius] paces
  /// across. Everything round on this field — the mound, a reach ring, a
  /// shadow — is one of these, and all of them were getting the squash
  /// but not the distance.
  static Rect groundOval(double fieldX, double fieldY, double radius) {
    final k = depthScale(fieldY);
    return Rect.fromCenter(
      center: Offset(x(fieldX, fieldY), y(fieldY)),
      width: radius * 2 * k,
      height: radius * 2 * k * squash,
    );
  }

  /// How high a ball is above the ground, as it arcs through its carry,
  /// in RENDER units — so it shrinks with distance like everything else.
  /// Without [atFieldY] a ball lofted into the outfield climbs as high on
  /// screen as one popped up over the plate.
  static double arcHeight(
    double travelled,
    double carry, [
    double atFieldY = 0,
  ]) {
    if (carry <= 0) return 0;
    final t = (travelled / carry).clamp(0.0, 1.0);
    return math.sin(t * math.pi) * carry * 0.16 * depthScale(atFieldY);
  }
}
