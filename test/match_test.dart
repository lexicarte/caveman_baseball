// Drives complete games headlessly.
//
// The match flow has states that only misbehave in sequence — a foul that
// should not be a third strike, a half that ends mid at-bat, a runner pinned
// at first forever. Playing thousands of games catches those far faster than
// tapping through them, and all three of those were real bugs.
import 'dart:math';

import 'package:caveman_baseball/data/starter_team.dart';
import 'package:caveman_baseball/game/match_controller.dart';
import 'package:caveman_baseball/model/loadout.dart';
import 'package:caveman_baseball/sim/base_running.dart';
import 'package:caveman_baseball/sim/fielder_spec.dart';
import 'package:caveman_baseball/sim/game_rules.dart';
import 'package:flutter_test/flutter_test.dart';

MatchController playGame({required int seed, double sigma = 0.04}) {
  final rng = Random(seed);
  final m = MatchController(
    playerTeam: StarterTeams.player(),
    opponent: StarterTeams.rookieOpponent(),
    rng: rng,
  );

  var guard = 0;
  while (m.phase != PitchPhase.gameOver && guard < 40000) {
    guard++;
    expect(m.outs, lessThanOrEqualTo(GameRules.outsPerHalf));
    switch (m.phase) {
      case PitchPhase.commit:
        final slots = m.availableSlots;
        expect(
          slots,
          isNotEmpty,
          reason: 'a batter always has somewhere to go',
        );
        final pick = slots[rng.nextInt(slots.length)];
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
          final u1 = 1.0 - rng.nextDouble();
          final u2 = rng.nextDouble();
          final g = sqrt(-2 * log(u1)) * cos(2 * pi * u2);
          m.pitchElapsed = m.contactTime + g * sigma;
          m.swingNow();
        } else {
          m.tick(5.0);
        }
      case PitchPhase.ballInPlay:
        if (m.playerBatting) {
          m.tick(5.0);
        } else if (m.interception == null) {
          // Chase with whoever is nearest where it ends up. Tapping at random
          // is not a defence, and makes this a test of nothing.
          var best = m.scheme.fielders.first;
          var bestGap = double.infinity;
          for (final f in m.scheme.fielders) {
            final gap = (m.flight!.restPoint - f.position).length;
            if (gap < bestGap) {
              bestGap = gap;
              best = f;
            }
          }
          m.tapFielder(best.id);
        } else if (m.interception!.caught) {
          // A catch needs no throw. The controller holds the play open for a
          // beat so it can be SEEN before it resolves, so the only thing to
          // do here is let the clock run — exactly what the game does every
          // frame. Tapping a bag at this point is a no-op, and a driver that
          // keeps tapping it instead of ticking wedges forever.
          m.tick(5.0);
        } else if (m.throwResult == null) {
          // Throw at the most advanced runner whose bag is actually guarded.
          Runner? target;
          for (final r in m.runners) {
            if (r.out || m.coverage[r.to] == null) continue;
            if (target == null || r.to > target.to) target = r;
          }
          m.tapBase(target?.to ?? firstBase);
        } else {
          m.tick(5.0);
        }
      case PitchPhase.outcome:
        m.advance();
      case PitchPhase.gameOver:
        break;
    }
  }
  expect(guard, lessThan(40000), reason: 'a game must terminate');
  return m;
}

void main() {
  group('a game always completes', () {
    test('across many seeds', () {
      for (var seed = 0; seed < 25; seed++) {
        final m = playGame(seed: seed);
        expect(m.phase, PitchPhase.gameOver);
        expect(m.progress.inning, greaterThan(GameRules.inningsPerGame));
        expect(m.progress.playerRuns, greaterThanOrEqualTo(0));
      }
    });

    test('somebody scores sooner or later', () {
      // Runners were once pinned at first forever — `from` never updated, so
      // every pitch recomputed them from the plate and no game could score.
      var totalRuns = 0;
      for (var seed = 0; seed < 25; seed++) {
        final m = playGame(seed: seed);
        totalRuns += m.progress.playerRuns + m.progress.opponentRuns;
      }
      expect(totalRuns, greaterThan(0));
    });

    test('and games do not run away', () {
      // They once hit 300 runs, because a settled runner was standing still
      // and no throw could ever retire him.
      for (var seed = 0; seed < 10; seed++) {
        final m = playGame(seed: seed);
        expect(m.progress.playerRuns, lessThan(60));
        expect(m.progress.opponentRuns, lessThan(60));
      }
    });

    test('reports a result', () {
      final m = playGame(seed: 5);
      expect(
        m.message,
        anyOf(contains('win'), contains('lose'), contains('Tied')),
      );
    });
  });

  group('rules hold', () {
    test('three slots, and a used one cannot be played twice', () {
      final m = MatchController(
        playerTeam: StarterTeams.player(),
        opponent: StarterTeams.rookieOpponent(),
        rng: Random(1),
      );
      expect(m.availableSlots.length, slotsPerBatter);
      m.commitSlot(0);
      expect(m.phase, PitchPhase.windUp);
      expect(m.availableSlots, isNot(contains(0)));
    });

    test('a slot cannot be committed while a pitch is in flight', () {
      final m = MatchController(
        playerTeam: StarterTeams.player(),
        opponent: StarterTeams.rookieOpponent(),
        rng: Random(2),
      );
      m.commitSlot(0);
      final before = m.availableSlots.length;
      m.commitSlot(1);
      expect(m.availableSlots.length, before);
    });

    test('the scheme is free to change at every pitch', () {
      final m = MatchController(
        playerTeam: StarterTeams.player(),
        opponent: StarterTeams.rookieOpponent(),
        rng: Random(3),
      );
      // Only while fielding; batting ignores it.
      m.chooseScheme(Schemes.deep);
      expect(m.playerBatting, isTrue);
      expect(m.scheme.id, isNot('deep'));
    });
  });

  group('teams', () {
    test('five men, all of whom field, one of whom catches', () {
      final t = StarterTeams.player();
      expect(t.players.length, playersPerTeam);
      expect(t.fielders.length, playersPerTeam);
      expect(t.fielders.first.id, t.players[t.catcherIndex].id);
    });

    test('a starter loadout is mostly empty', () {
      // Early games are two tribes swinging STIK at each other, and how full
      // the slots are is the progress bar of a run.
      expect(StarterTeams.player().fillRatio, lessThan(0.4));
    });
  });
}
