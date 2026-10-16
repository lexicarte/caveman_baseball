// Animation workbench. A second entry point, not a second app.
//
//   flutter run -t lib/main_anim.dart
//
// It imports the real renderer, so what you see here is what the game draws —
// there is no export step and nothing to keep in sync. Hot reload works, so
// the loop is: change a curve in caveman.dart, save, watch it.
//
// What it is for, in order of how much it matters:
//   1. The in-game size row. Everything looks fine at 180px; the only
//      question that decides an art direction is whether it reads at 48.
//   2. TRAVEL on a run. A run cycle driven by a timer always skates. Driven
//      by distance it cannot, and this shows the difference side by side.
//   3. The filmstrip, which is how you actually judge a cycle — a single
//      moving figure hides dead frames and a lopsided arc.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'game/art/art_style.dart';
import 'game/components/caveman.dart';
import 'game/components/caveman_cartoon.dart';
import 'game/components/caveman_pixel.dart';
import 'game/look.dart';
import 'model/player.dart';

void main() => runApp(const AnimWorkbenchApp());

/// Paces per second a man covers on the bases, from BaseRunning.
const double _basePaces = 13.0;
const double _secondsPerBase = 2.58;

/// Pixels per pace on the portrait board. Matches the design canvases.
const double _pxPerPace = 6.3;

/// Height argument that draws a steady man at the at-bat size. The painter
/// multiplies by [CavemanPainter.steadyDrawnFactor], so this is 48px divided
/// back out — what the field actually shows.
const double _inGameHeight =
    LookDefaults.fieldFigurePoints / CavemanPainter.steadyDrawnFactor;

String get _inGameLabel =>
    'in-game ${LookDefaults.fieldFigurePoints.round()}px';

class AnimWorkbenchApp extends StatelessWidget {
  const AnimWorkbenchApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Caveman animation workbench',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true)
        .copyWith(scaffoldBackgroundColor: const Color(0xFF14110D)),
    home: const _Workbench(),
  );
}

class _Workbench extends StatefulWidget {
  const _Workbench();

  @override
  State<_Workbench> createState() => _WorkbenchState();
}

class _WorkbenchState extends State<_Workbench>
    with SingleTickerProviderStateMixin {
  // Built in initState, not lazily: a `late final` ticker is first created
  // whenever it is first touched, and if that happens to be dispose() the
  // element is already deactivated and createTicker throws.
  Ticker? _ticker;
  Duration _last = Duration.zero;

  Act _act = Act.run;
  double _clock = 0; // seconds, free-running
  double _scrub = 0; // 0..1 when paused
  bool _playing = true;
  double _speed = 1.0;
  double _height = 150;
  bool _onion = false;
  bool _travel = true;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (!_playing || dt <= 0 || dt > 0.5) return;
    setState(() => _clock += dt * _speed);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  double _cycleFor(Archetype a) => switch (_act) {
    Act.swing => CavemanPainter.swingSeconds,
    Act.throwing => CavemanPainter.throwSeconds,
    Act.run => CavemanPainter.runCycleSecondsFor(
      a,
      _height,
      pxPerUnit: _pxPerPace * (_height / _inGameHeight),
    ),
    Act.still => 1.0,
  };

  double _phaseFor(Archetype a) {
    if (!_playing) return _scrub;
    final c = _cycleFor(a);
    return c <= 0 ? 0 : (_clock % c) / c;
  }

  Pose _pose(double t) => switch (_act) {
    Act.still => const Pose.still(),
    Act.swing => Pose.swing(t.clamp(0.0, 1.0)),
    Act.run => Pose.run(t),
    Act.throwing => Pose.throwing(t.clamp(0.0, 1.0)),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            Expanded(
              flex: 5,
              child: _panel(
                'STAGE',
                CustomPaint(
                  painter: _StagePainter(
                    act: _act,
                    height: _height,
                    phase: _phaseFor,
                    pose: _pose,
                    onion: _onion,
                    travel: _travel && _act == Act.run,
                    clock: _clock,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: _panel(
                'AT IN-GAME SIZE — ${LookDefaults.fieldFigurePoints.round()}px, '
                'what the field actually shows',
                CustomPaint(
                  painter: _StagePainter(
                    act: _act,
                    height: _inGameHeight,
                    phase: _phaseFor,
                    pose: _pose,
                    onion: false,
                    travel: _travel && _act == Act.run,
                    clock: _clock,
                    zoom: 3,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: _panel(
                'FILMSTRIP — eight frames across one cycle',
                CustomPaint(
                  painter: _StripPainter(
                    height: _height,
                    pose: _pose,
                    act: _act,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            _controls(),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
    child: Row(
      children: [
        const Flexible(
          child: Text(
            'CAVEMAN WORKBENCH',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontSize: 13,
              color: Color(0xFFE8DCC0),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            _readout(),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: _mono,
          ),
        ),
      ],
    ),
  );

  static const _mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11.5,
    color: Color(0xFF9A9085),
  );

  String _readout() {
    if (_act != Act.run) {
      final c = _cycleFor(Archetype.steady);
      return '${_act.name}  ${(c * 1000).round()}ms';
    }
    final parts = <String>[];
    for (final a in Archetype.values) {
      parts.add(
        '${a.name.substring(0, 2)} '
        '${(_cycleFor(a) * 1000).round()}ms',
      );
    }
    return 'slip-free cycle:  ${parts.join('   ')}';
  }

  Widget _panel(String label, Widget child) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 3, left: 2),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1.5,
              color: Color(0xFF6B6459),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF1B2419),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: child,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _controls() => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
    color: const Color(0xFF1A1510),
    child: Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final a in Act.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(a.name),
                    selected: _act == a,
                    onSelected: (_) => setState(() {
                      _act = a;
                      _clock = 0;
                    }),
                  ),
                ),
              const SizedBox(width: 10),
              ValueListenableBuilder<ArtStyle>(
                valueListenable: artStyle,
                builder: (context, style, _) => OutlinedButton(
                  onPressed: () => setState(() => artStyle.value = style.next),
                  child: Text(style.label),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: _playing ? 'Pause' : 'Play',
                onPressed: () => setState(() => _playing = !_playing),
                icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
              ),
              SizedBox(
                width: 180,
                child: Slider(
                  value: _scrub,
                  onChanged: (v) => setState(() {
                    _scrub = v;
                    _playing = false;
                  }),
                ),
              ),
              Text('t ${_scrub.toStringAsFixed(2)}', style: _mono),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                width: 170,
                child: _slider('size', _height, 18, 220, (v) => _height = v),
              ),
              SizedBox(
                width: 170,
                child: _slider('speed', _speed, 0.1, 2.0, (v) => _speed = v),
              ),
              TextButton(
                onPressed: () => setState(() => _height = _inGameHeight),
                child: Text(_inGameLabel),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _onion,
                    onChanged: (v) => setState(() => _onion = v ?? false),
                  ),
                  const Text('onion', style: _mono),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _travel,
                    onChanged: (v) => setState(() => _travel = v ?? false),
                  ),
                  const Text('travel', style: _mono),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    void Function(double) set,
  ) => Row(
    children: [
      SizedBox(width: 42, child: Text(label, style: _mono)),
      Expanded(
        child: Slider(
          value: value,
          min: min,
          max: max,
          onChanged: (v) => setState(() => set(v)),
        ),
      ),
    ],
  );
}

/// Three archetypes on a ground line.
class _StagePainter extends CustomPainter {
  _StagePainter({
    required this.act,
    required this.height,
    required this.phase,
    required this.pose,
    required this.onion,
    required this.travel,
    required this.clock,
    this.zoom = 1,
  });

  final Act act;
  final double height;
  final double Function(Archetype) phase;
  final Pose Function(double) pose;
  final bool onion;
  final bool travel;
  final double clock;
  final double zoom;

  static const _pixel = PixelCavemanPainter();
  static const _cartoon = CartoonCavemanPainter();

  void _draw(
    Canvas canvas, {
    required Offset ground,
    required Archetype archetype,
    required double height,
    required Pose pose,
    required bool club,
    Color? tint,
  }) {
    if (artStyle.value == ArtStyle.cartoon) {
      _cartoon.paint(
        canvas,
        ground: ground,
        archetype: archetype,
        height: height,
        tint: tint,
        holdingClub: club,
        detailed: height > 48,
        pose: pose,
      );
    } else {
      _pixel.paint(
        canvas,
        ground: ground,
        archetype: archetype,
        height: height,
        tint: tint,
        holdingClub: club,
        detailed: height > 48,
        pose: pose,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final h = height * zoom;
    final groundY = size.height * 0.82;
    canvas.drawRect(
      Rect.fromLTRB(0, groundY, size.width, size.height),
      Paint()..color = const Color(0xFF2E3B22),
    );

    final lane = size.width / Archetype.values.length;
    for (var i = 0; i < Archetype.values.length; i++) {
      final a = Archetype.values[i];
      var x = lane * (i + 0.5);
      var t = phase(a);

      if (travel) {
        // Drive the cycle from DISTANCE, not from a timer. Do that and foot
        // slip is arithmetically impossible; drive it from a timer and it is
        // only ever approximately right.
        final speedPx =
            (_basePaces / _secondsPerBase) *
            Player(id: '_', name: '_', archetype: a).speedScale *
            _pxPerPace *
            (h / _inGameHeight);
        final stride = CavemanPainter.strideFor(a, h);
        final travelled = clock * speedPx;
        t = stride <= 0 ? 0 : (travelled % stride) / stride;
        x = (travelled % (lane * 0.8)) + lane * i + lane * 0.1;
      }

      if (onion) {
        for (final d in [-0.12, 0.12]) {
          _draw(
            canvas,
            ground: Offset(x, groundY),
            archetype: a,
            height: h,
            tint: const Color(0x33FFFFFF),
            club: act == Act.swing,
            pose: pose((t + d) % 1.0),
          );
        }
      }

      _draw(
        canvas,
        ground: Offset(x, groundY),
        archetype: a,
        height: h,
        club: act == Act.swing,
        pose: pose(t),
      );

      final tp = TextPainter(
        text: TextSpan(
          text: a.name,
          style: const TextStyle(fontSize: 10, color: Color(0xFF8A9A72)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lane * (i + 0.5) - tp.width / 2, groundY + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _StagePainter old) => true;
}

/// Eight frames of one cycle, laid out left to right. A moving figure hides
/// a dead frame or a lopsided arc; a strip does not.
class _StripPainter extends CustomPainter {
  _StripPainter({required this.height, required this.pose, required this.act});

  final double height;
  final Pose Function(double) pose;
  final Act act;

  static const _pixel = PixelCavemanPainter();
  static const _cartoon = CartoonCavemanPainter();
  static const _frames = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final groundY = size.height * 0.86;
    final cell = size.width / _frames;
    final h = math.min(height, size.height * 0.74);

    for (var i = 0; i < _frames; i++) {
      if (i.isOdd) {
        canvas.drawRect(
          Rect.fromLTWH(cell * i, 0, cell, size.height),
          Paint()..color = const Color(0x11FFFFFF),
        );
      }
      final args = (
        ground: Offset(cell * (i + 0.5), groundY),
        pose: pose(i / _frames),
      );
      if (artStyle.value == ArtStyle.cartoon) {
        _cartoon.paint(
          canvas,
          ground: args.ground,
          archetype: Archetype.steady,
          height: h,
          holdingClub: act == Act.swing,
          detailed: h > 48,
          pose: args.pose,
        );
      } else {
        _pixel.paint(
          canvas,
          ground: args.ground,
          archetype: Archetype.steady,
          height: h,
          holdingClub: act == Act.swing,
          detailed: h > 48,
          pose: args.pose,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StripPainter old) => true;
}
