import 'dart:ui';

/// Device-pixel placement for pixel art.
///
/// The camera applies a uniform scale and a translation. Sprites are never
/// rotated. The canvas works in logical pixels; device pixels are those
/// times [devicePixelRatio]. Snapping in device space is what keeps a 2×
/// or 3× phone from splitting an art pixel across a pixel boundary.
class PixelSnap {
  const PixelSnap({
    required this.scaleX,
    required this.scaleY,
    required this.tx,
    required this.ty,
    required this.devicePixelRatio,
  });

  /// One world unit is one logical pixel, origin unmoved.
  const PixelSnap.identity({this.devicePixelRatio = 1})
    : scaleX = 1,
      scaleY = 1,
      tx = 0,
      ty = 0;

  final double scaleX;
  final double scaleY;
  final double tx;
  final double ty;
  final double devicePixelRatio;

  /// Null when the canvas is rotated or skewed. Callers then draw without
  /// snapping rather than guessing a transform.
  static PixelSnap? fromCanvas(Canvas canvas, double devicePixelRatio) {
    if (devicePixelRatio <= 0 || !devicePixelRatio.isFinite) return null;
    final m = canvas.getTransform();
    final sx = m[0];
    final sy = m[5];
    if (sx.abs() < 1e-9 || sy.abs() < 1e-9) return null;
    if (m[1].abs() > 1e-3 || m[4].abs() > 1e-3) return null;
    return PixelSnap(
      scaleX: sx,
      scaleY: sy,
      tx: m[12],
      ty: m[13],
      devicePixelRatio: devicePixelRatio,
    );
  }

  Offset worldToDevice(Offset world) => Offset(
    (scaleX * world.dx + tx) * devicePixelRatio,
    (scaleY * world.dy + ty) * devicePixelRatio,
  );

  Offset deviceToWorld(Offset device) => Offset(
    (device.dx / devicePixelRatio - tx) / scaleX,
    (device.dy / devicePixelRatio - ty) / scaleY,
  );

  Offset snapWorld(Offset world) {
    final d = worldToDevice(world);
    return deviceToWorld(Offset(d.dx.roundToDouble(), d.dy.roundToDouble()));
  }
}
