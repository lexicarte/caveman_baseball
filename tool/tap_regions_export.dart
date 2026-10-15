// Emits the tap map as JSON for the design canvas, so the picture on the
// board is generated from the shipped resolver rather than redrawn by hand.
import 'dart:convert';
import 'dart:math' as math;

import 'package:caveman_baseball/model/player.dart';
import 'package:caveman_baseball/sim/field_spec.dart';
import 'package:caveman_baseball/sim/fielder_spec.dart';
import 'package:caveman_baseball/sim/tap_regions.dart';

const double step = 0.5; // paces per cell
const double xMin = -34, xMax = 34, yMin = -6, yMax = 38;

void main() {
  final field = FieldSpec.compact;
  final out = <String, dynamic>{
    'step': step,
    'xMin': xMin,
    'yMin': yMin,
    'wall': field.wallRadius,
    'foul': field.foulAngleDegrees,
    'schemes': <Map<String, dynamic>>[],
  };

  // One representative lineup: the starter roster's shape, mighty at the
  // plate because that is where StarterTeams puts him.
  const lineup = [
    Archetype.mighty,
    Archetype.steady,
    Archetype.swift,
    Archetype.steady,
    Archetype.swift,
  ];

  for (final scheme in Schemes.all) {
    final men = [
      for (var i = 0; i < scheme.fielders.length; i++)
        scheme.fielders[i].withPlayer(
          Player(id: 'x$i', name: 'x', archetype: lineup[i]),
        ),
    ];
    final ids = [for (final m in men) m.id];

    final cols = ((xMax - xMin) / step).round();
    final rows = ((yMax - yMin) / step).round();

    // Run-length encoded per row: [owner, runLength, owner, runLength, ...]
    // with -1 for "off the field". Keeps the payload small enough to inline.
    final grid = <List<int>>[];
    for (var r = 0; r < rows; r++) {
      final y = yMin + r * step + step / 2;
      final runs = <int>[];
      var cur = -2, len = 0;
      for (var c = 0; c < cols; c++) {
        final x = xMin + c * step + step / 2;
        var owner = -1;
        if (math.sqrt(x * x + y * y) <= field.wallRadius) {
          owner = ids.indexOf(TapRegions.resolve(x, y, men).id);
        }
        if (owner == cur) {
          len++;
        } else {
          if (cur != -2) {
            runs.add(cur);
            runs.add(len);
          }
          cur = owner;
          len = 1;
        }
      }
      if (cur != -2) {
        runs.add(cur);
        runs.add(len);
      }
      grid.add(runs);
    }

    out['schemes'].add({
      'name': scheme.name,
      'givesUp': scheme.givesUp,
      'ids': ids,
      'men': [
        for (final m in men)
          {
            'id': m.id,
            'x': double.parse(m.position.x.toStringAsFixed(2)),
            'y': double.parse(m.position.y.toStringAsFixed(2)),
            'archetype': lineup[ids.indexOf(m.id)].name,
          },
      ],
      'cols': cols,
      'rows': rows,
      'grid': grid,
    });
  }

  // ignore: avoid_print
  print(jsonEncode(out));
}
