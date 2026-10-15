// Can you tap a REGION instead of a man, in every configuration?
//
// Region tap replaces "hit the 28px sprite" with "hit the patch of ground
// that belongs to him". The patch is earliest-arrival: a point belongs to
// whoever could stand on it soonest, which is FielderSpec.timeToReach — so
// the map already knows about reaction time and who is fast.
//
// That means the regions move when the lineup moves, and a slow man wedged
// between two quick ones could in principle end up with no region at all.
// This sweeps every scheme against every archetype assignment and measures,
// in screen pixels, the largest circle that fits inside each man's region.
// If that circle is smaller than a thumb, the region is not tappable and the
// whole idea fails for that configuration.
import 'dart:math' as math;

import 'package:caveman_baseball/model/player.dart';
import 'package:caveman_baseball/sim/field_spec.dart';
import 'package:caveman_baseball/sim/fielder_spec.dart';
import 'package:caveman_baseball/sim/tap_regions.dart';

/// Apple and Material both land on 44pt. Half of it is the radius a thumb
/// needs to sit clear of the nearest boundary.
const double tapDiameterPt = 44.0;
const double tapRadiusPt = tapDiameterPt / 2;

/// Render squash, from lib/game/ground.dart. Depth is compressed on screen,
/// so two men separated in depth are closer under the thumb than the field
/// says they are. This is the whole reason the question is hard.
const double squash = 0.62;

const double gridPx = 2.0;

class Verdict {
  Verdict(this.scheme, this.staffing, this.perMan, this.empty);
  final String scheme;
  final String staffing;

  /// Largest inscribed circle radius, in px, per fielder id.
  final Map<String, double> perMan;
  final List<String> empty;

  double get worst =>
      perMan.values.isEmpty ? 0 : perMan.values.reduce(math.min);
  String get worstMan {
    var id = '';
    var best = double.infinity;
    perMan.forEach((k, v) {
      if (v < best) {
        best = v;
        id = k;
      }
    });
    return id;
  }
}

/// Measures one arrangement at one zoom.
Verdict measure(
  Scheme scheme,
  List<Archetype> staffing,
  double pxPerPace,
  FieldSpec field, {
  bool fairOnly = false,
}) {
  final men = [
    for (var i = 0; i < scheme.fielders.length; i++)
      scheme.fielders[i].withPlayer(
        Player(id: 'x$i', name: 'x', archetype: staffing[i]),
      ),
  ];

  // Work in screen pixels directly, so the measurement is in the units the
  // thumb lives in. x is unsquashed, y is squashed.
  final halfW = field.wallRadius * math.sin(field.foulAngleRadians);
  // The tappable domain is the visible GROUND, not just fair territory: foul
  // ground and the dirt behind the plate are on screen and are exactly where
  // the catcher's region wants to live.
  final backDepth = fairOnly ? 0.0 : 6.0;
  final sideW = fairOnly ? halfW : halfW + 6.0;
  final w = (2 * sideW * pxPerPace / gridPx).ceil() + 1;
  final h =
      ((field.wallRadius + backDepth) * pxPerPace * squash / gridPx).ceil() + 1;

  final owner = List<int>.filled(w * h, -1);
  final inPlay = List<bool>.filled(w * h, false);

  for (var gy = 0; gy < h; gy++) {
    for (var gx = 0; gx < w; gx++) {
      // Screen px back to field paces.
      final fx = (gx * gridPx) / pxPerPace - sideW;
      final fy = (h - 1 - gy) * gridPx / (pxPerPace * squash) - backDepth;
      if (fairOnly && !field.isFair(fx, fy)) continue;
      if (math.sqrt(fx * fx + fy * fy) > field.wallRadius) continue;

      // Ask the shipped resolver, so this measures the real behaviour and
      // not a second copy of the same arithmetic.
      owner[gy * w + gx] = men.indexOf(TapRegions.resolve(fx, fy, men));
      inPlay[gy * w + gx] = true;
    }
  }

  // Distance to the nearest DIFFERENT owner, by two-pass chamfer. Only
  // inter-region boundaries count; running off the edge of the field does
  // not shrink a region, because you were never going to tap there anyway.
  const big = 1e9;
  final dist = List<double>.filled(w * h, big);
  bool boundary(int gx, int gy) {
    final o = owner[gy * w + gx];
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final nx = gx + dx, ny = gy + dy;
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        final q = owner[ny * w + nx];
        if (q != -1 && q != o) return true;
      }
    }
    return false;
  }

  for (var gy = 0; gy < h; gy++) {
    for (var gx = 0; gx < w; gx++) {
      if (!inPlay[gy * w + gx]) continue;
      if (boundary(gx, gy)) dist[gy * w + gx] = 0;
    }
  }

  const d1 = 1.0, d2 = 1.4142135623730951;
  void relax(int gx, int gy, int nx, int ny, double cost) {
    if (nx < 0 || ny < 0 || nx >= w || ny >= h) return;
    final v = dist[ny * w + nx] + cost;
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

  final perMan = <String, double>{};
  final seen = <int>{};
  for (var gy = 0; gy < h; gy++) {
    for (var gx = 0; gx < w; gx++) {
      final o = owner[gy * w + gx];
      if (o < 0) continue;
      seen.add(o);
      final r = dist[gy * w + gx] * gridPx;
      final id = men[o].id;
      if (r > (perMan[id] ?? -1)) perMan[id] = r;
    }
  }

  final empty = [
    for (var i = 0; i < men.length; i++)
      if (!seen.contains(i)) men[i].id,
  ];
  for (final id in empty) {
    perMan[id] = 0;
  }
  return Verdict(
    scheme.name,
    staffing.map((a) => a.name[0]).join(),
    perMan,
    empty,
  );
}

void main(List<String> args) {
  final field = FieldSpec.compact;
  final zooms = <String, double>{
    'portrait 6.3': 6.3,
    'portrait 6.9 (the 390pt ceiling)': 6.9,
    'landscape 11.0': 11.0,
  };

  // Every archetype assignment over the five posts, not just the ones the
  // starter roster can make. 243 of them.
  final all = <List<Archetype>>[];
  void build(List<Archetype> acc) {
    if (acc.length == 5) {
      all.add(List.of(acc));
      return;
    }
    for (final a in Archetype.values) {
      build([...acc, a]);
    }
  }

  build([]);

  final fairOnly = args.contains('--fair-only');
  for (final entry in zooms.entries) {
    final px = entry.value;
    print(
      '\n=== ${entry.key} — $px px per pace '
      '(tap target ${tapDiameterPt.toInt()}pt'
      '${fairOnly ? ", fair territory only" : ", whole visible ground"}) ===',
    );
    var failures = 0;
    var empties = 0;
    Verdict? absoluteWorst;
    final bySchemeWorst = <String, Verdict>{};

    for (final scheme in Schemes.all) {
      for (final staffing in all) {
        final v = measure(scheme, staffing, px, field, fairOnly: fairOnly);
        if (v.empty.isNotEmpty) empties++;
        if (v.worst < tapRadiusPt) failures++;
        final cur = bySchemeWorst[scheme.name];
        if (cur == null || v.worst < cur.worst) bySchemeWorst[scheme.name] = v;
        if (absoluteWorst == null || v.worst < absoluteWorst.worst) {
          absoluteWorst = v;
        }
      }
    }

    final total = Schemes.all.length * all.length;
    for (final scheme in Schemes.all) {
      final v = bySchemeWorst[scheme.name]!;
      final ok = v.worst >= tapRadiusPt;
      print(
        '  ${scheme.name.padRight(6)} worst region '
        '${v.worst.toStringAsFixed(0).padLeft(3)}px radius  '
        '(${v.worstMan}, lineup ${v.staffing})  '
        '${ok ? "OK" : "FAILS"}',
      );
    }
    print('  ---');
    print(
      '  $failures of $total configurations below '
      '${tapRadiusPt.toInt()}px radius; $empties with an unreachable man.',
    );
    if (absoluteWorst != null) {
      final w = absoluteWorst;
      print(
        '  worst overall: ${w.scheme} lineup ${w.staffing} — '
        '${w.perMan.entries.map((e) => "${e.key}:${e.value.toStringAsFixed(0)}").join("  ")}',
      );
    }
  }
}
