// ignore_for_file: avoid_print
//
// Every club against every rock-and-scheme the defence can field.
//
// The design rule this enforces: no defensive combination may be without a
// counter, and no club may beat everything. Reasoning about it on paper does
// not work — the interactions run through ball physics, fielder reach, throw
// timing and base running, and every hand-made prediction in this project has
// been wrong.
import 'dart:math' as math;

import 'package:caveman_baseball/data/clubs.dart';
import 'package:caveman_baseball/data/rocks.dart';
import 'package:caveman_baseball/sim/fielder_spec.dart';

import 'harness.dart';

/// A defensive combination is only truly countered if some club does this
/// well against it.
const counterThreshold = 0.45;

/// A club with at least this much against EVERY defensive combination has no
/// weakness at all.
const dominanceThreshold = 0.42;

const trials = 400;

void main() {
  final clubs = Clubs.all;
  final rocks = Rocks.all;

  // value[clubId][schemeId|rockId]
  final worstPerClub = <String, double>{for (final c in clubs) c.id: 9.9};
  final bestPerDefence = <String, double>{};
  final defenceLabel = <String, String>{};

  for (final scheme in Schemes.all) {
    print('');
    print('=' * 78);
    print('SCHEME ${scheme.name}  —  gives up ${scheme.givesUp}');
    print('total bases per at-bat, timing sigma 35ms');
    print('=' * 78);
    print(
      '${'rock'.padRight(13)}'
      '${clubs.map((c) => c.name.padLeft(11)).join()}${'BEST'.padLeft(8)}',
    );

    for (final rock in rocks) {
      final row = <double>[];
      for (final club in clubs) {
        final v = totalBasesPerAtBat(
          club: club,
          rock: rock,
          scheme: scheme,
          trials: trials,
        );
        row.add(v);
        if (v < worstPerClub[club.id]!) worstPerClub[club.id] = v;
      }
      final best = row.reduce(math.max);
      final key = '${scheme.id}/${rock.id}';
      bestPerDefence[key] = best;
      defenceLabel[key] = '${scheme.name} + ${rock.name}';

      print(
        '${rock.name.padRight(13)}'
        '${row.map((v) => v.toStringAsFixed(2).padLeft(11)).join()}'
        '${best.toStringAsFixed(2).padLeft(8)}',
      );
    }
  }

  print('');
  print('=' * 78);
  print('DEFENCE CHECK — is every rock-and-scheme beatable by something?');
  final uncountered = <String>[];
  for (final e in bestPerDefence.entries) {
    if (e.value < counterThreshold) {
      uncountered.add(
        '${defenceLabel[e.key]} (best ${e.value.toStringAsFixed(2)})',
      );
    }
  }
  if (uncountered.isEmpty) {
    print('  all ${bestPerDefence.length} combinations have a counter. ok');
  } else {
    print('  ${uncountered.length} of ${bestPerDefence.length} UNCOUNTERED:');
    for (final u in uncountered) {
      print('    $u');
    }
  }

  print('');
  print('CLUB CHECK — does every club have a weakness?');
  var anyDominant = false;
  for (final c in clubs) {
    final worst = worstPerClub[c.id]!;
    final flag = worst >= dominanceThreshold ? '  <-- NO WEAKNESS' : '';
    if (flag.isNotEmpty) anyDominant = true;
    print('  ${c.name.padRight(12)} worst ${worst.toStringAsFixed(2)}$flag');
  }
  if (!anyDominant) print('  every club is beaten by something. ok');
}
