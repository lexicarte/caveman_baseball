import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../model/player.dart';
import '../components/caveman.dart';
import 'pixel_snap.dart';
import 'sprite_name.dart';
import 'sprite_strip.dart';

/// The strips that actually exist on disk.
///
/// A missing file is not an error. [forFigure] returns null and the field
/// keeps drawing the code-drawn man, so the game runs before any art lands.
class SpriteLibrary {
  final Map<String, SpriteStrip> _strips = {};

  Iterable<String> get stems => _strips.keys;

  SpriteStrip? operator [](String stem) => _strips[stem];

  /// The sheet for what this man is doing, or null to use the painter.
  SpriteStrip? forFigure(
    Archetype archetype,
    Pose pose, {
    required bool holdingClub,
  }) {
    final state = switch (pose.act) {
      Act.swing => 'swing',
      Act.throwing => 'throw',
      Act.run => 'run',
      Act.still => holdingClub ? 'idle' : 'ready',
    };
    final name = SpriteName(
      category: 'anim',
      subject: archetype.name,
      state: state,
    );
    return _strips[name.stem];
  }

  /// Reads every `cb_*.png` under `assets/sprites/` that has a JSON sidecar.
  ///
  /// One bad file is skipped. The rest still load, and anything skipped
  /// falls back to the painter.
  Future<void> loadAvailable([AssetBundle? bundle]) async {
    final assets = bundle ?? rootBundle;
    final AssetManifest manifest;
    try {
      manifest = await AssetManifest.loadFromAssetBundle(assets);
    } catch (e) {
      debugPrint('sprite manifest unavailable: $e');
      return;
    }
    for (final key in manifest.listAssets()) {
      if (!key.startsWith('assets/sprites/') || !key.endsWith('.png')) {
        continue;
      }
      if (key.contains('/2.0x/') || key.contains('/3.0x/')) continue;
      final stem = key.split('/').last;
      final name = SpriteName.parse(stem.substring(0, stem.length - 4));
      if (name == null) continue;
      final jsonKey = '${key.substring(0, key.length - 4)}.json';
      try {
        final sidecar = await assets.loadString(jsonKey);
        final bytes = await assets.load(key);
        final ok = await addFromBytes(
          name: name,
          sidecarJson: sidecar,
          pngBytes: bytes.buffer.asUint8List(
            bytes.offsetInBytes,
            bytes.lengthInBytes,
          ),
        );
        if (!ok) debugPrint('skipped unusable sprite $key');
      } catch (e) {
        debugPrint('sprite $key fell back to code-drawn figures: $e');
      }
    }
  }

  /// False when the sidecar or the image cannot be used. The image is
  /// disposed in that case; a previous strip under the same name is kept.
  Future<bool> addFromBytes({
    required SpriteName name,
    required String sidecarJson,
    required Uint8List pngBytes,
  }) async {
    final SpriteStripSpec spec;
    try {
      spec = SpriteStripSpec.fromJson(jsonDecode(sidecarJson));
    } catch (_) {
      return false;
    }
    final ui.Image image;
    try {
      final codec = await ui.instantiateImageCodec(pngBytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      image = frame.image;
    } catch (_) {
      return false;
    }
    return addImage(name: name, spec: spec, image: image);
  }

  bool addImage({
    required SpriteName name,
    required SpriteStripSpec spec,
    required ui.Image image,
  }) {
    try {
      spec.validate();
      spec.validateImage(image.width, image.height);
    } catch (_) {
      image.dispose();
      return false;
    }
    _strips.remove(name.stem)?.dispose();
    _strips[name.stem] = SpriteStrip(name: name, spec: spec, image: image);
    return true;
  }

  void dispose() {
    for (final strip in _strips.values) {
      strip.dispose();
    }
    _strips.clear();
  }
}

/// A decoded strip, drawn with nearest-neighbour filtering.
class SpriteStrip {
  SpriteStrip({required this.name, required this.spec, required this.image});

  final SpriteName name;
  final SpriteStripSpec spec;
  final ui.Image image;

  /// [cellWorldHeight] is the cell, not the 48px body. Field figures pass
  /// the steady drawn height times 64/48 so the body lands on 48pt.
  void draw(
    ui.Canvas canvas, {
    required ui.Offset ground,
    required double cellWorldHeight,
    required double phase,
    required double devicePixelRatio,
  }) {
    final space = PixelSnap.fromCanvas(canvas, devicePixelRatio);
    final placement = SpritePlacement.compute(
      spec: spec,
      frame: spec.frameAt(phase),
      ground: ground,
      cellWorldHeight: cellWorldHeight,
      space: space,
    );
    canvas.drawImageRect(
      image,
      placement.source,
      placement.destination,
      placement.paint,
    );
  }

  void dispose() => image.dispose();
}
