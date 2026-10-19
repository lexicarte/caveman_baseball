// Swing timing, on the simulator, against a real pitch.
//
// A rock is thrown over and over. You tap when you would tap in a match,
// and the tap is scored by the same clock the match uses. Every dial writes
// [SwingTiming.now] as it moves, so the next frame — and the match underneath
// this screen — already has the new number. Save is what makes it survive
// the next launch. Reset puts the shipped swing back.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../bench/chrome.dart';
import '../bench/stage.dart';
import '../data/clubs.dart';
import '../data/rocks.dart';
import '../model/rock.dart';
import '../sim/fielder_spec.dart';
import 'caveman_baseball_game.dart';
import 'swing_preset.dart';
import 'swing_timing.dart';

/// Debug builds, and any build compiled with `--dart-define=DEV=true`.
const bool swingLabAvailable = kDebugMode || bool.fromEnvironment('DEV');

/// The rule the button uses, split out so a test can try release and dev
/// without rebuilding the whole app.
bool showSwingLab({required bool debug, required bool dev}) => debug || dev;

Future<void> openSwingLab(
  BuildContext context,
  CavemanBaseballGame game,
) async {
  game.pauseEngine();
  try {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SwingCalibrationScreen()),
    );
  } finally {
    game.resumeEngine();
  }
}

class SwingCalibrationScreen extends StatefulWidget {
  const SwingCalibrationScreen({super.key});

  @override
  State<SwingCalibrationScreen> createState() => _SwingCalibrationScreenState();
}

enum _Beat { gap, windUp, flight }

class _SwingCalibrationScreenState extends State<SwingCalibrationScreen>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  Duration _last = Duration.zero;

  // Wind-up first, so the opening pitch is not held for a gap.
  // The gap is the pause between pitches after that.
  _Beat beat = _Beat.windUp;
  double elapsed = 0;
  double? tappedAt;
  bool resolved = false;

  /// Which rock is coming in, and which rock the pitch-speed dial edits.
  String rockId = Rocks.plain.id;
  bool slow = false;

  SwingJudgement? last;
  bool took = false;
  int swings = 0;
  int hits = 0;
  String note = '';

  /// The mound the match starts the thrower on. Every scheme shares it.
  double get mound => Schemes.wheel.thrower.depth;

  Rock get rock =>
      Rocks.all.firstWhere((r) => r.id == rockId, orElse: () => Rocks.plain);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _tick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (!mounted || dt <= 0 || dt > 0.5) return;
    final step = dt > 0.05 ? 0.05 : dt;
    final timing = SwingTiming.now;
    setState(() {
      elapsed += step;
      if (beat == _Beat.gap) {
        if (elapsed >= timing.pitchGap) _beginWindUp();
      } else if (beat == _Beat.windUp) {
        if (elapsed >= timing.windUpSeconds) _beginFlight();
      } else {
        _maybeTake(timing);
        if (_flightFinished(timing)) {
          // A rock that arrives with no tap is a take, same as the match,
          // even when the window has been opened past the plate.
          if (!resolved) {
            took = true;
            last = null;
          }
          _beginGap();
        }
      }
    });
  }

  void _beginWindUp() {
    beat = _Beat.windUp;
    elapsed = 0;
    tappedAt = null;
    resolved = false;
  }

  void _beginFlight() {
    beat = _Beat.flight;
    elapsed = 0;
    tappedAt = null;
    resolved = false;
  }

  void _beginGap() {
    beat = _Beat.gap;
    elapsed = 0;
  }

  void _maybeTake(SwingTiming timing) {
    if (resolved || tappedAt != null) return;
    final flight = timing.flightFor(rockId, slow: slow);
    final deadline = timing.perfectTap(flight, mound) + timing.window;
    if (elapsed > deadline) {
      resolved = true;
      took = true;
      last = null;
    }
  }

  bool _flightFinished(SwingTiming timing) {
    final flight = timing.flightFor(rockId, slow: slow);
    if (elapsed < flight) return false;
    if (tappedAt == null) return true;
    return elapsed >= tappedAt! + timing.swingPlaySeconds;
  }

  void _swing() {
    if (beat != _Beat.flight || tappedAt != null) return;
    final timing = SwingTiming.now;
    final flight = timing.flightFor(rockId, slow: slow);
    final contact = timing.contactInstant(flight, mound);
    final judgement = timing.judge(
      tapAt: elapsed,
      contactTime: contact,
      club: Clubs.stik,
      rock: rock,
      windowScale: slow ? timing.slowWindowScale : 1,
    );
    setState(() {
      tappedAt = elapsed;
      resolved = true;
      took = false;
      last = judgement;
      swings += 1;
      if (judgement.hit) hits += 1;
    });
  }

  double? get _swingPhase {
    final at = tappedAt;
    if (at == null || beat != _Beat.flight) return null;
    final length = SwingTiming.now.swingPlaySeconds;
    if (length <= 0) return null;
    final t = (elapsed - at) / length;
    if (t < 0 || t >= 1) return null;
    return t;
  }

  double _depth(SwingTiming timing) {
    if (beat != _Beat.flight) return mound;
    final flight = timing.flightFor(rockId, slow: slow);
    if (flight <= 0) return 0;
    return mound * (1 - (elapsed / flight).clamp(0.0, 1.0));
  }

  void _apply(SwingTiming next) => setState(() => SwingTiming.now = next);

  Future<void> _reset() async {
    await clearSwingPreset();
    if (!mounted) return;
    setState(() {
      swings = 0;
      hits = 0;
      last = null;
      took = false;
      note = 'shipped swing';
    });
  }

  Future<void> _save() async {
    try {
      await saveSwingPreset();
      if (!mounted) return;
      setState(() => note = 'saved');
    } catch (_) {
      if (!mounted) return;
      setState(() => note = 'save failed');
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: SwingTiming.now.toJson()));
    if (!mounted) return;
    setState(() => note = 'copied');
  }

  @override
  Widget build(BuildContext context) {
    final timing = SwingTiming.now;
    final depth = _depth(timing);
    final camZoom = CavemanBaseballGame.tightZoom;
    final camLook = CavemanBaseballGame.tightLook;
    return Theme(
      data: ThemeData.dark(
        useMaterial3: true,
      ).copyWith(scaffoldBackgroundColor: benchBg),
      child: Scaffold(
        backgroundColor: benchBg,
        appBar: AppBar(
          backgroundColor: benchBg,
          foregroundColor: benchInk,
          title: const Text(
            'Swing timing',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(flex: 5, child: _stage(timing, depth, camZoom, camLook)),
              _feedback(timing),
              _rocks(),
              Expanded(flex: 6, child: _dials(timing)),
              _actions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stage(SwingTiming timing, double depth, double zoom, double look) {
    return GestureDetector(
      key: const Key('swing-lab-stage'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _swing(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: StagePainter(
              zoom: zoom,
              look: look,
              cropToBand: false,
              curve: timing.curve,
              figures: [
                StageFigure(
                  x: CavemanBaseballGame.throwerRenderOffsetX,
                  y: mound,
                ),
                batterFigure(swingPhase: _swingPhase),
              ],
              rock: StageRock(
                x: 0,
                y: depth,
                lift: CavemanBaseballGame.rockLift(depth, mound),
                rock: rock,
              ),
            ),
            child: const SizedBox.expand(),
          ),
          Positioned(
            left: 12,
            bottom: 8,
            child: Text(_prompt, style: benchMono.copyWith(color: benchInk)),
          ),
        ],
      ),
    );
  }

  String get _prompt => switch (beat) {
    _Beat.gap => 'NEXT PITCH',
    _Beat.windUp => 'WIND UP',
    _Beat.flight => tappedAt == null ? 'TAP TO SWING' : 'SWUNG',
  };

  Widget _feedback(SwingTiming timing) {
    final flight = timing.flightFor(rockId, slow: slow);
    final perfect = timing.perfectTap(flight, mound);
    final meetMs = (timing.swingPlaySeconds * timing.whip * 1000).round();
    final line = took
        ? 'TOOK IT'
        : (last == null ? 'waiting for a swing' : last!.summary);
    final colour = took
        ? benchDim
        : (last == null ? benchDim : (last!.hit ? benchGood : benchBad));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line,
            key: const Key('swing-lab-feedback'),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: colour,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hitRateLabel(hits, swings),
            key: const Key('hit-rate'),
            style: benchMono,
          ),
          Text(
            '${rock.name}  ·  on time ${(perfect * 1000).round()}ms into the flight'
            '  ·  bat meets rock ${meetMs}ms after the tap',
            style: benchMono,
          ),
        ],
      ),
    );
  }

  Widget _rocks() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final r in Rocks.all)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(r.name, style: const TextStyle(fontSize: 10)),
                selected: r.id == rockId,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => rockId = r.id),
              ),
            ),
          ChoiceChip(
            label: const Text('SLOW', style: TextStyle(fontSize: 10)),
            selected: slow,
            visualDensity: VisualDensity.compact,
            onSelected: (_) => setState(() => slow = !slow),
          ),
        ],
      ),
    );
  }

  Widget _dials(SwingTiming timing) {
    final speed = timing.speedFor(rockId);
    final flightMs = (timing.flightFor(rockId, slow: slow) * 1000).round();
    return ListView(
      key: const Key('swing-dials'),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      children: [
        _slider(
          key: const Key('swing-duration'),
          label: 'swing duration',
          value: timing.swingSeconds,
          dial: SwingDials.swingSeconds,
          shipped: SwingTiming.shipped.swingSeconds,
          scale: 1000,
          decimals: 0,
          unit: 'ms',
          onChanged: (v) => _apply(timing.copyWith(swingSeconds: v)),
        ),
        _slider(
          key: const Key('swing-speed'),
          label: 'swing speed',
          value: timing.swingSpeed,
          dial: SwingDials.swingSpeed,
          shipped: SwingTiming.shipped.swingSpeed,
          unit: 'x',
          onChanged: (v) => _apply(timing.copyWith(swingSpeed: v)),
        ),
        _slider(
          key: const Key('window'),
          label: 'window',
          value: timing.window,
          dial: SwingDials.window,
          shipped: SwingTiming.shipped.window,
          scale: 1000,
          decimals: 0,
          unit: 'ms',
          onChanged: (v) => _apply(timing.copyWith(window: v)),
        ),
        _slider(
          key: const Key('window-offset'),
          label: 'window offset',
          value: timing.windowOffset,
          dial: SwingDials.windowOffset,
          shipped: SwingTiming.shipped.windowOffset,
          scale: 1000,
          decimals: 0,
          unit: 'ms',
          onChanged: (v) => _apply(timing.copyWith(windowOffset: v)),
        ),
        _slider(
          key: const Key('pitch-speed'),
          label: 'pitch speed',
          value: speed,
          dial: SwingDials.rockSpeed,
          shipped: 1,
          unit: 'x',
          onChanged: (v) => _apply(timing.withRockSpeed(rockId, v)),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '${rock.name} reaches the plate in ${flightMs}ms'
            '${slow ? ' (slow)' : ''}. 1x is the flight below.',
            style: benchMono.copyWith(fontSize: 9.5),
          ),
        ),
        _slider(
          key: const Key('pitch-flight'),
          label: 'pitch flight',
          value: timing.pitchFlightSeconds,
          dial: SwingDials.pitchFlight,
          shipped: SwingTiming.shipped.pitchFlightSeconds,
          unit: 's',
          onChanged: (v) => _apply(timing.copyWith(pitchFlightSeconds: v)),
        ),
        _slider(
          key: const Key('pitch-gap'),
          label: 'pitch gap',
          value: timing.pitchGap,
          dial: SwingDials.pitchGap,
          shipped: SwingTiming.shipped.pitchGap,
          scale: 1000,
          decimals: 0,
          unit: 'ms',
          onChanged: (v) => _apply(timing.copyWith(pitchGap: v)),
        ),
        _slider(
          key: const Key('sprite-contact'),
          label: 'sprite contact',
          value: timing.spriteContactFrame,
          dial: SwingDials.spriteContact,
          shipped: SwingTiming.shipped.spriteContactFrame,
          onChanged: (v) => _apply(timing.copyWith(spriteContactFrame: v)),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'When in the swing the sprite contact frame is on screen. '
            '${SwingTiming.spriteContactHome.toStringAsFixed(2)} leaves the '
            'strip as it shipped. The procedural bat still meets the rock '
            'at whip.',
            style: benchMono.copyWith(fontSize: 9.5),
          ),
        ),
        _slider(
          key: const Key('whip'),
          label: 'whip',
          value: timing.whip,
          dial: SwingDials.whip,
          shipped: SwingTiming.shipped.whip,
          onChanged: (v) => _apply(timing.copyWith(whip: v)),
        ),
        _slider(
          key: const Key('arc-contact'),
          label: 'arc contact',
          value: timing.contactAt,
          dial: SwingDials.contactAt,
          shipped: SwingTiming.shipped.contactAt,
          onChanged: (v) => _apply(timing.copyWith(contactAt: v)),
        ),
        _slider(
          key: const Key('approach'),
          label: 'approach',
          value: timing.approach,
          dial: SwingDials.approach,
          shipped: SwingTiming.shipped.approach,
          onChanged: (v) => _apply(timing.copyWith(approach: v)),
        ),
        _slider(
          key: const Key('follow'),
          label: 'follow',
          value: timing.follow,
          dial: SwingDials.follow,
          shipped: SwingTiming.shipped.follow,
          onChanged: (v) => _apply(timing.copyWith(follow: v)),
        ),
        _slider(
          key: const Key('wind-up'),
          label: 'wind-up',
          value: timing.windUpSeconds,
          dial: SwingDials.windUp,
          shipped: SwingTiming.shipped.windUpSeconds,
          scale: 1000,
          decimals: 0,
          unit: 'ms',
          onChanged: (v) => _apply(timing.copyWith(windUpSeconds: v)),
        ),
        _slider(
          key: const Key('slow-pitch'),
          label: 'slow pitch',
          value: timing.slowPitchScale,
          dial: SwingDials.slowPitch,
          shipped: SwingTiming.shipped.slowPitchScale,
          unit: 'x',
          onChanged: (v) => _apply(timing.copyWith(slowPitchScale: v)),
        ),
        _slider(
          key: const Key('slow-window'),
          label: 'slow window',
          value: timing.slowWindowScale,
          dial: SwingDials.slowWindow,
          shipped: SwingTiming.shipped.slowWindowScale,
          unit: 'x',
          onChanged: (v) => _apply(timing.copyWith(slowWindowScale: v)),
        ),
        _slider(
          key: const Key('contact-depth'),
          label: 'contact depth',
          value: timing.contactDepth,
          dial: SwingDials.contactDepth,
          shipped: SwingTiming.shipped.contactDepth,
          unit: ' paces',
          onChanged: (v) => _apply(timing.copyWith(contactDepth: v)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            'Live in this match as you drag. Save keeps the numbers for the '
            'next launch. Reset restores the shipped swing. The gap between '
            'pitches is only this screen.',
            style: benchMono.copyWith(fontSize: 9.5),
          ),
        ),
      ],
    );
  }

  Widget _slider({
    required Key key,
    required String label,
    required double value,
    required SwingDial dial,
    required double shipped,
    required ValueChanged<double> onChanged,
    String unit = '',
    double scale = 1,
    int decimals = 2,
  }) {
    return BenchSlider(
      key: key,
      label: label,
      value: value,
      min: dial.min,
      max: dial.max,
      shipped: shipped,
      unit: unit,
      scale: scale,
      decimals: decimals,
      onChanged: onChanged,
    );
  }

  Widget _actions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(note, style: benchMono.copyWith(color: benchAccent)),
            ),
          Row(
            children: [
              benchButton(
                'RESET',
                benchDim,
                false,
                () => _reset(),
                expand: true,
              ),
              const SizedBox(width: 6),
              benchButton(
                'SAVE',
                benchAccent,
                false,
                () => _save(),
                expand: true,
              ),
              const SizedBox(width: 6),
              benchButton(
                'COPY',
                benchGood,
                false,
                () => _copy(),
                expand: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
