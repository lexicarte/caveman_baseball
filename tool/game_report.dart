// ignore_for_file: avoid_print
//
// Plays whole games through the real MatchController and reports scorelines.
//
// Per-swing tables say what a matchup is worth; this says whether a game is
// worth playing. A 0-0 grind and a 30-28 track meet both come from per-swing
// numbers that looked perfectly reasonable in isolation.
import 'dart:math';

import 'package:caveman_baseball/data/starter_team.dart';
import 'package:caveman_baseball/sim/game_rules.dart';
import 'package:caveman_baseball/game/match_controller.dart';
import 'package:caveman_baseball/sim/base_running.dart';
import 'package:caveman_baseball/model/club.dart';
import 'package:caveman_baseball/sim/fielder_spec.dart';
import 'package:caveman_baseball/sim/tap_regions.dart';
import 'package:vector_math/vector_math_64.dart';

/// The spray angle with the most room in it, within what this club can reach.
///
/// Since power no longer falls off with angle, deliberately swinging early or
/// late costs nothing — so a competent player aims at a hole rather than at
/// dead centre. Measuring accuracy around zero error would be scoring the
/// player on hitting the one spot every scheme guards.
double bestAngleFor(Scheme scheme, Club club) {
  var bestAngle = 0.0;
  var bestRoom = -1.0;
  for (var a = -club.maxSpray; a <= club.maxSpray; a += 2) {
    final rad = a * pi / 180.0;
    // Judge the gap at a representative depth for this club.
    final depth = 22.0;
    final p = Vector2(sin(rad) * depth, cos(rad) * depth);
    var room = 1e9;
    for (final f in scheme.fielders) {
      final d = (p - f.position).length - f.range;
      if (d < room) room = d;
    }
    if (room > bestRoom) {
      bestRoom = room;
      bestAngle = a;
    }
  }
  return bestAngle;
}

/// Drives one game with a given swing accuracy, returning the final score.
({int you, int them, int pitches}) playGame({
  required int seed,
  required double sigma,
}) {
  final rng = Random(seed);
  final m = MatchController(
    playerTeam: StarterTeams.player(),
    opponent: StarterTeams.rookieOpponent(),
    rng: rng,
  );

  var guard = 0, pitches = 0;
  while (m.phase != PitchPhase.gameOver && guard < 40000) {
    guard++;
    switch (m.phase) {
      case PitchPhase.commit:
        pitches++;
        final slots = m.availableSlots;
        final pick = slots.isEmpty ? 0 : slots[rng.nextInt(slots.length)];
        if (m.playerBatting) {
          m.commitSlot(pick);
        } else {
          m.chooseScheme(Schemes.all[rng.nextInt(Schemes.all.length)]);
          m.commitRock(pick);
        }

      case PitchPhase.windUp:
        m.tick(1.0);

      case PitchPhase.inFlight:
        if (m.playerBatting) {
          // Aim at the biggest hole in the scheme he can now see, and execute
          // it to within his accuracy.
          final target = bestAngleFor(m.scheme, m.club);
          final aimError =
              (target / m.club.maxSpray).clamp(-1.0, 1.0) *
              GameRules.timingWindow;
          final u1 = 1.0 - rng.nextDouble();
          final u2 = rng.nextDouble();
          final g = sqrt(-2 * log(u1)) * cos(2 * pi * u2);
          m.pitchElapsed = m.contactTime + aimError + g * sigma;
          m.swingNow();
        } else {
          m.tick(5.0);
        }

      case PitchPhase.ballInPlay:
        if (m.playerBatting) {
          m.tick(5.0);
        } else {
          // Chase with whoever is nearest where it ends up, then throw at the
          // lead runner — a competent default, not an optimal one.
          if (m.interception == null) {
            // Exactly what a tap does in the game: the player puts a thumb
            // on the ball and the nearest man in TIME goes. Modelling a
            // cleverer choice here would price the cards for a player who
            // cannot actually make it.
            final rest = m.flight!.restPoint;
            final best = TapRegions.resolve(rest.x, rest.y, m.staffedFielders);
            m.tapFielder(best.id);
          } else if (m.interception!.caught) {
            // A catch needs no throw. The controller holds the play open
            // for a beat so it can be SEEN before it resolves, so the only
            // thing to do is let the clock run — what the game does every
            // frame. Keep tapping a bag instead and the driver wedges, the
            // guard trips, and every game gets truncated.
            m.tick(5.0);
          } else if (m.throwResult == null &&
              m.phase == PitchPhase.ballInPlay) {
            final lead = m.runners
                .where((r) => !r.out)
                .fold<Runner?>(
                  null,
                  (a, r) => a == null || r.to > a.to ? r : a,
                );
            m.tapBase(lead?.to ?? firstBase);
          } else {
            m.tick(5.0);
          }
        }

      case PitchPhase.outcome:
        m.advance();

      case PitchPhase.gameOver:
        break;
    }
  }
  return (
    you: m.progress.playerRuns,
    them: m.progress.opponentRuns,
    pitches: pitches,
  );
}

void report(String label, double sigma) {
  const games = 200;
  var wins = 0, losses = 0, ties = 0;
  var you = 0, them = 0, shutouts = 0, blowouts = 0, pitches = 0;
  for (var i = 0; i < games; i++) {
    final r = playGame(seed: i, sigma: sigma);
    you += r.you;
    them += r.them;
    pitches += r.pitches;
    if (r.you > r.them) {
      wins++;
    } else if (r.you < r.them) {
      losses++;
    } else {
      ties++;
    }
    if (r.you == 0) shutouts++;
    if ((r.you - r.them).abs() >= 8) blowouts++;
  }
  print(
    '  ${label.padRight(16)} '
    'avg ${(you / games).toStringAsFixed(1)}-${(them / games).toStringAsFixed(1)}  '
    'W${wins.toString().padLeft(3)} L${losses.toString().padLeft(3)} '
    'T${ties.toString().padLeft(3)}  '
    'shutout ${(shutouts / games * 100).toStringAsFixed(0).padLeft(2)}%  '
    'blowout ${(blowouts / games * 100).toStringAsFixed(0).padLeft(2)}%  '
    '${(pitches / games).round()} pitches',
  );
}

void main() {
  print('200 games per row, 3 innings, starter loadouts on both sides.');
  print('');
  for (final s in [0.015, 0.030, 0.045, 0.070]) {
    report('sigma ${(s * 1000).round()}ms', s);
  }
}
