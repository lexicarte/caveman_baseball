// The numbers that decide whether a swing can connect, and what they imply.
//
// Pure, so the chart and a test can both ask the same questions. Every
// default comes from the shipping code rather than being restated here —
// a calibration instrument that holds its own copy of the values is
// measuring the wrong thing.
import 'dart:math' as math;
import 'dart:ui';

import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../data/clubs.dart';
import '../data/rocks.dart';
import '../model/club.dart';
import '../model/player.dart';
import '../model/rock.dart';
import '../sim/ball_flight.dart';
import '../sim/fielder_spec.dart';
import '../sim/game_rules.dart';
import '../sim/swing_resolver.dart';
import 'components/caveman.dart';
import 'field_motion.dart';
import 'caveman_baseball_game.dart';
import 'components/caveman_cartoon.dart';
import 'ground.dart';
import 'look.dart';
import 'match_controller.dart';

/// Everything a swing's geometry depends on. Defaults are the live values.
class Calibration {
  const Calibration({
    this.flightSeconds = GameRules.pitchFlightSeconds,
    this.contactDepth = MatchController.contactDepth,
    double? batterX,
    double? batterY,
    this.handDrop = CavemanBaseballGame.handDrop,
    double? throwerDepth,
    // The TIGHT height, not the wide one: every measurement here is of a
    // swing, and the camera is held at the at-bat zoom for the whole of it.
    double? figureHeight,
    this.liftRelease,
    this.liftPlate,
    this.club = Clubs.stik,
    this.rock = Rocks.plain,
    this.timingWindow = GameRules.timingWindow,
    this.swingSeconds = CavemanBaseballGame.swingSeconds,
    this.slow = false,
    this.slowScale = GameRules.slowPitchScale,
    this.curve = SwingCurve.shipped,
  }) : _batterX = batterX,
       _batterY = batterY,
       _throwerDepth = throwerDepth,
       _figureHeight = figureHeight;

  final double flightSeconds;
  final double contactDepth;
  final double handDrop;

  // Null means "whatever the game is using right now". These cannot be
  // plain defaults any more: the look dials make them runtime values, and
  // a const default would freeze the bench at the shipped numbers while
  // the view beside it moved.
  final double? _batterX;
  final double? _batterY;
  final double? _throwerDepth;
  final double? _figureHeight;

  double get batterX => _batterX ?? CavemanBaseballGame.batterX;
  double get batterY => _batterY ?? CavemanBaseballGame.batterY;
  double get throwerDepth => _throwerDepth ?? Look.now.moundDistance;
  double get figureHeight => _figureHeight ?? Ground.figureHeightTight;

  /// Override the rock's height at release and at the plate. Null means
  /// derived — pitched so it meets the bat at [contactDepth], which is what
  /// the game does. Setting them is how you reproduce a broken trajectory:
  /// 2.8 and 0.8 put the rock at the batter's ankles when men were 34pt.
  /// At 48pt the bat sits about that high, so that pair is no longer a miss.
  final double? liftRelease;
  final double? liftPlate;

  final Club club;
  final Rock rock;

  /// How far either side of perfect a swing can be and still connect. One
  /// window for the whole game — not a club property.
  final double timingWindow;

  /// How long the bat takes to come round. The same for every club.
  final double swingSeconds;

  /// A slow pitch (NOK NOGGIN) multiplies the flight, so there is more of
  /// it to read.
  final bool slow;
  final double slowScale;

  /// The shape of the arc. Tunable, so the bat can be reshaped without
  /// editing the painter.
  final SwingCurve curve;

  Calibration copyWith({
    double? flightSeconds,
    double? contactDepth,
    double? batterX,
    double? batterY,
    double? handDrop,
    double? liftRelease,
    double? liftPlate,
    Club? club,
    Rock? rock,
    double? timingWindow,
    double? swingSeconds,
    bool? slow,
    double? slowScale,
    SwingCurve? curve,
  }) => Calibration(
    flightSeconds: flightSeconds ?? this.flightSeconds,
    contactDepth: contactDepth ?? this.contactDepth,
    batterX: batterX ?? this.batterX,
    batterY: batterY ?? this.batterY,
    handDrop: handDrop ?? this.handDrop,
    throwerDepth: throwerDepth,
    figureHeight: figureHeight,
    liftRelease: liftRelease ?? this.liftRelease,
    liftPlate: liftPlate ?? this.liftPlate,
    club: club ?? this.club,
    rock: rock ?? this.rock,
    timingWindow: timingWindow ?? this.timingWindow,
    swingSeconds: swingSeconds ?? this.swingSeconds,
    slow: slow ?? this.slow,
    slowScale: slowScale ?? this.slowScale,
    curve: curve ?? this.curve,
  );

  double get drawnHeight => figureHeight * 1.04;

  /// The flight actually used, after a slow pitch has had its say.
  double get flight => slow ? flightSeconds * slowScale : flightSeconds;

  /// The instant a perfectly timed swing scores.
  double get contactTime => flight * (1 - contactDepth / throwerDepth);

  /// How far out the rock is at time [t].
  double depthAt(double t) => throwerDepth * (1 - (t / flight).clamp(0.0, 1.0));

  /// Where the rock is drawn, in render units.
  ///
  /// Anchored at the two ends the player can see — the thrower's hand and
  /// the bat — exactly as `CavemanBaseballGame.rockLift` does, so the
  /// bench and the game cannot describe different pitches.
  Offset rockAt(double t) {
    final depth = depthAt(t);
    final atHand =
        liftRelease ?? (handDrop * drawnHeight * Ground.depthScale(throwerDepth));
    final double lift;
    if (throwerDepth <= contactDepth) {
      lift = atHand;
    } else {
      final atBat = liftPlate ?? (Ground.y(contactDepth) - batHeight);
      final f =
          ((depth - contactDepth) / (throwerDepth - contactDepth)).clamp(
            0.0,
            1.0,
          );
      lift = atBat + (atHand - atBat) * f;
    }
    // Straight down the middle. See CavemanBaseballGame._pitchBall.
    return Offset(0, Ground.y(depth) - lift);
  }

  /// Screen height the bat sweeps at.
  double get batHeight => Ground.y(batterY) - handDrop * drawnHeight;

  /// The club, hand and tip, at raw swing phase [t]. In render units.
  ///
  /// NOTE [t] is the RAW phase, 0..1 through the animation — not
  /// `CartoonCavemanPainter.contactAt`, which is a fraction of the ARC
  /// after easing. Confusing the two reads the club at the wrong moment;
  /// it is the first mistake this instrument made about itself.
  ({Offset hand, Offset tip}) clubAt(double t) {
    final g = CartoonCavemanPainter.swingGeometry(
      figureHeight,
      Archetype.steady,
      t,
      curve: curve,
    );
    final feet = Offset(Ground.x(batterX, batterY), Ground.y(batterY));
    return (hand: feet + g.hand, tip: feet + g.tip);
  }

  Offset tipAt(double t) => clubAt(t).tip;

  /// The raw phase at which the eased arc reaches the contact point.
  ///
  /// Exact by construction: the curve's two segments meet at `whip`, and
  /// `ease(whip)` is `contactAt`. It used to be solved for numerically,
  /// which was correct but hid that the two are the same number.
  double get contactPhase => curve.whip;

  /// When the rock crosses the bat's height, and how far that is from the
  /// moment a swing actually scores.
  ///
  /// This is the whole point of the instrument. With no timing meter the
  /// player swings at what they see, so any gap here is error they can
  /// neither perceive nor correct for — it was 214ms once, which is wider
  /// than every club window in the game.
  ({double atTime, double errorMs})? crossing() {
    const steps = 2000;
    for (var i = 1; i <= steps; i++) {
      final t0 = flight * (i - 1) / steps;
      final t1 = flight * i / steps;
      final a = rockAt(t0).dy - batHeight;
      final b = rockAt(t1).dy - batHeight;
      if (a.sign != b.sign) {
        final f = a.abs() / (a.abs() + b.abs());
        final t = t0 + (t1 - t0) * f;
        return (atTime: t, errorMs: (t - contactTime) * 1000);
      }
    }
    return null;
  }

  /// Closest the CLUB comes to the rock at the scoring instant.
  ///
  /// Measured to the whole shaft, hand to tip — not to the tip. The rock
  /// is struck by the middle of the bat far more often than by its end,
  /// and measuring the tip reports a miss on a perfectly good swing. That
  /// was the second mistake this instrument made about itself.
  double gapAtContact() {
    final rock = rockAt(contactTime);
    var best = double.infinity;
    for (var i = 0; i <= 240; i++) {
      final c = clubAt(i / 240);
      final d = _pointToSegment(rock, c.hand, c.tip);
      if (d < best) best = d;
    }
    return best;
  }

  static double _pointToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 <= 0) return (p - a).distance;
    var u = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
    u = u.clamp(0.0, 1.0);
    return (p - Offset(a.dx + ab.dx * u, a.dy + ab.dy * u)).distance;
  }

  static double msPerPace(double flightSeconds, double throwerDepth) =>
      flightSeconds / throwerDepth * 1000;

  /// Rock speed across the ground, paces per second.
  double get rockSpeed => throwerDepth / flight;

  double windowPaces(double windowSeconds) => rockSpeed * windowSeconds;

  static double clampd(double v, double lo, double hi) =>
      math.min(math.max(v, lo), hi);
}

/// The three swings worth looking at.
enum ContactCase {
  /// As early in the rock's path as the bat can still reach it.
  early,

  /// Dead on.
  centre,

  /// As late as the club will allow.
  late;

  String get label => switch (this) {
    ContactCase.early => 'EARLY',
    ContactCase.centre => 'CENTRE',
    ContactCase.late => 'LATE',
  };

  /// Where in the window this sits. The resolver works in these units.
  double get normalized => switch (this) {
    ContactCase.early => -1.0,
    ContactCase.centre => 0.0,
    ContactCase.late => 1.0,
  };
}

/// One swing, carried all the way through to where the rock stops.
class HitOutcome {
  const HitOutcome({
    required this.kind,
    required this.tapAt,
    required this.timingError,
    required this.swing,
    required this.flight,
  });

  final ContactCase kind;

  /// When the player would have tapped, in seconds into the flight.
  final double tapAt;
  final double timingError;
  final SwingOutcome swing;
  final BallFlight flight;

  /// How far the rock finishes from the plate, in paces.
  double get distance => flight.restPoint.length;

  /// Where it finishes, in degrees off dead centre. Negative is left field.
  double get angleDegrees =>
      math.atan2(flight.restPoint.x, flight.restPoint.y) * 180 / math.pi;

  bool get foul => flight.foul;
}

extension Hitting on Calibration {
  static const _resolver = SwingResolver();
  static const _flightSim = BallFlightSim();

  /// Runs one swing through the REAL resolver and the REAL flight
  /// simulation, with jitter off and a fixed seed so the picture is the
  /// same every time you look at it. A calibration instrument that wobbles
  /// is telling you about its dice, not your game.
  HitOutcome outcomeFor(ContactCase kind) {
    final error = kind.normalized * timingWindow;
    final swing = _resolver.resolve(
      timingError: error,
      club: club,
      rock: rock,
      jitter: 0,
    );
    final flight = _flightSim.fly(
      exitSpeed: swing.exitSpeed,
      sprayDegrees: swing.sprayDegrees,
      nominalCarry: swing.carry,
      rock: rock,
      field: Look.now.fieldSpec,
      rng: math.Random(7),
    );
    return HitOutcome(
      kind: kind,
      tapAt: contactTime + error,
      timingError: error,
      swing: swing,
      flight: flight,
    );
  }

  List<HitOutcome> get outcomes => [
    for (final k in ContactCase.values) outcomeFor(k),
  ];

  /// The club tip's height at [t] seconds into the whole flight, for a
  /// swing tapped at [tapAt]. Null before the swing starts or after it
  /// finishes — the bat only exists for 300ms.
  double? batHeightAt(double t, double tapAt) {
    final s = t - tapAt;
    if (s < 0 || s > swingSeconds) return null;
    return tipAt(s / swingSeconds).dy;
  }
}

/// A whole play, from release to the rock coming to rest, as something you
/// can scrub through. Driven entirely by the real simulation output.
class PlayClip {
  PlayClip(this.cal, this.outcome, this.scheme) {
    // The bat reaches the ball part-way into its sweep, not at the tap.
    // Switching the rock onto its batted path at the TAP makes it leap off
    // a bat that has not arrived yet, which is the single thing that most
    // makes a replay look wrong.
    contactMoment =
        outcome.tapAt + CavemanBaseballGame.swingSeconds * cal.contactPhase;

    final staffed = [for (final f in scheme.fielders) f];
    FielderSpec? best;
    Interception? bestGrab;
    for (final post in staffed) {
      if (!post.chases) continue;
      final grab = const BallFlightSim().chaseBy(post, outcome.flight);
      if (bestGrab == null || grab.time < bestGrab.time) {
        bestGrab = grab;
        best = post;
      }
    }
    chaser = best;
    grab = bestGrab;
    duration =
        contactMoment +
        math.max(outcome.flight.restTime, bestGrab?.time ?? 0) +
        0.8;
  }

  final Calibration cal;
  final HitOutcome outcome;
  final Scheme scheme;

  late final double contactMoment;
  late final double duration;
  late final FielderSpec? chaser;
  late final Interception? grab;

  bool struck(double t) => t >= contactMoment;

  /// The camera, exactly as the game drives it: held tight on the plate and
  /// the mound for the whole at-bat, then eased out the moment the rock is
  /// struck so you can see where it went.
  ///
  /// The game smooths frame by frame; this is the closed form of the same
  /// ease, so a scrubbed frame looks like the played one instead of
  /// depending on how you got there.
  ({double zoom, double look}) cameraAt(double t) {
    if (!struck(t)) {
      return (
        zoom: CavemanBaseballGame.tightZoom,
        look: CavemanBaseballGame.tightLook,
      );
    }
    final k = math.exp(-CavemanBaseballGame.zoomOutRate * (t - contactMoment));
    return (
      zoom:
          CavemanBaseballGame.wideZoom +
          (CavemanBaseballGame.tightZoom - CavemanBaseballGame.wideZoom) * k,
      look:
          CavemanBaseballGame.wideLook +
          (CavemanBaseballGame.tightLook - CavemanBaseballGame.wideLook) * k,
    );
  }

  /// Where the rock is at [t]: field x, field depth, and height above the
  /// ground. Inbound before contact, on its batted path after.
  ({double x, double y, double lift}) rockAt(double t) {
    if (!struck(t)) {
      final depth = cal.depthAt(t);
      return (
        // Straight down the middle.
        x: 0.0,
        y: depth,
        lift: CavemanBaseballGame.rockLift(depth, cal.throwerDepth),
      );
    }
    final s = t - contactMoment;
    final path = outcome.flight.path;
    var pos = path.isEmpty ? Vector2.zero() : path.last.position;
    for (var i = 1; i < path.length; i++) {
      if (path[i].time >= s) {
        final prev = path[i - 1];
        final span = path[i].time - prev.time;
        final f = span <= 0 ? 0.0 : (s - prev.time) / span;
        pos = prev.position + (path[i].position - prev.position) * f;
        break;
      }
    }
    final travelled = pos.length;
    final lift = outcome.flight.airborne && travelled < outcome.flight.carry
        ? Ground.arcHeight(travelled, outcome.flight.carry, pos.y)
        : 0.0;
    return (x: pos.x, y: pos.y, lift: lift);
  }

  /// 0..1 through the swing, or null when the bat is at rest.
  double? swingAt(double t) {
    final s = t - outcome.tapAt;
    if (s < 0 || s > cal.swingSeconds) return null;
    return s / cal.swingSeconds;
  }

  /// Where a defender stands at [t]. The chaser runs at the ball from the
  /// moment it is struck; everyone else holds his post.
  Placement fielderAt(FielderSpec post, double t) {
    final g = grab;
    if (g == null || chaser?.id != post.id || !struck(t)) {
      return Placement(post.position.x, post.position.y, const Pose.still());
    }
    return placeFielder(
      fromX: post.position.x,
      fromY: post.position.y,
      toX: g.point.x,
      toY: g.point.y,
      reactionTime: post.reactionTime,
      arriveAt: g.time,
      playback: t - contactMoment,
      stride: CavemanPainter.strideFor(
        Archetype.steady,
        Ground.figureHeightAt(Ground.tightZoom, post.position.y),
      ),
    );
  }
}
