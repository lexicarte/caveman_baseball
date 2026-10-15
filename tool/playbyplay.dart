// ignore_for_file: avoid_print
//
// Narrates a real game pitch by pitch, through the actual MatchController.
//
// Scorelines tell you whether the numbers are sane. This tells you whether
// the game produces situations worth being in — which is the thing no
// aggregate can show.
import 'dart:math';

import 'package:caveman_baseball/data/starter_team.dart';
import 'package:caveman_baseball/sim/game_rules.dart';
import 'package:caveman_baseball/game/match_controller.dart';
import 'package:caveman_baseball/model/club.dart';
import 'package:caveman_baseball/sim/base_running.dart';
import 'package:caveman_baseball/sim/fielder_spec.dart';
import 'package:caveman_baseball/sim/tap_regions.dart';
import 'package:vector_math/vector_math_64.dart';

/// The angle with the most room in it, within what this club can reach.
double bestAngleFor(Scheme scheme, Club club) {
  var bestAngle = 0.0, bestRoom = -1e9;
  for (var a = -club.maxSpray; a <= club.maxSpray; a += 2) {
    final rad = a * pi / 180.0;
    final p = Vector2(sin(rad) * 22, cos(rad) * 22);
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

String bases(List<Runner> rs) {
  final on = {
    for (final r in rs)
      if (!r.out) r.from,
  };
  final b = [
    on.contains(firstBase) ? '1' : '-',
    on.contains(secondBase) ? '2' : '-',
    on.contains(thirdBase) ? '3' : '-',
  ].join();
  return b == '---' ? 'empty' : b;
}

void main() {
  final rng = Random(11);
  final m = MatchController(
    playerTeam: StarterTeams.player(),
    opponent: StarterTeams.rookieOpponent(),
    rng: rng,
  );
  const sigma = 0.030;

  var guard = 0;
  var half = '';
  while (m.phase != PitchPhase.gameOver && guard < 6000) {
    guard++;
    switch (m.phase) {
      case PitchPhase.commit:
        final label =
            '${m.progress.inningLabel} · ${m.playerBatting ? "YOU" : "THEM"}';
        if (label != half) {
          half = label;
          print('');
          print('=== $label ${'=' * (46 - label.length)}');
        }
        final slots = m.availableSlots;
        final pick = slots[rng.nextInt(slots.length)];
        if (m.playerBatting) {
          m.commitSlot(pick);
          print(
            '${m.batter.name.padRight(5)} '
            '[${m.outs} out, ${bases(m.runners)}] '
            'brings ${m.club.name}',
          );
        } else {
          m.chooseScheme(Schemes.all[rng.nextInt(Schemes.all.length)]);
          m.commitRock(pick);
          print(
            '${m.batter.name.padRight(5)} '
            '[${m.outs} out, ${bases(m.runners)}] '
            'you throw ${m.rock.name} in ${m.scheme.name}',
          );
        }

      case PitchPhase.windUp:
        m.tick(1.0);

      case PitchPhase.inFlight:
        if (m.playerBatting) {
          print('      …it is ${m.rock.name}, they are in ${m.scheme.name}');
          final target = bestAngleFor(m.scheme, m.club);
          final aim =
              (target / m.club.maxSpray).clamp(-1.0, 1.0) *
              GameRules.timingWindow;
          final u1 = 1.0 - rng.nextDouble(), u2 = rng.nextDouble();
          final g = sqrt(-2 * log(u1)) * cos(2 * pi * u2);
          m.pitchElapsed = m.contactTime + aim + g * sigma;
          print('      aim ${target.round()}°, swing');
          m.swingNow();
        } else {
          m.tick(5.0);
        }

      case PitchPhase.ballInPlay:
        if (m.playerBatting) {
          m.tick(5.0);
        } else if (m.interception == null) {
          // Exactly what a tap does in the game: thumb on the ball, nearest
          // man in TIME goes.
          final rest = m.flight!.restPoint;
          final best = TapRegions.resolve(rest.x, rest.y, m.staffedFielders);
          m.tapFielder(best.id);
        } else if (m.interception!.caught) {
          // A catch needs no throw; let the clock run so the play resolves.
          m.tick(5.0);
        } else if (m.throwResult == null) {
          Runner? t;
          for (final r in m.runners) {
            if (r.out || m.coverage[r.to] == null) continue;
            if (t == null || r.to > t.to) t = r;
          }
          m.tapBase(t?.to ?? firstBase);
        } else {
          m.tick(5.0);
        }

      case PitchPhase.outcome:
        final sw = m.swing;
        final fl = m.flight;
        final detail = StringBuffer('      ');
        if (sw != null && sw.verdict.name == 'contact') {
          detail.write('${sw.label}, ${sw.exitSpeed.round()} off the club');
          if (fl != null && fl.carry > 0) {
            detail.write(', carried ${fl.carry.round()}');
          }
          if (fl != null) {
            detail.write(' → ${fl.restPoint.length.round()} paces');
          }
          detail.write('  ');
        }
        detail.write('>> ${m.message}');
        print(detail.toString());
        m.advance();

      case PitchPhase.gameOver:
        break;
    }
  }
  print('');
  print('FINAL  ${m.message}');
}
