import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'pixel_snap.dart';

/// One horizontal strip: `frames` cells of [cellW]×[cellH], feet on the pivot.
///
/// Sidecar JSON, next to the PNG:
///
/// ```json
/// { "cell": [64, 64], "frames": 6, "durationsMs": [70, 70, 70, 70, 70, 70],
///   "pivot": [32, 63], "key": 5 }
/// ```
///
/// [key] is the 1-based frame number from the checklist (`f05` is 5). Idle
/// sheets omit it. Omitted [cell] is 64×64 and an omitted pivot sits in the
/// middle of the last row, which is (32, 63) for that cell. Frame 5 of six
/// equal frames therefore starts at 4/6 of the strip.
class SpriteStripSpec {
  const SpriteStripSpec({
    required this.cellW,
    required this.cellH,
    required this.frames,
    required this.durationsMs,
    required this.pivotX,
    required this.pivotY,
    this.key,
  });

  /// Body height of a FIELD caveman inside the 64×64 cell, in art pixels.
  static const int figureArtPixels = 48;

  final int cellW;
  final int cellH;
  final int frames;
  final List<int> durationsMs;
  final int pivotX;
  final int pivotY;

  /// 1-based. Null when the strip has no contact or release frame.
  final int? key;

  int get totalMs => durationsMs.fold<int>(0, (a, b) => a + b);

  /// 0-based index of [key], or null.
  int? get keyIndex => key == null ? null : key! - 1;

  /// Where [key] starts, as a fraction of the strip. Null when there is none.
  double? get keyPhase {
    final index = keyIndex;
    if (index == null) return null;
    var acc = 0;
    for (var i = 0; i < index; i++) {
      acc += durationsMs[i];
    }
    final total = totalMs;
    return total == 0 ? 0 : acc / total;
  }

  factory SpriteStripSpec.fromJson(Object? raw) {
    if (raw is String) {
      return SpriteStripSpec.fromJson(jsonDecode(raw));
    }
    if (raw is! Map) {
      throw const FormatException('sprite sidecar must be a JSON object');
    }
    final json = raw.cast<Object?, Object?>();
    final cell = _pair(json['cell'], 'cell') ?? const (64, 64);
    final pivot = _pair(json['pivot'], 'pivot') ?? (cell.$1 ~/ 2, cell.$2 - 1);
    final frames = _int(json['frames'], 'frames');
    final durations = _ints(json['durationsMs'], 'durationsMs');
    final key = json.containsKey('key') && json['key'] != null
        ? _int(json['key'], 'key')
        : null;
    final spec = SpriteStripSpec(
      cellW: cell.$1,
      cellH: cell.$2,
      frames: frames,
      durationsMs: durations,
      pivotX: pivot.$1,
      pivotY: pivot.$2,
      key: key,
    );
    spec.validate();
    return spec;
  }

  void validate() {
    if (cellW <= 0 || cellH <= 0) {
      throw const FormatException('cell must be positive');
    }
    if (frames < 1) {
      throw const FormatException('frames must be at least 1');
    }
    if (durationsMs.length != frames) {
      throw FormatException(
        'durationsMs has ${durationsMs.length} entries for $frames frames',
      );
    }
    if (durationsMs.any((d) => d <= 0)) {
      throw const FormatException('durationsMs must be positive');
    }
    if (pivotX < 0 || pivotX > cellW || pivotY < 0 || pivotY > cellH) {
      throw FormatException('pivot ($pivotX, $pivotY) is outside the cell');
    }
    if (key != null && (key! < 1 || key! > frames)) {
      throw FormatException('key frame $key is outside 1..$frames');
    }
  }

  void validateImage(int width, int height) {
    if (height != cellH || width != cellW * frames) {
      throw FormatException(
        'strip is ${width}x$height, expected ${cellW * frames}x$cellH',
      );
    }
  }

  /// Frame whose duration window contains [t] in 0..1.
  ///
  /// A frame starts at its boundary, so six equal frames put frame 5 (index
  /// 4) on screen at t = 4/6. t = 1 stays on the last frame.
  int frameAt(double t) {
    if (frames <= 1) return 0;
    if (t.isNaN) return 0;
    final u = t.clamp(0.0, 1.0);
    final total = totalMs;
    if (total <= 0) return 0;
    if (u >= 1) return frames - 1;
    final target = u * total;
    var acc = 0;
    for (var i = 0; i < frames; i++) {
      acc += durationsMs[i];
      if (target < acc) return i;
    }
    return frames - 1;
  }

  /// Loops [seconds] through the strip. Used for idle, which the game does
  /// not drive with a pose phase.
  double loopPhase(double seconds) {
    final total = totalMs;
    if (total <= 0) return 0;
    final ms = seconds * 1000;
    final wrapped = ms % total;
    final m = wrapped < 0 ? wrapped + total : wrapped;
    return m / total;
  }
}

/// Where one frame lands, in the same space as the ground point.
class SpritePlacement {
  const SpritePlacement({
    required this.source,
    required this.destination,
    required this.paint,
    required this.anchor,
  });

  final Rect source;
  final Rect destination;
  final Paint paint;

  /// The pivot, in world space, after snapping to a device pixel.
  final Offset anchor;

  static SpritePlacement compute({
    required SpriteStripSpec spec,
    required int frame,
    required Offset ground,
    required double cellWorldHeight,
    PixelSnap? space,
  }) {
    final index = frame.clamp(0, math.max(0, spec.frames - 1));
    final source = Rect.fromLTWH(
      index * spec.cellW.toDouble(),
      0,
      spec.cellW.toDouble(),
      spec.cellH.toDouble(),
    );
    final paint = Paint()..filterQuality = FilterQuality.none;
    final cellH = cellWorldHeight <= 0 ? 0.0 : cellWorldHeight;
    final cellW = spec.cellH == 0 ? cellH : cellH * spec.cellW / spec.cellH;

    if (space == null || cellH <= 0) {
      return SpritePlacement(
        source: source,
        destination: Rect.fromLTWH(
          ground.dx - spec.pivotX / spec.cellW * cellW,
          ground.dy - spec.pivotY / spec.cellH * cellH,
          cellW,
          cellH,
        ),
        paint: paint,
        anchor: ground,
      );
    }

    final desiredArt =
        cellH * space.scaleY * space.devicePixelRatio / spec.cellH;
    final cellDeviceH = _cellDevicePixels(desiredArt, spec.cellH);
    final cellDeviceW = _cellDevicePixels(
      desiredArt * spec.cellW / spec.cellH,
      spec.cellW,
    );
    final pivotDeviceX = (spec.pivotX * cellDeviceW / spec.cellW).round();
    final pivotDeviceY = (spec.pivotY * cellDeviceH / spec.cellH).round();
    final groundDevice = space.worldToDevice(ground);
    final gx = groundDevice.dx.round();
    final gy = groundDevice.dy.round();
    final left = gx - pivotDeviceX;
    final top = gy - pivotDeviceY;
    final origin = space.deviceToWorld(Offset(left.toDouble(), top.toDouble()));
    final far = space.deviceToWorld(
      Offset((left + cellDeviceW).toDouble(), (top + cellDeviceH).toDouble()),
    );
    return SpritePlacement(
      source: source,
      destination: Rect.fromLTRB(origin.dx, origin.dy, far.dx, far.dy),
      paint: paint,
      anchor: space.deviceToWorld(Offset(gx.toDouble(), gy.toDouble())),
    );
  }
}

/// Device pixels across one cell.
///
/// Near an integer art-pixel scale (1×, 2×, 3×) the cell locks to that
/// multiple so every art pixel is the same block. Further away — a fielder
/// shrunk by perspective — the cell is still a whole number of device
/// pixels, and the pivot is rounded onto one. Forcing every distance onto
/// a 1× minimum would draw the outfield the same size as the batter.
int _cellDevicePixels(double desiredArt, int cellPixels) {
  if (!desiredArt.isFinite || desiredArt <= 0 || cellPixels <= 0) return 1;
  final nearest = desiredArt.round();
  if (nearest >= 1 && (desiredArt - nearest).abs() <= 0.08) {
    return nearest * cellPixels;
  }
  return math.max(1, (desiredArt * cellPixels).round());
}

(int, int)? _pair(Object? raw, String name) {
  if (raw == null) return null;
  if (raw is! List || raw.length != 2) {
    throw FormatException('$name must be a pair of integers');
  }
  return (_int(raw[0], name), _int(raw[1], name));
}

int _int(Object? raw, String name) {
  if (raw is int) return raw;
  if (raw is num && raw == raw.roundToDouble()) return raw.round();
  throw FormatException('$name must be an integer');
}

List<int> _ints(Object? raw, String name) {
  if (raw is! List || raw.isEmpty) {
    throw FormatException('$name must be a non-empty list');
  }
  return [for (var i = 0; i < raw.length; i++) _int(raw[i], '$name[$i]')];
}
