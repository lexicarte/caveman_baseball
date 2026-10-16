// The same man, drawn on a grid.
//
// Sprites are written as pictures so they can be read and edited as
// pictures. Each character is one cell; the whole figure is 14 cells tall,
// which is what it has to be — a pixel sprite cannot be scaled without
// breaking the grid, so this set is drawn for the size it is used at.
//
// A caveman reads at this size from four things, in order: a jagged hair
// silhouette, a beard wider than the jaw, a ragged hem so the body does not
// end in a straight line, and bare limbs outside the hide. Build is then
// width and hide colour only.
import 'dart:ui';

import '../../model/player.dart';
import '../sprites/pixel_snap.dart';
import 'caveman.dart';

class PixelCavemanPainter {
  const PixelCavemanPainter();

  static const _pal = <String, Color>{
    'D': Color(0xFF2B241C), // hair and beard
    'S': Color(0xFFC89A6B), // skin
    'N': Color(0xFF1B1712), // eye
    'H': Color(0xFF6A5A46), // hide, steady
    'L': Color(0xFF9C8B6E), // hide, swift
    'K': Color(0xFF3A3026), // hide, mighty
    'C': Color(0xFF8C6239), // club
    'B': Color(0xFFE8DCC0), // bone, rock
    'O': Color(0xFFB4632A), // ochre daub
  };

  static const _shadow = Color(0x44000000);

  static const steady = <String>[
    '..D.D.D...',
    '.DDDDDDDD.',
    'DDDDDDDDDD',
    'DDSSSSSSDD',
    'DSNSSSSNSD',
    '.DSSSSSSD.',
    '..DDDDDD..',
    '...DDDD...',
    '.HHHHHHHH.',
    'SHHHHHHHHS',
    'SHHOOOOHHS',
    '.HHHHHHHH.',
    '..H.HH.H..',
    '..SS..SS..',
  ];

  static const swift = <String>[
    '..D.D.D.',
    '.DDDDDD.',
    'DDDDDDDD',
    'DDSSSSDD',
    'DSNSSNSD',
    '.DSSSSD.',
    '..DDDD..',
    '...DD...',
    '.LLLLLL.',
    'SLLLLLLS',
    'SLOOOOLS',
    '.LLLLLL.',
    '..L.LL..',
    '..SS.SS.',
  ];

  static const mighty = <String>[
    '..D.D.D.D...',
    '.DDDDDDDDDD.',
    'DDDDDDDDDDDD',
    'DDSSSSSSSSDD',
    'DDSNSSSSNSDD',
    '.DSSSSSSSSD.',
    '..DDDDDDDD..',
    '..DDDDDDDD..',
    'KKKKKKKKKKKK',
    'KKKKKKKKKKKK',
    'SKKKOOOOKKKS',
    'SKKKKKKKKKKS',
    '.K.KKKKKK.K.',
    '..SSS..SSS..',
  ];

  static const swinging = <String>[
    '..D.D.D.........',
    '.DDDDDDDD.......',
    'DDDDDDDDDD......',
    'DDSSSSSSDD...CCC',
    'DSNSSSSNSD..CCCC',
    '.DSSSSSSD...CCCC',
    '..DDDDDD....CCC.',
    '...DDDD...CC....',
    '.HHHHHHHHSC.....',
    'SHHHHHHHHS......',
    'SHHOOOOHH.......',
    '.HHHHHHHH.......',
    '.H.HH.HH........',
    '.SS...SS........',
  ];

  static const throwing = <String>[
    '..D.D.D......BB.',
    '.DDDDDDDD...BBBB',
    'DDDDDDDDDD..BBBB',
    'DDSSSSSSDD...BB.',
    'DSNSSSSNSD.S....',
    '.DSSSSSSD.S.....',
    '..DDDDDD.S......',
    '...DDDD.S.......',
    '.HHHHHHHHS......',
    'SHHHHHHHH.......',
    'SHHOOOOHH.......',
    '.HHHHHHHH.......',
    '..H.HH.H........',
    '..SS..SS........',
  ];

  static List<String> standFor(Archetype a) => switch (a) {
    Archetype.swift => swift,
    Archetype.steady => steady,
    Archetype.mighty => mighty,
  };

  /// Run frames by swapping the three leg rows.
  ///
  /// NOT a substitute for hand-drawn frames — a real pixel run cycle wants
  /// drawing in a sprite editor, which is the whole argument for buying one.
  /// This is enough to judge the direction against the cartoon rig.
  static List<String> _running(List<String> stand, double t) {
    final w = stand[0].length;
    final frame = ((t % 1.0) * 4).floor() % 4;
    // front/back foot offsets from centre, per frame
    const offsets = [
      [-3, 2],
      [-2, 1],
      [2, -3],
      [-2, 1],
    ];
    final c = (w / 2).floor() - 1;
    final a = c + offsets[frame][0];
    final b = c + offsets[frame][1];
    final hide = stand[8].replaceAll(RegExp('[^HLK]'), '').isEmpty
        ? 'H'
        : stand[8].replaceAll(RegExp('[^HLK]'), '')[0];

    String row(String ch, int lift) {
      final cells = List.filled(w, '.');
      for (final x in [a, a + 1]) {
        if (x >= 0 && x < w) cells[x] = ch;
      }
      for (final x in [b, b + 1]) {
        if (x >= 0 && x < w && lift == 0) cells[x] = ch;
      }
      return cells.join();
    }

    return [
      ...stand.sublist(0, 12),
      row(hide, 0),
      row('S', frame.isEven ? 0 : 1),
    ];
  }

  void paint(
    Canvas canvas, {
    required Offset ground,
    required Archetype archetype,
    required double height,
    Color? tint,
    bool holdingClub = false,
    bool detailed = false,
    Pose pose = const Pose.still(),
  }) {
    // Same overall height as the other painters, so swapping styles never
    // changes how big anyone is on the field.
    final h = CavemanPainter.drawnHeight(archetype, height);

    final rows = switch (pose.act) {
      Act.swing => swinging,
      Act.throwing => throwing,
      Act.run => _running(standFor(archetype), pose.t),
      Act.still => standFor(archetype),
    };

    final cell = h / rows.length;
    final w = rows[0].length * cell;
    // Whole pixels, so the grid does not shimmer as the camera eases.
    // The cell overlap below still covers a size that is not itself an
    // integer number of pixels — perspective is allowed to shrink a man.
    final dpr =
        PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1.0;
    final snapped =
        PixelSnap.fromCanvas(canvas, dpr)?.snapWorld(ground) ?? ground;
    final left = snapped.dx - (standFor(archetype)[0].length * cell) / 2;
    final top = snapped.dy - h;

    canvas.drawOval(
      Rect.fromCenter(center: snapped, width: w * 0.8, height: cell * 2.4),
      Paint()..color = _shadow,
    );

    final paint = Paint();
    for (var y = 0; y < rows.length; y++) {
      final row = rows[y];
      for (var x = 0; x < row.length; x++) {
        var c = _pal[row[x]];
        if (c == null) continue;
        // The chaser is tinted so you can see who you sent.
        if (tint != null && (row[x] == 'H' || row[x] == 'L' || row[x] == 'K')) {
          c = tint;
        }
        paint.color = c;
        // Half a cell of overlap: without it the grid shows hairlines
        // between cells wherever the camera lands off a whole pixel.
        canvas.drawRect(
          Rect.fromLTWH(
            left + x * cell,
            top + y * cell,
            cell * 1.04,
            cell * 1.04,
          ),
          paint,
        );
      }
    }
  }
}
