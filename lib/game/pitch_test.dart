// The five swings the pitch test plays, and the clock that plays them.
//
// Nothing here loops. [PitchSequence.go] runs the shots once, in order,
// then sits still. Each shot is a real swing through the resolver and a
// real batted flight, so "foul left" and "along the line" are the game's
// own answers, not a drawing of an arrow.
//
// Where in the swing the bat meets the rock is the calibration. Direction
// is not: the earliest contact is the early edge of the window, the lines
// are the foul angle, and the centre is dead on. STIK is the club, because
// its spray reaches past the lines, which is what makes the two foul shots
// and the two fair shots four different balls.
import 'dart:math' as math;

import '../data/clubs.dart';
import '../data/rocks.dart';
import '../model/player.dart';
import '../sim/ball_flight.dart';
import '../sim/swing_resolver.dart';
import 'caveman_baseball_game.dart';
import 'components/caveman.dart';
import 'ground.dart';
import 'look.dart';
import 'swing_timing.dart';

/// Play order. Declaration order is the order [PitchSequence] runs.
enum PitchShot {
  /// Edge of the window, pulled. Leaves foul down the left side.
  earliestFoul,

  /// Other edge, pushed. Leaves foul down the right side.
  latestFoul,

  /// No timing error. Leaves up the middle.
  centre,

  /// Earliest contact that is still fair: the 3rd-base line.
  fairThird,

  /// Latest contact that is still fair: the 1st-base line.
  fairFirst;

  String get label => switch (this) {
    PitchShot.earliestFoul => 'EARLIEST — foul left',
    PitchShot.latestFoul => 'LATEST — foul right',
    PitchShot.centre => 'CENTRE',
    PitchShot.fairThird => 'FAIR — 3rd base line',
    PitchShot.fairFirst => 'FAIR — 1st base line',
  };
}

/// How long the batted rock stays on screen after contact, before the gap.
const double pitchTestCarrySeconds = 1.05;

/// Batting camera, a step closer and aimed lower so the two men fill the
/// pitch test. Added to [Ground.tightZoom] and [Ground.tightLook]. A larger
/// look sits closer to the plate, which is down the screen.
const double pitchTestZoomBoost = 0.55;
const double pitchTestLookDown = 4.6;

/// Bat-swing camera. Tighter still, and aimed at the batter's body. The
/// pitcher is not drawn in that mode.
const double batTestZoomBoost = 1.7;

double get pitchTestZoom => Ground.tightZoom + pitchTestZoomBoost;
double get pitchTestLook => Ground.tightLook + pitchTestLookDown;
double get batTestZoom => Ground.tightZoom + batTestZoomBoost;

/// World y the bat-swing camera looks at: a little above the batter's feet,
/// so a taller calibrated batter stays in frame.
double batTestLook(SwingTiming timing) {
  final y = CavemanBaseballGame.batterY;
  final feet = Ground.y(y);
  final height =
      Ground.figureHeightAt(batTestZoom, y) * timing.scaleFor(batter: true);
  final drawn = CavemanPainter.drawnHeight(Archetype.steady, height);
  return feet - drawn * 0.55;
}

/// Vertical world span of a stage that fills [width] by [height] at [zoom],
/// aimed at [look]. The same framing [StagePainter] uses with the crop off.
({double top, double bottom}) stageWorldSpan({
  required double width,
  required double height,
  required double zoom,
  required double look,
}) {
  if (width <= 0 || height <= 0 || zoom <= 0) {
    return (top: look, bottom: look);
  }
  final aspect = width / height;
  final boxW = math.min(width, height * aspect);
  final boxH = boxW / aspect;
  final unit = boxW * zoom / Ground.viewportWidth;
  final half = boxH / 2 / unit;
  return (top: look - half, bottom: look + half);
}

/// Head and feet of a steady man, in world y. Head is the smaller number.
({double head, double feet}) steadyManExtent({
  required double fieldY,
  required double zoom,
  required double scale,
}) {
  final feet = Ground.y(fieldY);
  final height = Ground.figureHeightAt(zoom, fieldY) * scale;
  final drawn = CavemanPainter.drawnHeight(Archetype.steady, height);
  return (head: feet - drawn, feet: feet);
}

/// Timing error, in seconds, that produces [shot] on STIK.
///
/// The edges are the whole window. The lines are the foul angle as a
/// fraction of STIK's spray, which is past that angle on purpose. The
/// centre is zero.
double timingErrorFor(PitchShot shot, SwingTiming timing) {
  final spray = Clubs.stik.maxSpray;
  final edge = spray.abs() < 1e-9
      ? 1.0
      : (LookDefaults.foulAngleDegrees / spray).clamp(0.0, 1.0);
  final n = switch (shot) {
    PitchShot.earliestFoul => -1.0,
    PitchShot.latestFoul => 1.0,
    PitchShot.centre => 0.0,
    PitchShot.fairThird => -edge,
    PitchShot.fairFirst => edge,
  };
  return n * timing.window;
}

/// Swing phase at which [shot] meets the rock.
double phaseOf(PitchShot shot, SwingTiming timing) => switch (shot) {
  PitchShot.earliestFoul => timing.earliestHit,
  PitchShot.latestFoul => timing.latestHit,
  PitchShot.centre => timing.centreHit,
  PitchShot.fairThird => timing.fairEarly,
  PitchShot.fairFirst => timing.fairLate,
};

/// One scripted swing, resolved once. The phase is not in here: it is read
/// live from the sliders so dragging a mark retimes the bat without
/// re-rolling the rock.
class PitchShotPicture {
  const PitchShotPicture({
    required this.shot,
    required this.timingError,
    required this.swing,
    required this.flight,
  });

  final PitchShot shot;
  final double timingError;
  final SwingOutcome swing;
  final BallFlight flight;

  bool get foul => flight.foul;

  /// Degrees off centre at rest. Negative is the left-field side.
  double get angleDegrees =>
      math.atan2(flight.restPoint.x, flight.restPoint.y) * 180 / math.pi;
}

/// The five pictures. Built once: the directions do not depend on the
/// phase sliders, and rebuilding a flight every frame is a lot of steps
/// for a number that is not changing.
class PitchShots {
  PitchShots({SwingResolver? resolver, BallFlightSim? flights})
    : _resolver = resolver ?? const SwingResolver(),
      _flights = flights ?? const BallFlightSim() {
    for (final shot in PitchShot.values) {
      pictures[shot] = _make(shot);
    }
  }

  final SwingResolver _resolver;
  final BallFlightSim _flights;
  final pictures = <PitchShot, PitchShotPicture>{};

  PitchShotPicture operator [](PitchShot shot) => pictures[shot]!;

  PitchShotPicture _make(PitchShot shot) {
    final timing = SwingTiming.shipped;
    final error = timingErrorFor(shot, timing);
    final swing = _resolver.resolve(
      timingError: error,
      club: Clubs.stik,
      rock: Rocks.plain,
      jitter: 0,
      timingWindow: timing.window,
    );
    final flight = _flights.fly(
      exitSpeed: swing.exitSpeed,
      sprayDegrees: swing.sprayDegrees,
      nominalCarry: swing.carry,
      rock: Rocks.plain,
      field: Look.now.fieldSpec,
      rng: math.Random(7),
    );
    return PitchShotPicture(
      shot: shot,
      timingError: error,
      swing: swing,
      flight: flight,
    );
  }
}

/// Where the rock is along a flight, [t] seconds after contact.
({double x, double y}) sampleFlight(BallFlight flight, double t) {
  final path = flight.path;
  if (path.isEmpty) return (x: 0, y: 0);
  if (t <= path.first.time) {
    return (x: path.first.position.x, y: path.first.position.y);
  }
  for (var i = 1; i < path.length; i++) {
    if (path[i].time >= t) {
      final prev = path[i - 1];
      final span = path[i].time - prev.time;
      final f = span <= 0 ? 0.0 : (t - prev.time) / span;
      final pos = prev.position + (path[i].position - prev.position) * f;
      return (x: pos.x, y: pos.y);
    }
  }
  final last = path.last.position;
  return (x: last.x, y: last.y);
}

/// The rock the stage should draw.
class LabRock {
  const LabRock({required this.x, required this.y, required this.lift});

  final double x;
  final double y;
  final double lift;
}

/// One shot, measured from the start of its wind-up.
class ShotClock {
  ShotClock({required this.timing, required this.shot, required this.mound});

  final SwingTiming timing;
  final PitchShot shot;

  /// Thrower's depth. The rock leaves from here.
  final double mound;

  double get release => timing.windUpSeconds;

  double get flightSeconds => timing.flightFor(Rocks.plain.id, slow: false);

  /// Seconds from the start of the shot to the rock reaching the bat.
  double get contact => release + timing.contactInstant(flightSeconds, mound);

  double get phase => phaseOf(shot, timing);

  double get swingLength => timing.swingPlaySeconds;

  /// When the bat starts, so that [phase] lands on [contact].
  double get swingStart => contact - phase * swingLength;

  double get swingEnd => swingStart + swingLength;

  /// Wind-up, flight, and whatever of the swing is still going.
  double get pitchedUntil => math.max(release + flightSeconds, swingEnd);

  double get carryUntil => pitchedUntil + pitchTestCarrySeconds;

  /// Includes the gap before the next shot.
  double get end => carryUntil + timing.pitchGap;

  double? swingPhase(double t) {
    if (swingLength <= 0) return null;
    if (t < swingStart || t >= swingEnd) return null;
    final u = (t - swingStart) / swingLength;
    return u >= 1 ? null : u;
  }

  LabRock rockAt(double t, BallFlight flight) {
    if (t < release) {
      return LabRock(
        x: 0,
        y: mound,
        lift: CavemanBaseballGame.rockLift(mound, mound),
      );
    }
    if (t < contact) {
      final u = flightSeconds <= 0
          ? 1.0
          : ((t - release) / flightSeconds).clamp(0.0, 1.0);
      final depth = mound * (1 - u);
      return LabRock(
        x: 0,
        y: depth,
        lift: CavemanBaseballGame.rockLift(depth, mound),
      );
    }
    final at = sampleFlight(flight, t - contact);
    final travelled = math.sqrt(at.x * at.x + at.y * at.y);
    final lift = flight.airborne
        ? Ground.arcHeight(travelled, flight.carry, at.y)
        : 0.0;
    return LabRock(x: at.x, y: at.y, lift: lift);
  }
}

/// Plays [PitchShot.values] once. Idle until [go].
class PitchSequence {
  int index = -1;
  double time = 0;

  bool get running => index >= 0 && index < PitchShot.values.length;

  PitchShot? get shot => running ? PitchShot.values[index] : null;

  void go() {
    index = 0;
    time = 0;
  }

  void stop() {
    index = -1;
    time = 0;
  }

  void tick(double dt, SwingTiming timing, {required double mound}) {
    if (!running || dt <= 0) return;
    time += dt;
    final end = ShotClock(timing: timing, shot: shot!, mound: mound).end;
    if (time < end) return;
    time = 0;
    index += 1;
    if (!running) stop();
  }
}

/// What the pitch-test stage and its caption should show right now.
class PitchTestFrame {
  const PitchTestFrame({
    required this.running,
    required this.caption,
    required this.swingPhase,
    required this.rock,
    this.shot,
  });

  final bool running;
  final String caption;
  final double? swingPhase;
  final LabRock rock;
  final PitchShot? shot;
}

PitchTestFrame pitchTestFrame({
  required PitchSequence sequence,
  required PitchShots shots,
  required SwingTiming timing,
  required double mound,
}) {
  final held = LabRock(
    x: 0,
    y: mound,
    lift: CavemanBaseballGame.rockLift(mound, mound),
  );
  final shot = sequence.shot;
  if (shot == null) {
    return PitchTestFrame(
      running: false,
      caption: 'GO plays five pitches',
      swingPhase: null,
      rock: held,
    );
  }
  final clock = ShotClock(timing: timing, shot: shot, mound: mound);
  final picture = shots[shot];
  final where = picture.foul ? 'FOUL' : 'FAIR';
  final angle = picture.angleDegrees.abs().toStringAsFixed(0);
  final side = picture.angleDegrees < -0.5
      ? ' left'
      : (picture.angleDegrees > 0.5 ? ' right' : '');
  return PitchTestFrame(
    running: true,
    caption: '${sequence.index + 1}/5  ${shot.label}  ·  $where $angle°$side',
    swingPhase: clock.swingPhase(sequence.time),
    rock: clock.rockAt(sequence.time, picture.flight),
    shot: shot,
  );
}

/// One press of SWING in the bat test. Plays the swing once and stops.
class BatSwingPlayback {
  double elapsed = -1;

  bool get playing => elapsed >= 0;

  void swing() => elapsed = 0;

  void stop() => elapsed = -1;

  void tick(double dt, SwingTiming timing) {
    if (!playing || dt <= 0) return;
    elapsed += dt;
    if (elapsed >= timing.swingPlaySeconds) stop();
  }

  double? phase(SwingTiming timing) {
    if (!playing) return null;
    final length = timing.swingPlaySeconds;
    if (length <= 0) return null;
    final t = elapsed / length;
    return t >= 1 ? null : t;
  }
}
