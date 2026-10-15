// What is the SMALLEST change to scheme geometry that makes every man
// tappable in portrait? Two squeezes showed up in tool/tap_regions.dart:
//   CLOSE  — thrower at depth 10 against a centre fielder at 16
//   LINE   — three men at 23 paces, only 14 degrees apart
// These depths are balance-tuned, so this only reports what would work. It
// changes nothing.
import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:caveman_baseball/model/player.dart';
import 'package:caveman_baseball/sim/field_spec.dart';
import 'package:caveman_baseball/sim/fielder_spec.dart';

double squash = 0.62;
const double gridPx = 2.0;
const double tapRadiusPt = 22.0;

({double r, String id}) worstRegion(
  List<FielderSpec> men,
  double px,
  FieldSpec field,
) {
  final halfW = field.wallRadius * math.sin(field.foulAngleRadians) + 6.0;
  const back = 6.0;
  final w = (2 * halfW * px / gridPx).ceil() + 1;
  final h = ((field.wallRadius + back) * px * squash / gridPx).ceil() + 1;
  final owner = List<int>.filled(w * h, -1);

  for (var gy = 0; gy < h; gy++) {
    for (var gx = 0; gx < w; gx++) {
      final fx = (gx * gridPx) / px - halfW;
      final fy = (h - 1 - gy) * gridPx / (px * squash) - back;
      if (math.sqrt(fx * fx + fy * fy) > field.wallRadius) continue;
      final p = Vector2(fx, fy);
      var best = double.infinity;
      var bi = -1;
      for (var i = 0; i < men.length; i++) {
        final t = men[i].timeToReach(p);
        if (t < best) {
          best = t;
          bi = i;
        }
      }
      owner[gy * w + gx] = bi;
    }
  }

  const big = 1e9;
  final dist = List<double>.filled(w * h, big);
  for (var gy = 0; gy < h; gy++) {
    for (var gx = 0; gx < w; gx++) {
      if (owner[gy * w + gx] < 0) continue;
      final o = owner[gy * w + gx];
      var edge = false;
      for (var dy = -1; dy <= 1 && !edge; dy++) {
        for (var dx = -1; dx <= 1 && !edge; dx++) {
          final nx = gx + dx, ny = gy + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          final q = owner[ny * w + nx];
          if (q != -1 && q != o) edge = true;
        }
      }
      if (edge) dist[gy * w + gx] = 0;
    }
  }
  const d1 = 1.0, d2 = 1.4142135623730951;
  void relax(int gx, int gy, int nx, int ny, double c) {
    if (nx < 0 || ny < 0 || nx >= w || ny >= h) return;
    final v = dist[ny * w + nx] + c;
    if (v < dist[gy * w + gx]) dist[gy * w + gx] = v;
  }

  for (var gy = 0; gy < h; gy++) {
    for (var gx = 0; gx < w; gx++) {
      relax(gx, gy, gx - 1, gy, d1);
      relax(gx, gy, gx, gy - 1, d1);
      relax(gx, gy, gx - 1, gy - 1, d2);
      relax(gx, gy, gx + 1, gy - 1, d2);
    }
  }
  for (var gy = h - 1; gy >= 0; gy--) {
    for (var gx = w - 1; gx >= 0; gx--) {
      relax(gx, gy, gx + 1, gy, d1);
      relax(gx, gy, gx, gy + 1, d1);
      relax(gx, gy, gx + 1, gy + 1, d2);
      relax(gx, gy, gx - 1, gy + 1, d2);
    }
  }

  final best = List<double>.filled(men.length, 0);
  for (var i = 0; i < owner.length; i++) {
    final o = owner[i];
    if (o < 0) continue;
    final r = dist[i] * gridPx;
    if (r > best[o]) best[o] = r;
  }
  var wi = 0;
  for (var i = 1; i < best.length; i++) {
    if (best[i] < best[wi]) wi = i;
  }
  return (r: best[wi], id: men[wi].id);
}

List<FielderSpec> staff(List<FielderSpec> posts, List<Archetype> a) => [
  for (var i = 0; i < posts.length; i++)
    posts[i].withPlayer(Player(id: 'x$i', name: 'x', archetype: a[i])),
];

/// Worst over every archetype assignment.
({double r, String id}) worstOverLineups(
  List<FielderSpec> posts,
  double px,
  FieldSpec f,
) {
  var worst = (r: double.infinity, id: '');
  final acc = <Archetype>[];
  void rec() {
    if (acc.length == 5) {
      final v = worstRegion(staff(posts, acc), px, f);
      if (v.r < worst.r) worst = v;
      return;
    }
    for (final a in Archetype.values) {
      acc.add(a);
      rec();
      acc.removeLast();
    }
  }

  rec();
  return worst;
}

void main() {
  final field = FieldSpec.compact;

  FielderSpec post(String id, double ang, double depth) =>
      FielderSpec(id: id, name: id, angleDegrees: ang, depth: depth);
  const catcher = FielderSpec(
    id: 'c',
    name: 'c',
    angleDegrees: 0,
    depth: 0,
    range: 4.0,
    reactionTime: 0.45,
  );
  const thrower = FielderSpec(
    id: 'p',
    name: 'p',
    angleDegrees: 0,
    depth: 10,
    range: 5.07,
    reactionTime: 0.55,
  );

  final schemes = <String, List<FielderSpec>>{
    'CLOSE': [
      catcher,
      thrower,
      post('lf', -35, 15),
      post('cf', 0, 16),
      post('rf', 35, 15),
    ],
    'DEEP': [
      catcher,
      thrower,
      post('lf', -35, 29),
      post('cf', 0, 32),
      post('rf', 35, 29),
    ],
    'LINE': [
      catcher,
      thrower,
      post('lf', -14, 23),
      post('cf', 0, 23),
      post('rf', 14, 23),
    ],
    'WIDE': [
      catcher,
      thrower,
      post('lf', -44, 21),
      post('cf', 0, 31),
      post('rf', 44, 21),
    ],
    'WHEEL': [
      catcher,
      thrower,
      post('lf', -38, 21),
      post('cf', 0, 28),
      post('rf', 38, 21),
    ],
  };

  print('Worst tappable region, over all 243 lineups. Needs >= 22px radius.');
  print('Portrait, 6.3 px/pace. Only the ground squash changes.\n');
  print('  squash   ${schemes.keys.map((k) => k.padRight(12)).join()}');
  for (final sq in [0.62, 0.70, 0.78, 0.80, 0.90, 1.00]) {
    squash = sq;
    final cells = <String>[];
    var allOk = true;
    for (final e in schemes.entries) {
      final v = worstOverLineups(e.value, 6.3, field);
      if (v.r < tapRadiusPt) allOk = false;
      cells.add('${v.r.toStringAsFixed(0).padLeft(2)}px ${v.id}'.padRight(12));
    }
    print(
      '  ${sq.toStringAsFixed(2)}     ${cells.join()}'
      '${allOk ? "  <-- all pass" : ""}',
    );
  }

  print('\nThe arithmetic: the catcher sits at depth 0 and the thrower at');
  print('depth 10, both dead centre. Their separation on screen is');
  print('10 paces x px/pace x squash, and the best either can do is half of');
  print(
    'that. At 6.3 px/pace a 44pt thumb needs squash >= ${(44.0 / (10 * 6.3)).toStringAsFixed(2)}.',
  );
}
