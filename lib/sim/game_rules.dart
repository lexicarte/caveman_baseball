// Game constants and the scoreboard.
//
// Baserunners used to live here as a Bases bitfield with a single
// advance(n) method. They are now real runners in base_running.dart, each
// resolved by an actual throw, so all that is left here is the frame.
class GameRules {
  static const inningsPerGame = 3;
  static const outsPerHalf = 3;
  static const strikesPerOut = 3;

  /// Seconds from the thrower starting his motion to the ball leaving his
  /// hand. The swing timer does not start until release, so the batter has a
  /// visible cue to read rather than guessing from a bar.
  static const windUpSeconds = 0.55;

  /// Seconds from release to the plate, before any rock or item changes it.
  // 1.45 / 1.2: the rock crosses the same ten paces 20% quicker. The
  // timing windows are absolute milliseconds, so this costs the player
  // ground to read the pitch in without changing a single outcome in the
  // simulation.
  static const pitchFlightSeconds = 1.21;

  /// How far either side of perfect a swing can be and still connect.
  ///
  /// ONE window for the whole game. It used to be a per-club property,
  /// which made some clubs simply harder to use rather than different to
  /// use — the clubs now differ in power, spray, carry and how badly an
  /// off-centre hit is punished, all of which are choices, while timing is
  /// a skill you learn once and keep.
  static const timingWindow = 0.150;

  /// What a slow pitch does: NOK NOGGIN multiplies the flight by this, so
  /// the rock is in the air longer and there is more of it to read.
  static const slowPitchScale = 1.45;
}

/// Three innings, player bats first.
class GameProgress {
  int inning = 1;
  bool topHalf = true;
  int playerRuns = 0;
  int opponentRuns = 0;

  bool get playerBatting => topHalf;
  bool get isComplete => inning > GameRules.inningsPerGame;

  void completeHalf(int runs) {
    if (topHalf) {
      playerRuns += runs;
      topHalf = false;
    } else {
      opponentRuns += runs;
      topHalf = true;
      inning++;
    }
  }

  String get scoreLine => '$playerRuns · $opponentRuns';

  String get inningLabel =>
      isComplete ? 'Final' : '${topHalf ? 'Top' : 'Bot'} $inning';
}
