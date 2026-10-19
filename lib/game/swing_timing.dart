// The numbers a swing is timed with, in one place the match and the
// calibration screen both read.
//
// Shipped values are taken from the code that already decided them —
// GameRules, the painter, the swing curve — rather than typed out again.
// [SwingTiming.now] starts as that shipped swing. Moving a slider replaces
// [now] immediately, so the pitch in front of you retimes without a
// restart. Nothing is written down until a preset is saved, and [reset]
// puts the shipped swing back, so a session of fiddling cannot become the
// game by accident.
import 'dart:convert';

import '../model/club.dart';
import '../model/rock.dart';
import '../sim/game_rules.dart';
import '../sim/swing_resolver.dart';
import 'components/caveman.dart';
import 'components/caveman_cartoon.dart';

/// Where one dial is allowed to sit. Shared by the sliders and by loading
/// a preset, so a saved file cannot push a value the slider could not.
class SwingDial {
  const SwingDial(this.min, this.max);

  final double min;
  final double max;

  double pin(double v) {
    if (!v.isFinite) return min;
    if (v < min) return min;
    if (v > max) return max;
    return v;
  }
}

class SwingDials {
  static const swingSeconds = SwingDial(0.12, 0.60);
  static const swingSpeed = SwingDial(0.25, 3.0);
  static const window = SwingDial(0.04, 0.45);
  static const windowOffset = SwingDial(-0.25, 0.25);
  static const pitchFlight = SwingDial(0.45, 2.40);
  static const rockSpeed = SwingDial(0.40, 2.50);
  static const pitchGap = SwingDial(0.15, 2.50);
  static const spriteContact = SwingDial(0.05, 0.95);
  static const whip = SwingDial(0.08, 0.75);
  static const contactAt = SwingDial(0.30, 0.95);
  static const approach = SwingDial(0.35, 2.50);
  static const follow = SwingDial(0.50, 3.0);
  static const windUp = SwingDial(0.05, 1.50);
  static const slowPitch = SwingDial(1.0, 2.50);
  static const slowWindow = SwingDial(1.0, 2.50);
  static const contactDepth = SwingDial(0.0, 4.0);
}

/// What Nok Noggin used to multiply the contact window by, before it was a
/// dial. The flight scale lives on [GameRules.slowPitchScale]; this one
/// lived as a literal in the match.
const double shippedSlowWindowScale = 1.35;

class SwingTiming {
  SwingTiming({
    double? swingSeconds,
    double? swingSpeed,
    double? window,
    double? windowOffset,
    double? pitchFlightSeconds,
    Map<String, double>? rockPitchSpeed,
    double? pitchGap,
    double? spriteContactFrame,
    double? whip,
    double? contactAt,
    double? approach,
    double? follow,
    double? windUpSeconds,
    double? slowPitchScale,
    double? slowWindowScale,
    double? contactDepth,
  }) : swingSeconds = SwingDials.swingSeconds.pin(
         swingSeconds ?? CavemanPainter.swingSeconds,
       ),
       swingSpeed = SwingDials.swingSpeed.pin(swingSpeed ?? 1),
       window = SwingDials.window.pin(window ?? GameRules.timingWindow),
       windowOffset = SwingDials.windowOffset.pin(windowOffset ?? 0),
       pitchFlightSeconds = SwingDials.pitchFlight.pin(
         pitchFlightSeconds ?? GameRules.pitchFlightSeconds,
       ),
       rockPitchSpeed = _speeds(rockPitchSpeed),
       pitchGap = SwingDials.pitchGap.pin(pitchGap ?? 0.70),
       spriteContactFrame = SwingDials.spriteContact.pin(
         spriteContactFrame ?? SwingCurve.shipped.contactAt,
       ),
       whip = SwingDials.whip.pin(whip ?? SwingCurve.shipped.whip),
       contactAt = SwingDials.contactAt.pin(
         contactAt ?? SwingCurve.shipped.contactAt,
       ),
       approach = SwingDials.approach.pin(
         approach ?? SwingCurve.shipped.approach,
       ),
       follow = SwingDials.follow.pin(follow ?? SwingCurve.shipped.follow),
       windUpSeconds = SwingDials.windUp.pin(
         windUpSeconds ?? GameRules.windUpSeconds,
       ),
       slowPitchScale = SwingDials.slowPitch.pin(
         slowPitchScale ?? GameRules.slowPitchScale,
       ),
       slowWindowScale = SwingDials.slowWindow.pin(
         slowWindowScale ?? shippedSlowWindowScale,
       ),
       // The controller owns this constant. It cannot be read from here
       // without an import cycle, and the calibration test is what keeps
       // the two from drifting.
       contactDepth = SwingDials.contactDepth.pin(contactDepth ?? 0.5);

  /// The swing the game ships with. [now] starts as this same value.
  static final shipped = SwingTiming();

  /// What the match, the swing animation and the calibration screen read.
  static SwingTiming now = shipped;

  /// Back to [shipped]. Does not touch a saved preset; clearing that is
  /// the preset store's job, so a reset actually survives the next launch.
  static void reset() => now = shipped;

  /// Seconds from the tap until the bat has finished, before [swingSpeed].
  final double swingSeconds;

  /// How fast that swing plays. 1 is the shipped duration.
  final double swingSpeed;

  /// How far either side of perfect still connects, in seconds.
  final double window;

  /// Shifts the on-time tap relative to the rock reaching contact depth.
  /// Negative means the batter has to have swung earlier. Zero is shipped:
  /// on time is the rock meeting the bat.
  final double windowOffset;

  /// Seconds from release to the plate, before a per-rock speed or a slow
  /// pitch. Every rock uses this until its own speed is set.
  final double pitchFlightSeconds;

  /// Per rock id, a multiplier on [pitchFlightSeconds]. Above 1 is a faster
  /// pitch. Missing entries are 1, so an untouched rock stays shipped.
  final Map<String, double> rockPitchSpeed;

  /// Pause between pitches on the calibration screen. The match does not
  /// insert it: the player already taps to move on, and a default pause
  /// would slow every game.
  final double pitchGap;

  /// Where in the swing (0..1) the sprite strip shows its contact frame.
  ///
  /// The frame itself sits at [spriteContactHome] of the strip, which is
  /// the same 0.67 as the procedural arc's contact. Leaving this at that
  /// home samples the strip in lockstep with swing time, which is how a
  /// swing looked before the dial existed. Dragging it toward [whip] puts
  /// the contact frame on screen when the procedural bat meets the rock.
  final double spriteContactFrame;

  /// Fraction of the swing's TIME at which the procedural bat meets the
  /// rock. Shipped at 0.30. This is not a fraction of the arc.
  final double whip;

  /// How far through the procedural ARC the bat is when it meets the rock.
  final double contactAt;

  /// Speed ramp of the procedural bat before contact. Below 1 whips.
  final double approach;

  /// Speed ramp after contact.
  final double follow;

  /// Seconds of wind-up before the rock is released. The swing timer does
  /// not run during it.
  final double windUpSeconds;

  /// What a slow pitch (NOK NOGGIN) multiplies the flight by.
  final double slowPitchScale;

  /// What a slow pitch multiplies the contact window by.
  final double slowWindowScale;

  /// How far in front of the plate, in paces, the rock is met. The pitch
  /// is drawn to arrive at the bat at this depth, and on time is that
  /// arrival plus [windowOffset].
  final double contactDepth;

  /// Strip phase of the contact frame. The same number as the procedural
  /// arc's shipped contact, so "0.67" means one thing in both drawings.
  static double get spriteContactHome => SwingCurve.shipped.contactAt;

  /// Seconds the bat is actually in motion.
  double get swingPlaySeconds => swingSeconds / swingSpeed;

  /// Speed multiplier for [rockId]. 1 when that rock has never been tuned.
  double speedFor(String rockId) => rockPitchSpeed[rockId] ?? 1;

  /// Flight seconds for [rockId], after its speed and, when [slow], the
  /// slow-pitch scale.
  double flightFor(String rockId, {required bool slow}) {
    final speed = speedFor(rockId);
    final safe = speed.abs() < 1e-6 ? 1.0 : speed;
    final seconds = pitchFlightSeconds / safe;
    return slow ? seconds * slowPitchScale : seconds;
  }

  /// When a perfectly timed tap lands, before [windowOffset].
  ///
  /// The same formula the match has always used: contact is
  /// [contactDepth] paces out, and the flight is linear from the mound.
  double contactInstant(double flightSeconds, double throwerDepth) {
    if (throwerDepth <= 0) return 0;
    return flightSeconds * (1 - contactDepth / throwerDepth);
  }

  /// The on-time tap: the rock meeting the bat, shifted by [windowOffset].
  double perfectTap(double flightSeconds, double throwerDepth) =>
      contactInstant(flightSeconds, throwerDepth) + windowOffset;

  /// The procedural bat, from the dials. Load and finish stay shipped —
  /// they are the shape of the arc, not when it arrives.
  SwingCurve get curve => SwingCurve(
    contactAt: contactAt,
    whip: whip,
    approach: approach,
    follow: follow,
  );

  /// Strip phase to sample at swing time [t] (0..1).
  ///
  /// Identity when the contact frame is shown at its home, so a shipped
  /// swing paints the same frames it always did.
  double spritePhase(double t) {
    final u = t.isNaN ? 0.0 : t.clamp(0.0, 1.0).toDouble();
    final home = spriteContactHome;
    if ((spriteContactFrame - home).abs() <= 1e-9) return u;
    final at = spriteContactFrame.clamp(0.02, 0.98).toDouble();
    if (u <= at) return home * (u / at);
    final tail = 1 - at;
    if (tail <= 1e-9) return 1;
    return (home + (1 - home) * ((u - at) / tail)).clamp(0.0, 1.0).toDouble();
  }

  /// One tap, judged the way the match judges it. Jitter is off: a
  /// calibration swing should answer timing, not the dice.
  SwingJudgement judge({
    required double tapAt,
    required double contactTime,
    required Club club,
    required Rock rock,
    double powerScale = 1,
    double windowScale = 1,
  }) {
    final error = tapAt - contactTime - windowOffset;
    final outcome = const SwingResolver().resolve(
      timingError: error,
      club: club,
      rock: rock,
      powerScale: powerScale,
      windowScale: windowScale,
      timingWindow: window,
      jitter: 0,
    );
    return SwingJudgement(timingError: error, outcome: outcome);
  }

  SwingTiming withRockSpeed(String rockId, double speed) {
    final next = Map<String, double>.of(rockPitchSpeed);
    next[rockId] = SwingDials.rockSpeed.pin(speed);
    return copyWith(rockPitchSpeed: next);
  }

  SwingTiming copyWith({
    double? swingSeconds,
    double? swingSpeed,
    double? window,
    double? windowOffset,
    double? pitchFlightSeconds,
    Map<String, double>? rockPitchSpeed,
    double? pitchGap,
    double? spriteContactFrame,
    double? whip,
    double? contactAt,
    double? approach,
    double? follow,
    double? windUpSeconds,
    double? slowPitchScale,
    double? slowWindowScale,
    double? contactDepth,
  }) => SwingTiming(
    swingSeconds: swingSeconds ?? this.swingSeconds,
    swingSpeed: swingSpeed ?? this.swingSpeed,
    window: window ?? this.window,
    windowOffset: windowOffset ?? this.windowOffset,
    pitchFlightSeconds: pitchFlightSeconds ?? this.pitchFlightSeconds,
    rockPitchSpeed: rockPitchSpeed ?? this.rockPitchSpeed,
    pitchGap: pitchGap ?? this.pitchGap,
    spriteContactFrame: spriteContactFrame ?? this.spriteContactFrame,
    whip: whip ?? this.whip,
    contactAt: contactAt ?? this.contactAt,
    approach: approach ?? this.approach,
    follow: follow ?? this.follow,
    windUpSeconds: windUpSeconds ?? this.windUpSeconds,
    slowPitchScale: slowPitchScale ?? this.slowPitchScale,
    slowWindowScale: slowWindowScale ?? this.slowWindowScale,
    contactDepth: contactDepth ?? this.contactDepth,
  );

  Map<String, Object> toMap() => {
    'swingSeconds': swingSeconds,
    'swingSpeed': swingSpeed,
    'window': window,
    'windowOffset': windowOffset,
    'pitchFlightSeconds': pitchFlightSeconds,
    'rockPitchSpeed': rockPitchSpeed,
    'pitchGap': pitchGap,
    'spriteContactFrame': spriteContactFrame,
    'whip': whip,
    'contactAt': contactAt,
    'approach': approach,
    'follow': follow,
    'windUpSeconds': windUpSeconds,
    'slowPitchScale': slowPitchScale,
    'slowWindowScale': slowWindowScale,
    'contactDepth': contactDepth,
  };

  String toJson() => const JsonEncoder.withIndent('  ').convert(toMap());

  factory SwingTiming.fromJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('swing timing must be a JSON object');
    }
    return SwingTiming.fromMap(decoded.map((k, v) => MapEntry('$k', v)));
  }

  factory SwingTiming.fromMap(Map<String, Object?> json) {
    final speeds = <String, double>{};
    final rawSpeeds = json['rockPitchSpeed'];
    if (rawSpeeds is Map) {
      for (final entry in rawSpeeds.entries) {
        final v = entry.value;
        if (v is num && v.isFinite) {
          speeds['${entry.key}'] = v.toDouble();
        }
      }
    }
    return SwingTiming(
      swingSeconds: _num(json['swingSeconds']),
      swingSpeed: _num(json['swingSpeed']),
      window: _num(json['window']),
      windowOffset: _num(json['windowOffset']),
      pitchFlightSeconds: _num(json['pitchFlightSeconds']),
      rockPitchSpeed: speeds,
      pitchGap: _num(json['pitchGap']),
      spriteContactFrame: _num(json['spriteContactFrame']),
      whip: _num(json['whip']),
      contactAt: _num(json['contactAt']),
      approach: _num(json['approach']),
      follow: _num(json['follow']),
      windUpSeconds: _num(json['windUpSeconds']),
      slowPitchScale: _num(json['slowPitchScale']),
      slowWindowScale: _num(json['slowWindowScale']),
      contactDepth: _num(json['contactDepth']),
    );
  }

  static double? _num(Object? raw) =>
      raw is num && raw.isFinite ? raw.toDouble() : null;

  static Map<String, double> _speeds(Map<String, double>? raw) {
    if (raw == null || raw.isEmpty) return const {};
    return Map.unmodifiable({
      for (final entry in raw.entries)
        entry.key: SwingDials.rockSpeed.pin(entry.value),
    });
  }
}

/// A swing the calibration screen can print, and a test can assert on.
class SwingJudgement {
  const SwingJudgement({required this.timingError, required this.outcome});

  /// Seconds off the on-time tap. Negative is early, positive is late.
  final double timingError;
  final SwingOutcome outcome;

  bool get hit => outcome.verdict == SwingVerdict.contact;

  /// 0..1, 1 being dead on. Zero on a miss.
  double get quality => outcome.quality;

  double get exitSpeed => outcome.exitSpeed;

  int get earlyLateMs => (timingError * 1000).round();

  String get summary {
    final ms = earlyLateMs.abs();
    final when = earlyLateMs == 0
        ? 'ON TIME'
        : (timingError < 0 ? 'EARLY ${ms}ms' : 'LATE ${ms}ms');
    final result = hit ? 'HIT' : 'MISS';
    return '$when · $result · quality ${(quality * 100).round()}%';
  }
}

/// Running contact rate. Swings that were never offered are not counted.
String hitRateLabel(int hits, int swings) {
  if (swings <= 0) return 'hit rate 0/0';
  final pct = (100 * hits / swings).round();
  return 'hit rate $hits/$swings · $pct%';
}
