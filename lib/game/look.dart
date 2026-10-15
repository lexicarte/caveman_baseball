// Every number that decides how the game LOOKS, in one mutable place.
//
// These used to be `static const` scattered across Ground, FieldComponent,
// FieldSpec and the game. Constants are right for shipping and useless for
// tuning: you cannot drag a slider attached to one. So the constants moved
// here as DEFAULTS, the fields are mutable, and the old call sites now read
// `Look.now.squash` instead of `Ground.squash`.
//
// NOTHING IN `lib/sim/` READS THIS. Not one number below is allowed to
// change an outcome — if a look dial could decide a game, the bench would
// be a balance tool wearing a disguise, and tuning the picture would
// silently retune the sport. The one bridge is [fieldSpec], which hands
// the simulation a field built from the tuned distances, and that is
// deliberate: the diamond you see has to be the diamond that is played on.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../sim/field_spec.dart';

/// The shipped values. Changing one of these changes the game; changing the
/// matching field on [Look.now] only changes this run.
class LookDefaults {
  // --- field geometry, all in paces from home plate -------------------
  //
  // Tuned on the simulator 2026-10-11. The diamond is deliberately WIDER
  // than it is deep — 16.36 to the corners against 18.76 to second, which
  // renders at 1.76:1 — because it is seen from behind the plate.
  static const double cornerDistance = 16.364;
  static const double secondDistance = 18.764;
  static const double infieldRadius = 21.5;

  /// The outfield is where the green lives, and perspective eats it: the
  /// band between the apron and the wall compresses harder than anything
  /// else on screen because it is the furthest thing on it. 38 left a
  /// stripe of grass barely thicker than the chalk. This is a DRAWING
  /// distance — how long a ball takes to get anywhere is not derived from
  /// it, so widening the field does not quietly lengthen the game.
  static const double wallRadius = 54.0;
  static const double moundDistance = 11.273;
  static const double foulAngleDegrees = 48.0;

  // --- the ground plane -----------------------------------------------
  static const double squash = 0.70;
  static const double plateY = 14.5;

  /// How far BEHIND home plate the camera sits, in paces, which is the
  /// whole of the fake 3D. See `Ground.depthScale`: everything is divided
  /// by `(camDepth + depth)`, so the field narrows and shortens with
  /// distance instead of shearing uniformly. Large values approach the
  /// old flat shear; small values are a wide lens pressed up to the plate.
  static const double camDepth = 38.0;

  // --- the camera -------------------------------------------------------
  //
  // The FIELDING numbers moved when the camera was set back. Perspective
  // pulls the wall in from 26.6 render units deep to 13.3, so the whole
  // field now occupies about a quarter of the area it used to and the old
  // `1.0` framed a small patch in a sea of desert. The field's SHAPE is
  // unchanged — a perspective field is about 2:1, wide and shallow, same
  // as the sheared one was — so this is purely a re-aim.
  static const double wideZoom = 2.2;
  static const double tightZoom = 3.6;
  static const double wideLook = 7.1;
  static const double tightLook = 6.0;

  // --- how big a man is --------------------------------------------------
  //
  // `figureHeightWide` fell with the same arithmetic: a man has to stay
  // the same fraction of the SCREEN, and the fielding camera is now
  // 2.2x in, so 4.6 became 4.6 / 2.2. He is still deliberately oversized
  // at that view — he is a marker for where people are, not a portrait.
  static const double figureHeightWide = 2.1;
  static const double figureHeightTight = 1.56;

  /// How far off the rubber the thrower is DRAWN, in his own heights, so
  /// the rock is not hidden behind him. Render only.
  static const double throwerOffsetInHeights = 0.62;
}

/// The live values. One global instance, because the renderers are spread
/// across components that have no constructor path between them and
/// threading a settings object through every one of them would be worse
/// than a global for a bench.
class Look {
  Look();

  static Look now = Look();

  /// Bumped on every change so widgets can rebuild off it.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static void changed() => revision.value++;

  double cornerDistance = LookDefaults.cornerDistance;
  double secondDistance = LookDefaults.secondDistance;
  double infieldRadius = LookDefaults.infieldRadius;
  double wallRadius = LookDefaults.wallRadius;
  double moundDistance = LookDefaults.moundDistance;

  double squash = LookDefaults.squash;
  double plateY = LookDefaults.plateY;
  double camDepth = LookDefaults.camDepth;

  double wideZoom = LookDefaults.wideZoom;
  double tightZoom = LookDefaults.tightZoom;
  double wideLook = LookDefaults.wideLook;
  double tightLook = LookDefaults.tightLook;

  double figureHeightWide = LookDefaults.figureHeightWide;
  double figureHeightTight = LookDefaults.figureHeightTight;

  double throwerOffsetInHeights = LookDefaults.throwerOffsetInHeights;

  /// The field the SIMULATION plays on, built from the tuned distances so
  /// that what is drawn and what is played are the same field.
  FieldSpec get fieldSpec => FieldSpec(
    wallRadius: wallRadius,
    foulAngleDegrees: LookDefaults.foulAngleDegrees,
    baseDistance: cornerDistance,
    secondDistance: secondDistance,
    moundDistance: moundDistance,
  );

  /// The rendered diamond's aspect: how wide it is against how deep it
  /// looks. A player reads this as "how far over the field am I looking
  /// from". 1.0 is a square seen top-down.
  ///
  /// Measured through the live projection rather than from the formula,
  /// because with the camera set back the two are no longer the same: a
  /// near corner is pushed out and a far bag pulled in.
  double get diamondAspect {
    final corner = cornerDistance / math.sqrt2;
    final width = 2 * corner * camDepth / (camDepth + corner);
    final depth =
        squash *
        (secondDistance * camDepth / (camDepth + secondDistance) -
            0.0); // plate is at 0
    return depth <= 0 ? 0 : width / depth;
  }

  // --- persistence --------------------------------------------------
  //
  // Each entry is NAME -> (read, write). One list so saving, loading,
  // resetting, the slider table and the Dart dump cannot drift apart:
  // adding a dial in one place adds it everywhere.
  Map<String, double> toMap() => {
    for (final d in dials) d.name: d.get(this),
  };

  void applyMap(Map<String, dynamic> m) {
    for (final d in dials) {
      final v = m[d.name];
      if (v is num) d.set(this, v.toDouble());
    }
    changed();
  }

  void reset() {
    for (final d in dials) {
      d.set(this, d.shipped);
    }
    changed();
  }

  String toJson() => jsonEncode(toMap());

  /// The current values as Dart source, so a tuning session can be made
  /// permanent by pasting over [LookDefaults] rather than by remembering
  /// six numbers.
  String toDartSource() {
    final b = StringBuffer();
    for (final d in dials) {
      final changedFromShipped = (d.get(this) - d.shipped).abs() > 1e-9;
      b.writeln(
        '  static const double ${d.name} = '
        '${d.get(this).toStringAsFixed(3)};'
        '${changedFromShipped ? '  // was ${d.shipped.toStringAsFixed(3)}' : ''}',
      );
    }
    return b.toString();
  }

  static const groupDistances = 'DISTANCES FROM HOME';
  static const groupGround = 'GROUND';
  static const groupCamera = 'CAMERA';
  static const groupFigures = 'FIGURES';

  /// The headings, in the order the bench shows them.
  static const List<String> groups = [
    groupDistances,
    groupGround,
    groupCamera,
    groupFigures,
  ];

  static List<Dial> inGroup(String g) =>
      [for (final d in dials) if (d.group == g) d];

  static final List<Dial> dials = [
    Dial(groupDistances, 'cornerDistance', 'home to 1st/3rd', 6, 26,
        LookDefaults.cornerDistance,
        (l) => l.cornerDistance, (l, v) => l.cornerDistance = v, 'paces'),
    Dial(groupDistances, 'secondDistance', 'home to 2nd', 8, 40,
        LookDefaults.secondDistance,
        (l) => l.secondDistance, (l, v) => l.secondDistance = v, 'paces'),
    Dial(groupDistances, 'moundDistance', 'home to pitcher', 4, 24,
        LookDefaults.moundDistance,
        (l) => l.moundDistance, (l, v) => l.moundDistance = v, 'paces'),
    Dial(groupDistances, 'infieldRadius', 'home to infield edge', 10, 40,
        LookDefaults.infieldRadius,
        (l) => l.infieldRadius, (l, v) => l.infieldRadius = v, 'paces'),
    Dial(groupDistances, 'wallRadius', 'home to outfield wall', 20, 70,
        LookDefaults.wallRadius,
        (l) => l.wallRadius, (l, v) => l.wallRadius = v, 'paces'),
    Dial(groupGround, 'squash', 'ground tilt', 0.35, 1.0, LookDefaults.squash,
        (l) => l.squash, (l, v) => l.squash = v, ''),
    Dial(groupGround, 'plateY', 'plate height on screen', 2, 30,
        LookDefaults.plateY,
        (l) => l.plateY, (l, v) => l.plateY = v, ''),
    Dial(groupGround, 'camDepth', 'camera set back', 10, 160,
        LookDefaults.camDepth,
        (l) => l.camDepth, (l, v) => l.camDepth = v, 'paces'),
    Dial(groupCamera, 'tightZoom', 'batting zoom', 1.0, 7.0,
        LookDefaults.tightZoom,
        (l) => l.tightZoom, (l, v) => l.tightZoom = v, 'x'),
    Dial(groupCamera, 'tightLook', 'batting aim', -14, 22,
        LookDefaults.tightLook,
        (l) => l.tightLook, (l, v) => l.tightLook = v, ''),
    Dial(groupCamera, 'wideZoom', 'fielding zoom', 0.4, 3.0,
        LookDefaults.wideZoom,
        (l) => l.wideZoom, (l, v) => l.wideZoom = v, 'x'),
    Dial(groupCamera, 'wideLook', 'fielding aim', -24, 14,
        LookDefaults.wideLook,
        (l) => l.wideLook, (l, v) => l.wideLook = v, ''),
    Dial(groupFigures, 'figureHeightTight', 'man size, batting', 0.5, 5.0,
        LookDefaults.figureHeightTight,
        (l) => l.figureHeightTight, (l, v) => l.figureHeightTight = v, ''),
    Dial(groupFigures, 'figureHeightWide', 'man size, fielding', 1.5, 10.0,
        LookDefaults.figureHeightWide,
        (l) => l.figureHeightWide, (l, v) => l.figureHeightWide = v, ''),
    Dial(groupFigures, 'throwerOffsetInHeights', 'pitcher off centre', 0, 2.0,
        LookDefaults.throwerOffsetInHeights,
        (l) => l.throwerOffsetInHeights,
        (l, v) => l.throwerOffsetInHeights = v, 'ht'),
  ];
}

/// One tunable: how to read it, how to write it, and what it ships at.
class Dial {
  Dial(this.group, this.name, this.label, this.min, this.max, this.shipped,
      this.get, this.set, this.unit);

  /// The heading this dial sits under on the bench. Carried by the dial
  /// rather than by the layout so that adding one cannot silently file it
  /// under the wrong heading, or off the end of the list.
  final String group;

  final String name;

  /// What the bench calls it. The field name is for the Dart dump.
  final String label;
  final double min;
  final double max;
  final double shipped;
  final double Function(Look) get;
  final void Function(Look, double) set;
  final String unit;
}
