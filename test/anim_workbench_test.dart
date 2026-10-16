// The workbench is a dev tool, but a dev tool that throws on launch is worse
// than none. This pumps it, walks every action, and fails on any paint
// exception or layout overflow.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caveman_baseball/game/components/caveman.dart';
import 'package:caveman_baseball/game/look.dart';
import 'package:caveman_baseball/main_anim.dart';
import 'package:caveman_baseball/model/player.dart';

void main() {
  testWidgets('the workbench launches and every action draws', (t) async {
    await t.binding.setSurfaceSize(const Size(1280, 900));
    await t.pumpWidget(const AnimWorkbenchApp());
    await t.pump(const Duration(milliseconds: 16));

    for (final a in Act.values) {
      await t.tap(find.widgetWithText(ChoiceChip, a.name));
      await t.pump(const Duration(milliseconds: 16));
      await t.pump(const Duration(milliseconds: 120));
      expect(lastException(), isNull, reason: 'drawing ${a.name} threw');
    }

    // The in-game size button is the point of the whole tool.
    await t.tap(
      find.text('in-game ${LookDefaults.fieldFigurePoints.round()}px'),
    );
    await t.pump(const Duration(milliseconds: 16));
    expect(lastException(), isNull);

    await t.binding.setSurfaceSize(null);
  });

  group('a run cycle cannot skate', () {
    test('stride grows with build, as the figure does', () {
      final swift = CavemanPainter.strideFor(Archetype.swift, 28);
      final steady = CavemanPainter.strideFor(Archetype.steady, 28);
      final mighty = CavemanPainter.strideFor(Archetype.mighty, 28);
      expect(swift, lessThan(steady));
      expect(steady, lessThan(mighty));
    });

    test(
      'the slip-free cycle walks the stride off in exactly its own time',
      () {
        // This is the whole contract: stride / speed == cycle. If it ever
        // drifts, the feet slide along the ground and everybody notices.
        const px = 6.3;
        for (final a in Archetype.values) {
          for (final h in [28.0, 90.0, 180.0]) {
            final scale = px * (h / 28.0);
            final cycle = CavemanPainter.runCycleSecondsFor(
              a,
              h,
              pxPerUnit: scale,
            );
            final speed =
                (13.0 / 2.58) *
                Player(id: '_', name: '_', archetype: a).speedScale *
                scale;
            expect(
              cycle * speed,
              closeTo(CavemanPainter.strideFor(a, h), 1e-9),
              reason: '${a.name} at ${h}px',
            );
          }
        }
      },
    );

    test('a faster man turns his legs over faster', () {
      double cyc(Archetype a) =>
          CavemanPainter.runCycleSecondsFor(a, 28, pxPerUnit: 6.3);
      expect(cyc(Archetype.swift), lessThan(cyc(Archetype.steady)));
      expect(cyc(Archetype.steady), lessThan(cyc(Archetype.mighty)));
    });
  });
}

Object? lastException() => TestWidgetsFlutterBinding.instance.takeException();
