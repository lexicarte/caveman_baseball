// Renders a MatchController and feeds it time and taps.
//
// The game object decides nothing about baseball. It ticks the controller,
// plays back the ball flight the simulation already produced, and draws the
// result. Every rule lives in lib/sim and match_controller.dart.
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../sim/ball_flight.dart';
import '../sim/base_running.dart';
import '../sim/tap_regions.dart';
import 'components/ball_component.dart';
import 'components/caveman.dart';
import 'components/field_component.dart';
import 'field_motion.dart';
import 'ground.dart';
import 'look.dart';
import 'components/figures_component.dart';
import 'match_controller.dart';
import 'sprites/sprite_library.dart';
import 'swing_timing.dart';

class CavemanBaseballGame extends FlameGame {
  CavemanBaseballGame({required this.match})
    : super(
        // PORTRAIT-shaped, and 67 wide is what sets the scale: at 390pt that
        // is 5.8 points per pace, near the 6.9 ceiling a 96-degree wedge
        // allows on a phone. The height is not extra field — the field is
        // the same size either way — it is the sky and foreground that used
        // to be a black letterbox, because a 67x38 viewport is landscape and
        // the screen is not.
        camera: CameraComponent.withFixedResolution(
          width: viewportWidth,
          height: viewportHeight,
        ),
      );

  final MatchController match;

  /// Home plate's y now lives in Ground, which owns the whole transform.

  /// Ball playback runs a little fast so a roll reads as quick rather than
  /// languid.
  static const double playbackRate = 1.3;

  /// The camera pushes in as the pitch arrives.
  ///
  /// Wide when the scheme is revealed, so the defence can be read; tight by
  /// the time the ball reaches the plate, so the swing is not happening in
  /// half an inch of screen. Zooming in for the whole pitch would hide the
  /// deep men, which are exactly what you need to see.
  // The camera lives on Ground so the figure scale can read it without
  // importing the game. These are aliases.
  static const double viewportWidth = Ground.viewportWidth;
  static const double viewportHeight = Ground.viewportHeight;
  static const double zoomOutRate = Ground.zoomOutRate;
  static const double zoomInRate = Ground.zoomInRate;

  static double get wideZoom => Ground.wideZoom;

  /// Close enough on the plate and the mound to read the pitch. Held for the
  /// WHOLE at-bat rather than pushed in during the flight — a camera that
  /// moves while you are timing a swing is unplayable.
  static double get tightZoom => Ground.tightZoom;

  /// What the camera looks at, wide and tight. Tight sits down near the
  /// plate where the ball actually is.
  static double get wideLook => Ground.wideLook;
  static double get tightLook => Ground.tightLook;

  double _zoom = Ground.wideZoom;
  double _look = Ground.wideLook;

  /// How long the bat takes to come through, as shipped. Short enough to
  /// feel like a swing, long enough to actually see. From the painter, so
  /// the animation and the thing driving it cannot disagree about how long
  /// a swing takes. A saved preset scales this through [liveSwingSeconds].
  static const double swingSeconds = CavemanPainter.swingSeconds;

  /// Seconds the bat is in motion right now. Equals [swingSeconds] until a
  /// preset says otherwise.
  double get liveSwingSeconds => SwingTiming.now.swingPlaySeconds;

  /// The drawn height of a man at the at-bat view, which is the scale every
  /// swing measurement below is taken at — the camera is held still for the
  /// whole at-bat, so this does not move while it matters.
  static double get drawnHeight => Ground.figureHeightTight * 1.04;

  /// The batter stands this far to the side of the plate and this far out,
  /// MEASURED IN HIS OWN HEIGHTS. Absolute paces would be wrong: shrink the
  /// figure and he keeps standing a long way off with a club that no longer
  /// reaches the plate.
  static const double batterSideInHeights = -0.545;
  static const double batterDepthInHeights = 0.031;

  /// Where the batter stands, in field paces.
  ///
  /// His DEPTH has to match the plate, and that is not cosmetic. The swing
  /// is timed by eye off the rock, and `timingError` is zero at the moment
  /// the rock reaches depth 0 — so if he is drawn further out than the
  /// plate, "level with the batter" and "on time" are two different
  /// moments. At the 1.2 paces he used to be drawn at they were **174ms**
  /// apart, which is outside every club's window except TWIG's: swinging
  /// when the rock was in front of him was a strike, every time.
  ///
  /// Negative x is the third-base side, which from behind home is screen
  /// LEFT — where a right-hander stands.

  /// The thrower stands a little to the side of the rubber, so the rock —
  /// which now flies straight down the middle — is not drawn on top of
  /// him. Render only: the simulation has him at dead centre, and moving
  /// him there would change what he can reach.
  ///
  /// IN HIS OWN HEIGHTS, for the same reason the batter is. A flat 1.4
  /// paces was set when the men were drawn big; once they shrink with the
  /// zoom it is three body widths and he reads as standing BESIDE the
  /// mound rather than on it. Just over half a height clears the rock and
  /// keeps him on the dirt circle.
  static double get throwerOffsetInHeights => Look.now.throwerOffsetInHeights;
  static double get throwerRenderOffsetX =>
      throwerOffsetInHeights * drawnHeight;

  static double get batterX => batterSideInHeights * drawnHeight;
  static double get batterY => batterDepthInHeights * drawnHeight;

  /// How far below the top of his head a man's hands are, as a fraction of
  /// his drawn height. Both painters put them there, and it is where the
  /// bat sweeps — so it is also the height the rock has to arrive at.
  static const double handDrop = 0.45;

  /// Screen height the bat sweeps at. Stated through `Ground.y` rather
  /// than by repeating the shear, so it stays right when the projection
  /// changes underneath it.
  static double get batHeight => Ground.y(batterY) - handDrop * drawnHeight;

  /// How far above the ground the rock is drawn at [depth].
  ///
  /// It leaves the thrower's hand at hand height and is pitched so that it
  /// meets the bat EXACTLY at [MatchController.contactDepth] — the same
  /// instant a perfectly timed swing scores. With no timing meter the
  /// player swings at what they see, so those two have to be one event. A
  /// rock that crosses the bat's height at any other moment is a timing
  /// error the player can neither see nor correct for; an earlier version
  /// of this sank to the batter's ankles and was 214ms out.
  static double rockLift(double depth, double throwerDepth) {
    // Anchored at both ends rather than derived from the shear: it leaves
    // the thrower's hand — which is as high as HIS drawn height, and he
    // is drawn smaller because he is further away — and arrives at the
    // bat's height exactly at the contact depth.
    final atHand = handDrop * drawnHeight * Ground.depthScale(throwerDepth);
    // Shipped as MatchController.contactDepth. A preset can move it, and
    // the rock has to follow or the bat and the score are two events again.
    final dc = SwingTiming.now.contactDepth;
    if (throwerDepth <= dc) return atHand;
    final atBat = Ground.y(dc) - batHeight;
    final f = ((depth - dc) / (throwerDepth - dc)).clamp(0.0, 1.0);
    return atBat + (atHand - atBat) * f;
  }

  double _swingElapsed = -1;
  bool _swungThisPitch = false;

  /// Bumped every frame so the Flutter HUD rebuilds from the controller.
  final revision = ValueNotifier<int>(0);

  late final BallComponent _ball;
  late final FiguresComponent _figures;
  late final FieldComponent _fieldComponent;
  PitchPhase? _lastPhase;

  @override
  Future<void> onLoad() async {
    final sprites = SpriteLibrary();
    // Missing sheets are the normal case until art is exported. The library
    // leaves those poses empty and the figures stay code-drawn.
    await sprites.loadAvailable();
    _ball = BallComponent();
    _figures = FiguresComponent(sprites: sprites);
    _fieldComponent = FieldComponent(spec: MatchController.field);
    world.addAll([_fieldComponent, _figures, _ball]);
  }

  /// Converts a screen tap into field coordinates (+y toward the outfield).
  ///
  /// Returns plain numbers on purpose: Flame and the simulation use two
  /// different Vector2 classes from the same package, so nothing vector-shaped
  /// crosses this boundary.
  ({double x, double y}) fieldPointAt(double sx, double sy) {
    final world = camera.globalToLocal(Vector2(sx, sy));
    // Depth first: how many paces across a tap is worth depends on how
    // far down the field it landed.
    final depth = Ground.fieldY(world.y);
    if (!depth.isFinite) return (x: 0.0, y: double.infinity);
    return (x: Ground.fieldX(world.x, depth), y: depth);
  }

  /// Every tap in the game comes through here.
  ///
  /// What it means depends entirely on where we are: during the flight it is
  /// the swing, on the field it is "chase that" then "throw there", and on a
  /// result screen it moves on.
  void handleTapAt(double sx, double sy) {
    switch (match.phase) {
      case PitchPhase.inFlight:
        match.swingNow();
      case PitchPhase.outcome:
        match.advance();
      case PitchPhase.ballInPlay:
        if (!match.playerBatting) _handleFieldTap(sx, sy);
      case PitchPhase.commit:
      case PitchPhase.windUp:
      case PitchPhase.gameOver:
        break;
    }
    revision.value++;
  }

  void _handleFieldTap(double sx, double sy) {
    final p = fieldPointAt(sx, sy);

    double gapTo(double x, double y) {
      final dx = x - p.x, dy = y - p.y;
      return math.sqrt(dx * dx + dy * dy);
    }

    if (match.interception == null) {
      // Tap the GROUND, not the man. A fielder is a small sprite and CLOSE
      // puts two of them inside one thumb, so hit-testing the sprites is a
      // coin flip. The whole field is partitioned instead: whoever could
      // stand on the tapped point soonest goes and gets it, which means
      // there is no cutoff radius and no tap that misses.
      final man = TapRegions.resolve(p.x, p.y, match.staffedFielders);
      match.tapFielder(man.id);
      return;
    }

    if (match.throwResult != null) return;
    // Same rule for the throw: nearest bag, no cutoff. A tap that lands
    // between two bags and does nothing is the worst outcome under time
    // pressure — far worse than throwing to the wrong one, which at least
    // teaches you where the bags are.
    var bestBase = firstBase;
    var bestGap = double.infinity;
    for (final base in [firstBase, secondBase, thirdBase, homeBase]) {
      final bag = basePosition(base, MatchController.field);
      final gap = gapTo(bag.x, bag.y);
      if (gap < bestGap) {
        bestGap = gap;
        bestBase = base;
      }
    }
    match.tapBase(bestBase);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (match.phase != _lastPhase) {
      _ball.clearTrail();
      _lastPhase = match.phase;
    }

    switch (match.phase) {
      case PitchPhase.commit:
        _pitchBall(match.throwerDepth);
      case PitchPhase.windUp:
      case PitchPhase.inFlight:
        match.tick(dt);
        _pitchBall(match.pitchBallDepth);
      case PitchPhase.ballInPlay:
        match.tick(dt * playbackRate);
        _syncBattedBall();
      case PitchPhase.outcome:
      case PitchPhase.gameOver:
        break;
    }

    _driveCamera(dt);
    _driveSwing(dt);
    // Everything that draws a MODEL needs the camera, because models shrink
    // as it pushes in — that is what puts five body heights between the
    // batter and the mound instead of one and a half.
    _fieldComponent.zoom = _zoom;
    _ball.modelScale = Ground.modelScaleFor(_zoom);
    _figures
      ..zoom = _zoom
      ..figures = _buildFigures()
      ..coveredBases = match.coverage.keys.toSet();
    revision.value++;
  }

  /// Starts the bat moving the instant a swing is resolved, and lets it play
  /// out across the phase change into the ball being live.
  void _driveSwing(double dt) {
    if (match.phase == PitchPhase.commit) {
      _swungThisPitch = false;
      _swingElapsed = -1;
    }
    if (!_swungThisPitch && match.swing != null) {
      _swungThisPitch = true;
      _swingElapsed = 0;
    }
    final length = liveSwingSeconds;
    if (_swingElapsed >= 0 && length > 0 && _swingElapsed < length) {
      _swingElapsed += dt;
    }
  }

  double? get _swingPhase {
    if (_swingElapsed < 0) return null;
    final length = liveSwingSeconds;
    if (length <= 0) return null;
    final t = _swingElapsed / length;
    return t >= 1 ? null : t;
  }

  void _driveCamera(double dt) {
    // Push in over the course of the flight, pull straight back out the
    // moment the ball is struck so the whole field is readable again.
    // Tight for the at-bat, wide the instant the ball is struck. Only when
    // the player is BATTING: fielding, he is choosing a scheme and needs to
    // see the whole field.
    final atBat =
        match.playerBatting &&
        (match.phase == PitchPhase.commit ||
            match.phase == PitchPhase.windUp ||
            match.phase == PitchPhase.inFlight);
    final targetZoom = atBat ? tightZoom : wideZoom;
    final targetLook = atBat ? tightLook : wideLook;

    // Both directions are eased over roughly a third of a second. Snapping
    // out of a 3.6x close-up reads as a cut to a different scene; you lose
    // track of the ball at the one moment you most need to follow it.
    final rate = targetZoom < _zoom
        ? (zoomOutRate * dt).clamp(0.0, 1.0)
        : (zoomInRate * dt).clamp(0.0, 1.0);
    _zoom += (targetZoom - _zoom) * rate;
    _look += (targetLook - _look) * rate;
    camera.viewfinder
      ..zoom = _zoom
      ..position = Vector2(0, _look);
  }

  /// Everyone currently standing on the field: the defence at their posts,
  /// the batter at the plate, and anyone on base.
  List<Figure> _buildFigures() {
    final out = <Figure>[];
    final defenders = match.fieldingTeam.fielders;
    final chaserId = match.interception?.fielder.id;

    final grab = match.interception;
    final t = match.playback;

    for (var i = 0; i < match.scheme.fielders.length; i++) {
      final post = match.scheme.fielders[i];
      final man = i < defenders.length ? defenders[i] : defenders.last;

      // On offence the catcher is simply in the way: the camera sits behind
      // the plate and he covers the batter. He never chases, so hiding him
      // costs nothing.
      if (match.playerBatting && !post.chases) continue;

      var x = post.position.x + (post.id == 'p' ? throwerRenderOffsetX : 0);
      var y = post.position.y;
      var pose = const Pose.still();

      // Where is he going, and when does he get there? The chaser runs at
      // the ball; everyone else runs to the bag they have been given.
      double? toX;
      double? toY;
      double? arrive;
      if (grab != null && grab.fielder.id == post.id) {
        toX = grab.point.x;
        toY = grab.point.y;
        arrive = grab.time;
      } else {
        for (final entry in match.coverage.entries) {
          if (entry.value.id != post.id) continue;
          final bag = basePosition(entry.key, MatchController.field);
          toX = bag.x;
          toY = bag.y;
          arrive = post.timeToReach(bag);
          break;
        }
      }

      if (toX != null && toY != null && arrive != null) {
        final at = placeFielder(
          fromX: post.position.x,
          fromY: post.position.y,
          toX: toX,
          toY: toY,
          reactionTime: post.reactionTime,
          arriveAt: arrive,
          playback: t,
          // From the height he is DRAWN at, not the unzoomed one, or he
          // skates whenever the camera is not wide.
          stride: CavemanPainter.strideFor(
            man.archetype,
            Ground.figureHeightAt(_zoom, y),
          ),
        );
        x = at.x;
        y = at.y;
        pose = at.pose;
      }

      out.add(
        Figure(
          fieldX: x,
          fieldY: y,
          archetype: man.archetype,
          chasing: post.id == chaserId,
          reach: post.range,
          pose: pose,
        ),
      );
    }

    out.add(
      Figure(
        fieldX: batterX,
        fieldY: batterY,
        archetype: match.batter.archetype,
        holdingClub: true,
        pose: _swingPhase == null
            ? const Pose.still()
            : Pose.swing(_swingPhase!),
      ),
    );

    for (final r in match.runners) {
      if (r.out || r.from == homePlate) continue;
      final bag = basePosition(r.from, MatchController.field);
      out.add(
        Figure(
          fieldX: bag.x - 1.4,
          fieldY: bag.y,
          archetype: r.player.archetype,
        ),
      );
    }

    return out;
  }

  /// The rock on its way in.
  ///
  /// It flies at HAND HEIGHT the whole way — out of the thrower's hand and
  /// into the strike zone, which is exactly where the bat sweeps. That is
  /// not decoration: with the timing meter gone the player swings at what
  /// they SEE, so the rock meeting the bat and the swing scoring as on-time
  /// have to be the same instant.
  ///
  /// It used to sink from 2.8 to 0.8 on the way in, crossing the bat's
  /// height **214ms before** the on-time moment and arriving at the
  /// batter's ankles. Swinging at what you saw was early on every pitch,
  /// past the window of every club in the game.
  ///
  /// It comes STRAIGHT down the middle, from the thrower to the plate. It
  /// used to be held out to his side and converge, which drew a curve
  /// across the screen: the rock looked like it was swerving when it is
  /// not, and you cannot time a pitch whose line you cannot read. The side
  /// offset existed only to keep it off the thrower's body, which stopped
  /// mattering once figures shrank at the at-bat view.
  void _pitchBall(double depth) {
    _ball.syncTo(
      0,
      depth,
      match.rock,
      lift: rockLift(depth, match.throwerDepth),
    );
  }

  /// Interpolates along the path the simulation already computed, so what is
  /// on screen is the play that actually happened.
  void _syncBattedBall() {
    final flight = match.flight;
    if (flight == null || flight.path.isEmpty) return;
    final t = match.playback;

    var sample = flight.path.last;
    for (var i = 1; i < flight.path.length; i++) {
      if (flight.path[i].time >= t) {
        final prev = flight.path[i - 1];
        final span = flight.path[i].time - prev.time;
        final f = span <= 0 ? 0.0 : (t - prev.time) / span;
        final pos =
            prev.position + (flight.path[i].position - prev.position) * f;
        sample = BallSample(t, pos);
        break;
      }
    }

    // A ball still in the air lifts off its shadow and comes back down.
    final travelled = sample.position.length;
    final lift = flight.airborne && travelled < flight.carry
        ? Ground.arcHeight(travelled, flight.carry, sample.position.y)
        : 0.0;

    // Once a man has it, the rock stops following the roll and flies to the
    // bag instead. Without this leg it sits in the outfield while the play
    // is decided somewhere else, which is the single most confusing thing
    // that can happen on screen.
    final grab = match.interception;
    final thrown = match.throwResult;
    if (grab != null && t >= grab.time) {
      if (thrown == null || grab.caught) {
        _ball.syncTo(grab.point.x, grab.point.y, match.rock);
        return;
      }
      final bag = basePosition(thrown.targetBase, MatchController.field);
      final span = thrown.throwArrives - grab.time;
      final f = span <= 0 ? 1.0 : ((t - grab.time) / span).clamp(0.0, 1.0);
      final bx = grab.point.x + (bag.x - grab.point.x) * f;
      final by = grab.point.y + (bag.y - grab.point.y) * f;
      // A throw is a flat arc, so it reads as through the air rather than
      // as another ground ball.
      _ball.syncTo(bx, by, match.rock, lift: math.sin(f * math.pi) * 3.2);
      return;
    }

    _ball.syncTo(sample.position.x, sample.position.y, match.rock, lift: lift);
  }
}
