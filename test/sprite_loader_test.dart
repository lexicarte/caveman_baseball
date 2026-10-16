import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:caveman_baseball/game/components/caveman.dart';
import 'package:caveman_baseball/game/sprites/field_figure.dart';
import 'package:caveman_baseball/game/sprites/pixel_snap.dart';
import 'package:caveman_baseball/game/sprites/sprite_library.dart';
import 'package:caveman_baseball/game/sprites/sprite_name.dart';
import 'package:caveman_baseball/game/sprites/sprite_strip.dart';
import 'package:caveman_baseball/main.dart';
import 'package:caveman_baseball/model/player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('names', () {
    test('cb_<category>_<subject>_<state> round-trips', () {
      const swing = SpriteName(
        category: 'anim',
        subject: 'steady',
        state: 'swing',
      );
      expect(swing.stem, 'cb_anim_steady_swing');
      expect(swing.pngAsset, 'assets/sprites/players/cb_anim_steady_swing.png');
      expect(
        swing.jsonAsset,
        'assets/sprites/players/cb_anim_steady_swing.json',
      );
      expect(SpriteName.parse(swing.stem), swing);

      expect(
        SpriteName.parse('cb_rock_rok'),
        const SpriteName(category: 'rock', subject: 'rok'),
      );
      expect(
        SpriteName.parse('cb_rock_rok')!.pngAsset,
        'assets/sprites/rocks/cb_rock_rok.png',
      );
      expect(SpriteName.parse('cb_club_stik_field')!.folder, 'clubs');
      expect(
        SpriteName.parse('cb_card_frame_stone_club'),
        const SpriteName(
          category: 'card',
          subject: 'frame',
          state: 'stone_club',
        ),
      );
      expect(SpriteName.parse('steady_swing'), isNull);
      expect(SpriteName.parse('cb_only'), isNull);
      expect(SpriteName.parse('CB_ANIM_STEADY_SWING'), isNull);
    });
  });

  group('sidecar', () {
    const swingJson = '''
      { "cell": [64, 64], "frames": 6,
        "durationsMs": [70, 70, 70, 70, 70, 70],
        "pivot": [32, 63], "key": 5 }
    ''';

    test('six equal frames put the key frame on screen at 0.67', () {
      final spec = SpriteStripSpec.fromJson(swingJson);
      expect(spec.cellW, 64);
      expect(spec.cellH, 64);
      expect(spec.pivotX, 32);
      expect(spec.pivotY, 63);
      expect(spec.key, 5);
      expect(spec.keyIndex, 4);
      expect(spec.keyPhase, closeTo(4 / 6, 1e-12));
      expect(spec.frameAt(0), 0);
      expect(spec.frameAt(spec.keyPhase!), 4);
      expect(spec.frameAt(0.67), 4);
      expect(spec.frameAt(1), 5);
    });

    test('an omitted cell and pivot are the 64×64 field cell', () {
      final spec = SpriteStripSpec.fromJson({
        'frames': 2,
        'durationsMs': [400, 400],
      });
      expect(spec.cellW, 64);
      expect(spec.cellH, 64);
      expect(spec.pivotX, 32);
      expect(spec.pivotY, 63);
      expect(spec.key, isNull);
    });

    test('a throw releases on its key frame', () {
      final spec = SpriteStripSpec.fromJson({
        'cell': [64, 64],
        'frames': 4,
        'durationsMs': [100, 100, 80, 100],
        'pivot': [32, 63],
        'key': 3,
      });
      expect(spec.keyPhase, closeTo(200 / 380, 1e-12));
      expect(spec.frameAt(spec.keyPhase!), 2);
    });

    test('a strip that does not match its sidecar is refused', () {
      final spec = SpriteStripSpec.fromJson(swingJson);
      expect(() => spec.validateImage(384, 64), returnsNormally);
      expect(() => spec.validateImage(64, 64), throwsFormatException);
      expect(() => spec.validateImage(384, 32), throwsFormatException);
      expect(
        () => SpriteStripSpec.fromJson({
          'frames': 6,
          'durationsMs': [70, 70],
        }),
        throwsFormatException,
      );
      expect(
        () => SpriteStripSpec.fromJson({
          'frames': 1,
          'durationsMs': [70],
          'key': 0,
        }),
        throwsFormatException,
      );
    });
  });

  group('placement', () {
    const spec = SpriteStripSpec(
      cellW: 64,
      cellH: 64,
      frames: 6,
      durationsMs: [70, 70, 70, 70, 70, 70],
      pivotX: 32,
      pivotY: 63,
      key: 5,
    );

    test('the pivot sits on the ground, on a whole device pixel', () {
      const space = PixelSnap(
        scaleX: 10,
        scaleY: 10,
        tx: 0,
        ty: 0,
        devicePixelRatio: 1,
      );
      // 4.8 world units * 10 px = 48 logical px of body, so 1 art px = 1 px.
      final placed = SpritePlacement.compute(
        spec: spec,
        frame: 4,
        ground: const Offset(1.04, 2.06),
        cellWorldHeight: 4.8 * 64 / 48,
        space: space,
      );
      expect(placed.paint.filterQuality, FilterQuality.none);
      expect(placed.source, const Rect.fromLTWH(256, 0, 64, 64));

      final anchorDevice = space.worldToDevice(placed.anchor);
      expect(anchorDevice.dx, anchorDevice.dx.roundToDouble());
      expect(anchorDevice.dy, anchorDevice.dy.roundToDouble());
      expect(anchorDevice.dx, 10);
      expect(anchorDevice.dy, 21);

      final cellDevice =
          space.worldToDevice(placed.destination.bottomRight) -
          space.worldToDevice(placed.destination.topLeft);
      expect(cellDevice.dx, 64);
      expect(cellDevice.dy, 64);

      final pivot =
          space.worldToDevice(placed.destination.topLeft) +
          const Offset(32, 63);
      expect(pivot.dx, closeTo(anchorDevice.dx, 1e-6));
      expect(pivot.dy, closeTo(anchorDevice.dy, 1e-6));
    });

    test('2× and 3× lock to whole art pixels', () {
      for (final dpr in [2.0, 3.0]) {
        final space = PixelSnap(
          scaleX: 10,
          scaleY: 10,
          tx: 0,
          ty: 0,
          devicePixelRatio: dpr,
        );
        final placed = SpritePlacement.compute(
          spec: spec,
          frame: 0,
          ground: Offset.zero,
          cellWorldHeight: 4.8 * 64 / 48,
          space: space,
        );
        final cell =
            space.worldToDevice(placed.destination.bottomRight) -
            space.worldToDevice(placed.destination.topLeft);
        expect(cell.dx, 64 * dpr);
        expect(cell.dy, 64 * dpr);
      }
    });

    test('a distant figure may be smaller than one art pixel per pixel', () {
      const space = PixelSnap.identity();
      final placed = SpritePlacement.compute(
        spec: spec,
        frame: 0,
        ground: Offset.zero,
        cellWorldHeight: 32,
        space: space,
      );
      expect(placed.destination.height, 32);
    });
  });

  group('loading', () {
    test('registered sprite folders are in the asset bundle', () async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets();
      for (final folder in ['players', 'clubs', 'rocks', 'field', 'ui']) {
        expect(
          assets,
          contains('assets/sprites/$folder/.gitkeep'),
          reason: folder,
        );
      }
    });

    test('no sheets yet, so every pose falls back', () async {
      final library = SpriteLibrary();
      await library.loadAvailable();
      expect(library.stems, isEmpty);
      for (final archetype in Archetype.values) {
        expect(
          library.forFigure(
            archetype,
            const Pose.swing(0.67),
            holdingClub: true,
          ),
          isNull,
        );
      }
    });

    test('a bad sidecar does not throw and does not install', () async {
      final library = SpriteLibrary();
      final ok = await library.addFromBytes(
        name: const SpriteName(
          category: 'anim',
          subject: 'steady',
          state: 'swing',
        ),
        sidecarJson: '{',
        pngBytes: Uint8List(0),
      );
      expect(ok, isFalse);
      expect(library.stems, isEmpty);
    });

    testWidgets('a real strip draws its pivot pixel, unfiltered', (t) async {
      // Image decode and picture rasterisation complete on the engine's
      // real event loop. The widget binding's fake async never pumps that,
      // so both calls have to run outside it.
      final bytes = _png(width: 128, height: 64, framesOf: 64);
      final library = SpriteLibrary();
      final name = const SpriteName(
        category: 'anim',
        subject: 'steady',
        state: 'idle',
      );
      final ok = await t.runAsync(
        () => library.addFromBytes(
          name: name,
          sidecarJson:
              '{"cell":[64,64],"frames":2,"durationsMs":[400,400],"pivot":[32,63]}',
          pngBytes: bytes,
        ),
      );
      expect(ok, isTrue);

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.scale(2);
      paintFieldFigure(
        canvas,
        sprites: library,
        ground: const Offset(16, 31.5),
        archetype: Archetype.steady,
        height: 48 / CavemanPainter.steadyDrawnFactor,
        holdingClub: true,
        pose: const Pose.still(),
        devicePixelRatio: 1,
      );
      final image = await t.runAsync(
        () => recorder.endRecording().toImage(128, 128),
      );
      expect(image, isNotNull);
      final shot = image!;
      final raw = await t.runAsync(
        () => shot.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      expect(raw, isNotNull);

      // scale 2, dpr 1, body 48px → each art pixel is a 2×2 block. The red
      // pixel is the pivot, so it lands on the ground (32, 63) and does not
      // bleed into the next pixel the way a linear filter would.
      expect(_pixel(raw!, shot.width, 32, 63), [255, 0, 0, 255]);
      expect(_pixel(raw, shot.width, 33, 64), [255, 0, 0, 255]);
      expect(_pixel(raw, shot.width, 34, 63), [0, 0, 255, 255]);

      shot.dispose();
      library.dispose();
    });

    testWidgets('the match screen builds with no sprite files', (t) async {
      await t.binding.setSurfaceSize(const Size(390, 844));
      await t.pumpWidget(const CavemanBaseballApp());
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('missing art still paints a code-drawn man', (t) async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      paintFieldFigure(
        canvas,
        sprites: SpriteLibrary(),
        ground: const Offset(40, 80),
        archetype: Archetype.mighty,
        height: 48,
        pose: const Pose.swing(0.3),
        holdingClub: true,
      );
      final image = await t.runAsync(
        () => recorder.endRecording().toImage(160, 120),
      );
      expect(image, isNotNull);
      final shot = image!;
      final raw = await t.runAsync(
        () => shot.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      expect(raw, isNotNull);
      final painted = raw!.buffer.asUint8List().any((b) => b != 0);
      expect(painted, isTrue, reason: 'the fallback painter drew nothing');
      shot.dispose();
    });
  });
}

List<int> _pixel(ByteData raw, int width, int x, int y) {
  final i = (y * width + x) * 4;
  final b = raw.buffer.asUint8List();
  return [b[i], b[i + 1], b[i + 2], b[i + 3]];
}

/// A horizontal strip. Frame 0 has one red pixel at (32, 63); the rest of
/// the strip is blue, so a filtered scale would bleed red into the neighbours.
Uint8List _png({
  required int width,
  required int height,
  required int framesOf,
}) {
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0);
    for (var x = 0; x < width; x++) {
      final red = x < framesOf && x == 32 && y == 63;
      raw.add(red ? const [255, 0, 0, 255] : const [0, 0, 255, 255]);
    }
  }
  final compressed = zlib.encode(raw.takeBytes());
  final out = BytesBuilder();
  out.add(const [137, 80, 78, 71, 13, 10, 26, 10]);
  out.add(_chunk('IHDR', _ihdr(width, height)));
  out.add(_chunk('IDAT', compressed));
  out.add(_chunk('IEND', const []));
  return out.toBytes();
}

Uint8List _ihdr(int width, int height) {
  final b = ByteData(13);
  b.setUint32(0, width);
  b.setUint32(4, height);
  b.setUint8(8, 8);
  b.setUint8(9, 6);
  return b.buffer.asUint8List();
}

Uint8List _chunk(String tag, List<int> data) {
  final out = BytesBuilder();
  final header = ByteData(8);
  header.setUint32(0, data.length);
  out.add(header.buffer.asUint8List(0, 4));
  out.add(tag.codeUnits);
  out.add(data);
  final crc = _crc([...tag.codeUnits, ...data]);
  final tail = ByteData(4)..setUint32(0, crc);
  out.add(tail.buffer.asUint8List());
  return out.toBytes();
}

int _crc(List<int> data) {
  var c = 0xffffffff;
  for (final byte in data) {
    c ^= byte;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xedb88320 ^ (c >> 1) : c >> 1;
    }
  }
  return (c ^ 0xffffffff) & 0xffffffff;
}
