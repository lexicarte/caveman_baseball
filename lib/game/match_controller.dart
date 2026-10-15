// Runs a game: the pitch loop, the swing, and the fielding play.
//
// Free of Flame so a whole match can be driven by tests and balance tools.
// The Flame layer reads this and draws it; it decides nothing.
//
// The pitch sequence, which is the heart of the game:
//   1. the batter commits one of his three slots, blind
//   2. the thrower commits a rock and picks a scheme, blind
//   3. the pitch flies — during the flight BOTH the rock and the scheme are
//      visible, which is when the swing-or-take decision happens
//   4. taking is simply not tapping
import 'dart:math';

import '../data/clubs.dart';
import '../data/rocks.dart';
import '../model/club.dart';
import '../model/item.dart';
import '../model/loadout.dart';
import '../model/player.dart';
import '../model/rock.dart';
import '../sim/ball_flight.dart';
import '../sim/base_running.dart';
import '../sim/field_spec.dart';
import '../sim/fielder_spec.dart';
import '../sim/game_rules.dart';
import '../sim/swing_resolver.dart';

enum PitchPhase {
  /// Batting: pick a slot. Fielding: pick a rock and a scheme.
  commit,

  /// The thrower is winding up. The timer has not started.
  windUp,

  /// Ball on its way. Rock and scheme are visible; tap to swing.
  inFlight,

  /// Ball is live. When fielding, tap a chaser then tap a base.
  ballInPlay,

  outcome,
  gameOver,
}

class MatchController {
  MatchController({
    required this.playerTeam,
    required this.opponent,
    Random? rng,
  }) : _rng = rng ?? Random() {
    _startAtBat();
  }

  final Team playerTeam;
  final Team opponent;
  final Random _rng;

  static const field = FieldSpec.compact;
  static const swingResolver = SwingResolver();
  static const flightSim = BallFlightSim();
  static const baseRunning = BaseRunning();

  /// How accurately the opposing batter times a pitch, in seconds of spread.
  static const opponentTimingSigma = 0.042;

  final progress = GameProgress();

  // --- half-inning -------------------------------------------------------
  int outs = 0;
  int runsThisHalf = 0;
  final List<Runner> runners = [];

  // --- at-bat ------------------------------------------------------------
  int playerBatterIndex = 0;
  int opponentBatterIndex = 0;
  int strikes = 0;
  final Set<int> usedSlots = {};

  /// Slots gummed up by TAR, gone for the rest of this at-bat.
  final Set<int> stuckSlots = {};

  // --- this pitch --------------------------------------------------------
  PitchPhase phase = PitchPhase.commit;
  Club club = Clubs.stik;
  Item? item;
  Rock rock = Rocks.plain;
  Scheme scheme = Schemes.wheel;
  int? committedSlot;

  double windUpRemaining = 0;
  double pitchElapsed = 0;
  double pitchFlightTime = GameRules.pitchFlightSeconds;

  SwingOutcome? swing;
  BallFlight? flight;
  double playback = 0;
  Interception? interception;
  ThrowResult? throwResult;
  Map<int, FielderSpec> coverage = const {};
  String message = '';

  // --- derived -----------------------------------------------------------

  bool get playerBatting => progress.playerBatting;
  Team get battingTeam => playerBatting ? playerTeam : opponent;
  Team get fieldingTeam => playerBatting ? opponent : playerTeam;

  int get batterIndex =>
      playerBatting ? playerBatterIndex : opponentBatterIndex;

  Player get batter => battingTeam.players[batterIndex];

  /// True once the ball has actually left the hand.
  bool get released => windUpRemaining <= 0;

  /// Slots the batter can still reach for.
  List<int> get availableSlots => [
    for (var i = 0; i < slotsPerBatter; i++)
      if (!usedSlots.contains(i) && !stuckSlots.contains(i)) i,
  ];

  /// Where the pitched ball is, in metres from the plate up the middle.
  /// How far out the rock leaves from: the thrower's own post.
  double get throwerDepth => scheme.thrower.depth;

  /// Contact happens slightly IN FRONT of the plate, toward the thrower —
  /// which is where a hitter actually meets the ball. It also makes the
  /// swing asymmetric in the way that reads best: a fractionally early
  /// swing still connects, a fractionally late one does not.
  static const double contactDepth = 0.5;

  /// The instant a perfectly timed swing lands. Everything that scores or
  /// models a swing measures from HERE, not from the rock reaching the
  /// plate — they are 5% of the flight apart.
  double get contactTime => pitchFlightTime * (1 - contactDepth / throwerDepth);

  double get pitchBallDepth {
    final mound = throwerDepth;
    if (!released) return mound;
    return mound * (1.0 - (pitchElapsed / pitchFlightTime).clamp(0.0, 1.0));
  }

  /// Holds a finished play open until it has been played out on screen.
  ///
  /// The simulation resolves a hit in one frame. Settling on that same frame
  /// made every play instantaneous — the ball never moved, nobody ran, and
  /// the outcome banner appeared before you had seen what happened.
  double _settleAt = 0;
  void Function()? _pending;

  /// A beat after the ball arrives, so the last moment of the play lands
  /// before the banner replaces it.
  static const double settleHold = 0.5;

  void _defer(double at, void Function() action) {
    _settleAt = (at > playback ? at : playback) + settleHold;
    _pending = action;
  }

  /// The men not chasing, available to cover bases.
  List<FielderSpec> get coverMen {
    final chaser = interception?.fielder;
    return [
      for (final f in scheme.fielders)
        if (chaser == null || f.id != chaser.id) f,
    ];
  }

  // --- flow --------------------------------------------------------------

  void _startAtBat() {
    strikes = 0;
    usedSlots.clear();
    stuckSlots.clear();
    _startPitch();
  }

  void _startPitch() {
    committedSlot = null;
    item = null;
    swing = null;
    flight = null;
    interception = null;
    throwResult = null;
    coverage = const {};
    playback = 0;
    pitchElapsed = 0;
    phase = PitchPhase.commit;
    message = playerBatting ? 'Pick a club' : 'Pick a rock';
  }

  /// Batting: commit one of the three slots. An empty slot swings STIK.
  void commitSlot(int slot) {
    if (phase != PitchPhase.commit || !playerBatting) return;
    if (!availableSlots.contains(slot)) return;

    committedSlot = slot;
    usedSlots.add(slot);
    final card = battingTeam.batting[batterIndex][slot];
    club = switch (card) {
      ClubCard(:final club) => club,
      // An item still swings — just with the club everyone owns.
      ItemCard() => Clubs.stik,
      null => Clubs.stik,
    };
    item = card is ItemCard ? card.item : null;

    _opponentThrows();
    _launchPitch();
  }

  /// Fielding: commit a rock, having already set a scheme.
  void commitRock(int slot) {
    if (phase != PitchPhase.commit || playerBatting) return;
    if (!availableSlots.contains(slot)) return;

    committedSlot = slot;
    usedSlots.add(slot);
    rock = playerTeam.throwing[opponentBatterIndex][slot] ?? Rocks.plain;

    _opponentBats();
    _launchPitch();
  }

  /// Fielding: the scheme is a dial, changeable at every pitch and free.
  void chooseScheme(Scheme s) {
    if (playerBatting) return;
    scheme = s;
  }

  void _opponentThrows() {
    final slots = opponent.throwing[playerBatterIndex];
    final loaded = [for (final r in slots) ?r];
    rock = loaded.isEmpty ? Rocks.plain : loaded[_rng.nextInt(loaded.length)];
    scheme = Schemes.all[_rng.nextInt(Schemes.all.length)];
  }

  void _opponentBats() {
    final slots = opponent.batting[opponentBatterIndex];
    final loaded = [
      for (final c in slots)
        if (c is ClubCard) c.club,
    ];
    club = loaded.isEmpty ? Clubs.stik : loaded[_rng.nextInt(loaded.length)];
    item = null;
  }

  void _launchPitch() {
    // Nok Noggin slows the pitch, so there is longer to read it.
    final slow = item?.effect == ItemEffect.slowPitch;
    pitchFlightTime = GameRules.pitchFlightSeconds * (slow ? 1.45 : 1.0);
    windUpRemaining = GameRules.windUpSeconds;
    pitchElapsed = 0;
    phase = PitchPhase.windUp;
    message = '';
  }

  void tick(double dt) {
    switch (phase) {
      case PitchPhase.windUp:
        windUpRemaining -= dt;
        if (windUpRemaining <= 0) {
          phase = PitchPhase.inFlight;
          message = playerBatting ? 'Swing!' : '';
        }

      case PitchPhase.inFlight:
        pitchElapsed += dt;
        if (!playerBatting) {
          // The opposing batter commits at his own accuracy.
          if (pitchElapsed >= contactTime) {
            _resolveSwing(_gaussian() * opponentTimingSigma);
          }
          return;
        }
        // Past the window with no tap is a take.
        if (pitchElapsed > contactTime + GameRules.timingWindow) {
          _takePitch();
        }

      case PitchPhase.ballInPlay:
        playback += dt;
        final due = _pending;
        if (due != null && playback >= _settleAt) {
          _pending = null;
          due();
        }

      case PitchPhase.commit:
      case PitchPhase.outcome:
      case PitchPhase.gameOver:
        break;
    }
  }

  /// The tap. Only meaningful while the ball is on its way.
  void swingNow() {
    if (phase != PitchPhase.inFlight || !playerBatting) return;
    _resolveSwing(pitchElapsed - contactTime);
  }

  void _takePitch() {
    // A risk rock is too awkward to throw true: let it go and it costs a club
    // but does not advance the count. That is the gamble.
    if (rock.noStrikeOnTake) {
      message = 'Let it go — no strike';
      phase = PitchPhase.outcome;
      return;
    }
    _recordStrike('Took it');
  }

  void _resolveSwing(double timingError) {
    final windowScale = item?.effect == ItemEffect.slowPitch ? 1.35 : 1.0;
    final outcome = swingResolver.resolve(
      timingError: timingError,
      club: club,
      rock: rock,
      powerScale: batter.powerScale,
      windowScale: windowScale,
      rng: _rng,
    );
    swing = outcome;

    // Swinging at a risk rock is what it punishes.
    if (rock.risk == RiskEffect.stick && committedSlot != null) {
      stuckSlots.add(committedSlot!);
    }

    if (outcome.verdict != SwingVerdict.contact) {
      _recordStrike(outcome.label);
      return;
    }
    _putInPlay(outcome);
  }

  void _putInPlay(SwingOutcome outcome) {
    flight = flightSim.fly(
      exitSpeed: outcome.exitSpeed,
      sprayDegrees: outcome.sprayDegrees,
      nominalCarry: outcome.carry,
      rock: rock,
      field: field,
      rng: _rng,
    );

    if (flight!.foul) {
      _recordFoul();
      return;
    }

    // Everyone is going on contact. Without this, a runner who settled on a
    // base has to == from, so he is standing still — his arrival time is zero
    // and no throw can ever retire him, which means almost nothing is an out.
    for (final r in runners) {
      r.to = r.from + 1;
    }
    runners.add(Runner(player: batter, from: homePlate, to: firstBase));

    playback = 0;
    _pending = null;
    _settleAt = 0;
    phase = PitchPhase.ballInPlay;
    message = '';

    if (playerBatting) {
      // The opposition fields for itself.
      _autoField();
    }
  }

  // --- fielding ----------------------------------------------------------

  /// Tap a man to chase the ball. Whoever chases is no longer covering a
  /// base, which is the second half of this decision.
  void tapFielder(String fielderId) {
    if (phase != PitchPhase.ballInPlay || playerBatting) return;
    if (interception != null) return;
    final f = scheme.fielders.firstWhere(
      (m) => m.id == fielderId && m.chases,
      orElse: () => scheme.fielders.firstWhere((m) => m.chases),
    );
    _assignChaser(f);
  }

  void _assignChaser(FielderSpec f) {
    final staffed = _staffFor(f);
    interception = flightSim.chaseBy(staffed, flight!);
    coverage = baseRunning.assignCoverage(
      coverMen,
      field,
      needed: _bagsNeedingCover(),
    );
    message = interception!.caught ? 'Caught!' : 'Throw it';
    if (interception!.caught) {
      _defer(interception!.time, () => _recordOut('Caught'));
    }
  }

  /// Where runners are actually heading, nearest-to-scoring first. With the
  /// bases loaded this is four bags against three men.
  List<int> _bagsNeedingCover() {
    final bags = <int>{
      for (final r in runners)
        if (!r.out) r.to,
    }.toList()..sort((a, b) => b.compareTo(a));
    return bags.isEmpty ? const [firstBase] : bags;
  }

  /// The scheme with real men on it. Tap regions are built from these and
  /// not from the bare posts, because speed decides who owns which ground.
  List<FielderSpec> get staffedFielders => [
    for (final f in scheme.fielders) _staffFor(f),
  ];

  /// Applies the real player's speed and arm to a post.
  FielderSpec _staffFor(FielderSpec post) {
    final men = fieldingTeam.fielders;
    final idx = scheme.fielders.indexWhere((m) => m.id == post.id);
    if (idx < 0 || idx >= men.length) return post;
    return post.withPlayer(men[idx]);
  }

  /// Tap the base to throw to.
  void tapBase(int base) {
    if (phase != PitchPhase.ballInPlay || playerBatting) return;
    final grab = interception;
    if (grab == null || throwResult != null || grab.caught) return;
    _throwTo(base, grab);
  }

  void _throwTo(int base, Interception grab) {
    final target = runners.where((r) => !r.out && r.to == base).firstOrNull;
    final result = baseRunning.resolveThrow(
      targetBase: base,
      fieldedAt: grab.point,
      fieldedTime: grab.time,
      thrower: grab.fielder,
      coverMan: coverage[base],
      runner: target,
      field: field,
    );
    throwResult = result;
    _defer(result.throwArrives, () {
      if (result.isOut && target != null) target.out = true;

      // Everyone not retired on this play still ran, whether or not somebody
      // was thrown out. Skipping this left the batter standing at home for
      // the rest of the inning, invisible and unable to score.
      baseRunning.advanceAll(runners, result.throwArrives);
      _settlePlay(result.label, anOut: result.isOut && target != null);
    });
  }

  /// The opposition makes a competent but not perfect choice: chase with
  /// whoever gets there soonest, then throw at the lead runner.
  void _autoField() {
    var best = scheme.fielders.firstWhere((f) => f.chases);
    var bestTime = double.infinity;
    for (final post in scheme.fielders) {
      if (!post.chases) continue;
      final grab = flightSim.chaseBy(_staffFor(post), flight!);
      if (grab.time < bestTime) {
        bestTime = grab.time;
        best = post;
      }
    }
    _assignChaser(best);
    if (interception!.caught) return;

    // Throw at the most advanced runner whose bag someone is actually
    // guarding — a throw to an unguarded bag sails into the dirt.
    Runner? target;
    for (final r in runners) {
      if (r.out || coverage[r.to] == null) continue;
      if (target == null || r.to > target.to) target = r;
    }
    _throwTo(target?.to ?? firstBase, interception!);
  }

  // --- outcomes ----------------------------------------------------------

  void _recordStrike(String why) {
    strikes++;
    if (strikes >= GameRules.strikesPerOut) {
      _recordOut('Struck out');
      return;
    }
    message = '$why — strike $strikes';
    phase = PitchPhase.outcome;
  }

  void _recordFoul() {
    // A foul cannot be the third strike, same as real baseball.
    if (strikes < GameRules.strikesPerOut - 1) strikes++;
    message = 'Foul — strike $strikes';
    phase = PitchPhase.outcome;
  }

  void _recordOut(String why) {
    outs++;
    message = why;
    _endAtBat();
  }

  void _settlePlay(String why, {bool anOut = false}) {
    if (anOut) outs++;
    for (final r in runners.where((r) => r.scored)) {
      runsThisHalf++;
      r.out = true; // off the basepaths
    }
    runners.removeWhere((r) => r.out);
    // Survivors now stand where they got to; the next play advances them from
    // there rather than from the plate.
    for (final r in runners) {
      r.from = r.to;
    }
    message = why;
    _endAtBat();
  }

  void _endAtBat() {
    phase = PitchPhase.outcome;
    if (outs >= GameRules.outsPerHalf) message = '$message · side away';
  }

  /// Tap through the result.
  void advance() {
    if (phase != PitchPhase.outcome) return;

    if (outs >= GameRules.outsPerHalf) {
      progress.completeHalf(runsThisHalf);
      outs = 0;
      runsThisHalf = 0;
      runners.clear();
      if (progress.isComplete) {
        phase = PitchPhase.gameOver;
        final p = progress.playerRuns, o = progress.opponentRuns;
        message = p > o
            ? 'You win $p–$o'
            : (p < o ? 'You lose $p–$o' : 'Tied $p–$o');
        return;
      }
      _nextBatter(advanceOrder: false);
      _startAtBat();
      return;
    }

    final atBatOver =
        strikes >= GameRules.strikesPerOut ||
        swing?.verdict == SwingVerdict.contact;
    if (atBatOver) {
      _nextBatter(advanceOrder: true);
      _startAtBat();
    } else {
      _startPitch();
    }
  }

  void _nextBatter({required bool advanceOrder}) {
    if (!advanceOrder) return;
    if (playerBatting) {
      playerBatterIndex = (playerBatterIndex + 1) % playersPerTeam;
    } else {
      opponentBatterIndex = (opponentBatterIndex + 1) % playersPerTeam;
    }
  }

  double _gaussian() {
    final u1 = 1.0 - _rng.nextDouble();
    final u2 = _rng.nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  }
}
