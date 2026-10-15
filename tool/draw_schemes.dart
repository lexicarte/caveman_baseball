// ignore_for_file: avoid_print
//
// Draws the five defensive schemes as an SVG, straight from the real Scheme
// data — so the picture cannot drift from what the simulation actually uses.
//
//   dart run tool/draw_schemes.dart > schemes.svg
import 'dart:math' as math;

import 'package:caveman_baseball/sim/field_spec.dart';
import 'package:caveman_baseball/sim/fielder_spec.dart';

const field = FieldSpec.compact;

const scale = 7.0;
const padX = 26.0;
const padTop = 18.0;
const labelBlock = 56.0;

final double fieldHalfW =
    field.wallRadius * math.sin(field.foulAngleRadians) * scale;
final double panelW = fieldHalfW * 2 + padX * 2;
final double panelH = field.wallRadius * scale + padTop + labelBlock;

double sx(double x) => panelW / 2 + x * scale;
double sy(double y) => panelH - labelBlock - y * scale;

String arcPath(double radius, double sweepAngle) {
  final r = radius * scale;
  final hx = sx(0), hy = sy(0);
  final lx = hx - math.sin(sweepAngle) * r, ly = hy - math.cos(sweepAngle) * r;
  final rx = hx + math.sin(sweepAngle) * r, ry = hy - math.cos(sweepAngle) * r;
  return 'M $lx $ly A $r $r 0 0 1 $rx $ry';
}

String panel(Scheme s, int col, int row) {
  final b = StringBuffer();
  final ox = col * (panelW + 22);
  final oy = row * (panelH + 26);
  b.writeln('<g transform="translate($ox,$oy)">');

  final a = field.foulAngleRadians;
  final r = field.wallRadius * scale;
  final hx = sx(0), hy = sy(0);
  final lx = hx - math.sin(a) * r, ly = hy - math.cos(a) * r;
  final rx = hx + math.sin(a) * r, ry = hy - math.cos(a) * r;
  b.writeln(
    '<path d="M $hx $hy L $lx $ly A $r $r 0 0 1 $rx $ry Z" '
    'fill="#4E7A3A" stroke="#6B4A2F" stroke-width="3"/>',
  );

  // Depth rings every 15 paces, so how deep a scheme sits is unmistakable.
  for (final d in [15.0, 30.0]) {
    b.writeln(
      '<path d="${arcPath(d, a)}" fill="none" stroke="#FFFFFF" '
      'stroke-opacity="0.22" stroke-width="1.5" stroke-dasharray="7 7"/>',
    );
    final ty = sy(d) + 4;
    b.writeln(
      '<text x="${sx(0) + 6}" y="$ty" font-family="monospace" '
      'font-size="11" fill="#FFFFFF" fill-opacity="0.45">'
      '${d.round()}</text>',
    );
  }

  final bd = field.baseDistance;
  for (final p in [
    [bd * 0.707, bd * 0.707],
    [0.0, bd],
    [-bd * 0.707, bd * 0.707],
    [0.0, 0.0],
  ]) {
    final x = sx(p[0]) - 4.5, y = sy(p[1]) - 4.5;
    b.writeln('<rect x="$x" y="$y" width="9" height="9" fill="#E8E2D0"/>');
  }

  for (final f in s.fielders) {
    final p = f.position;
    final cx = sx(p.x), cy = sy(p.y);
    b.writeln(
      '<circle cx="$cx" cy="$cy" r="${f.range * scale}" '
      'fill="#FFFFFF" fill-opacity="0.20" stroke="#FFFFFF" '
      'stroke-opacity="0.30" stroke-width="1"/>',
    );
    b.writeln(
      '<circle cx="$cx" cy="${cy + 2}" r="9" fill="#000000" '
      'fill-opacity="0.28"/>',
    );
    b.writeln('<circle cx="$cx" cy="$cy" r="9" fill="#2E2A26"/>');
    b.writeln('<circle cx="$cx" cy="${cy - 3}" r="4.4" fill="#C9A227"/>');
  }

  final ly2 = panelH - 22;
  b.writeln(
    '<text x="${panelW / 2}" y="$ly2" text-anchor="middle" '
    'font-family="monospace" font-size="26" font-weight="700" '
    'fill="#1d1f21" letter-spacing="2">${s.name}</text>',
  );
  b.writeln(
    '<text x="${panelW / 2}" y="${ly2 + 20}" text-anchor="middle" '
    'font-family="sans-serif" font-size="14" fill="#5a5f63">'
    'gives up ${s.givesUp}</text>',
  );
  b.writeln('</g>');
  return b.toString();
}

void main() {
  const cols = 2;
  final n = Schemes.all.length;
  final rows = (n / cols).ceil();
  final w = cols * panelW + (cols - 1) * 22;
  final h = rows * panelH + (rows - 1) * 26;

  final b = StringBuffer();
  b.writeln(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $w $h" '
    'width="$w" height="$h">',
  );
  b.writeln('<rect width="$w" height="$h" fill="#EDEEEB"/>');
  for (var i = 0; i < n; i++) {
    b.write(panel(Schemes.all[i], i % cols, i ~/ cols));
  }
  b.writeln('</svg>');
  print(b.toString());
}
