// Swing calibration, in two modes.
//
// PITCH TEST is the default. It shows the batting view — pitcher, batter,
// the perspective field — and does not throw until GO. GO plays five
// swings once: earliest foul left, latest foul right, dead centre, then
// the two foul lines. The sliders say where in the swing each of those
// contacts falls, how big the two men are, and how fast each rock flies.
//
// BAT SWING shows only the batter. SWING plays the bat once. The sliders
// there are the ones the match already reads: duration, window, whip, and
// the rest.
//
// Every dial writes [SwingTiming.now] as it moves. Save is what makes it
// survive the next launch. Reset puts the shipped swing back.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../bench/chrome.dart';
import '../bench/stage.dart';
import '../data/rocks.dart';
import '../sim/fielder_spec.dart';
import 'caveman_baseball_game.dart';
import 'pitch_test.dart';
import 'sprites/sprite_library.dart';
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

enum LabMode { pitch, bat }

class SwingCalibrationScreen extends StatefulWidget {
  const SwingCalibrationScreen({super.key});

  @override
  State<SwingCalibrationScreen> createState() => _SwingCalibrationScreenState();
}

class _SwingCalibrationScreenState extends State<SwingCalibrationScreen>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  Duration _last = Duration.zero;

  LabMode mode = LabMode.pitch;
  final shots = PitchShots();
  final sequence = PitchSequence();
  final bat = BatSwingPlayback();
  final sprites = SpriteLibrary();

  /// The mound the match starts the thrower on. Every scheme shares it.
  double get mound => Schemes.wheel.thrower.depth;

  String note = '';

  @override
  void initState() {
    super.initState();
    sprites.loadAvailable().then((_) {
      if (mounted) setState(() {});
    });
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
    final playing = sequence.running || bat.playing;
    if (!playing) return;
    final timing = SwingTiming.now;
    sequence.tick(step, timing, mound: mound);
    bat.tick(step, timing);
    setState(() {});
  }

  void _apply(SwingTiming next) => setState(() => SwingTiming.now = next);

  void _go() {
    bat.stop();
    setState(sequence.go);
  }

  void _swingBat() {
    sequence.stop();
    setState(bat.swing);
  }

  void _setMode(LabMode next) {
    if (next == mode) return;
    sequence.stop();
    bat.stop();
    setState(() => mode = next);
  }

  Future<void> _reset() async {
    await clearSwingPreset();
    if (!mounted) return;
    sequence.stop();
    bat.stop();
    setState(() => note = 'shipped swing');
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
    final pitching = mode == LabMode.pitch;
    return Theme(
      data: ThemeData.dark(
        useMaterial3: true,
      ).copyWith(scaffoldBackgroundColor: benchBg),
      child: RepaintBoundary(
        key: const Key('swing-lab-capture'),
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
                _modeSwitch(),
                Expanded(
                  flex: 5,
                  child: pitching ? _pitchStage(timing) : _batStage(timing),
                ),
                if (pitching) _pitchStatus() else _batStatus(),
                Expanded(
                  flex: 6,
                  child: pitching ? _pitchDials(timing) : _swingDials(timing),
                ),
                _actions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeSwitch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: ChoiceChip(
              key: const Key('mode-pitch'),
              label: const Text('PITCH TEST', style: TextStyle(fontSize: 11)),
              selected: mode == LabMode.pitch,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => _setMode(LabMode.pitch),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ChoiceChip(
              key: const Key('mode-bat'),
              label: const Text('BAT SWING', style: TextStyle(fontSize: 11)),
              selected: mode == LabMode.bat,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => _setMode(LabMode.bat),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pitchStage(SwingTiming timing) {
    final frame = pitchTestFrame(
      sequence: sequence,
      shots: shots,
      timing: timing,
      mound: mound,
    );
    return _view(
      zoom: pitchTestZoom,
      look: pitchTestLook,
      timing: timing,
      figures: [
        StageFigure(
          x: CavemanBaseballGame.throwerRenderOffsetX,
          y: mound,
          scale: timing.pitcherScale,
        ),
        batterFigure(swingPhase: frame.swingPhase, scale: timing.batterScale),
      ],
      rock: StageRock(
        x: frame.rock.x,
        y: frame.rock.y,
        lift: frame.rock.lift,
        rock: Rocks.plain,
      ),
    );
  }

  Widget _batStage(SwingTiming timing) {
    final phase = bat.phase(timing);
    return _view(
      zoom: batTestZoom,
      look: batTestLook(timing),
      timing: timing,
      figures: [batterFigure(swingPhase: phase, scale: timing.batterScale)],
      swingArc: true,
    );
  }

  Widget _view({
    required double zoom,
    required double look,
    required SwingTiming timing,
    required List<StageFigure> figures,
    StageRock? rock,
    bool swingArc = false,
  }) {
    final batter = figures.last;
    return CustomPaint(
      key: const Key('swing-lab-stage'),
      painter: StagePainter(
        zoom: zoom,
        look: look,
        cropToBand: false,
        curve: timing.curve,
        billboards: true,
        sprites: sprites,
        figures: figures,
        rock: rock,
        swingArc: swingArc ? Offset(batter.x, batter.y) : null,
      ),
      child: const SizedBox.expand(),
    );
  }

  Widget _pitchStatus() {
    final frame = pitchTestFrame(
      sequence: sequence,
      shots: shots,
      timing: SwingTiming.now,
      mound: mound,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            frame.caption,
            key: const Key('pitch-test-status'),
            style: benchMono.copyWith(color: benchInk, fontSize: 12),
          ),
          const SizedBox(height: 6),
          FilledButton(
            key: const Key('pitch-test-go'),
            style: FilledButton.styleFrom(
              backgroundColor: benchAccent,
              foregroundColor: const Color(0xFF1A1208),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: _go,
            child: const Text(
              'GO',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _batStatus() {
    final playing = bat.playing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            playing ? 'SWINGING' : 'SWING plays the bat',
            key: const Key('bat-swing-status'),
            style: benchMono.copyWith(color: benchInk, fontSize: 12),
          ),
          const SizedBox(height: 6),
          FilledButton(
            key: const Key('bat-swing'),
            style: FilledButton.styleFrom(
              backgroundColor: benchAccent,
              foregroundColor: const Color(0xFF1A1208),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: _swingBat,
            child: const Text(
              'SWING',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pitchDials(SwingTiming timing) {
    return ListView(
      key: const Key('pitch-dials'),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      children: [
        benchHeading('WHERE IN THE SWING'),
        _slider(
          key: const Key('earliest-hit'),
          label: 'earliest hit',
          value: timing.earliestHit,
          dial: SwingDials.hitPhase,
          shipped: SwingTiming.shippedEarliestHit,
          onChanged: (v) => _apply(timing.copyWith(earliestHit: v)),
        ),
        _slider(
          key: const Key('latest-hit'),
          label: 'latest hit',
          value: timing.latestHit,
          dial: SwingDials.hitPhase,
          shipped: SwingTiming.shippedLatestHit,
          onChanged: (v) => _apply(timing.copyWith(latestHit: v)),
        ),
        _slider(
          key: const Key('fair-early'),
          label: 'fair, 3rd line',
          value: timing.fairEarly,
          dial: SwingDials.hitPhase,
          shipped: SwingTiming.shippedFairEarly,
          onChanged: (v) => _apply(timing.copyWith(fairEarly: v)),
        ),
        _slider(
          key: const Key('fair-late'),
          label: 'fair, 1st line',
          value: timing.fairLate,
          dial: SwingDials.hitPhase,
          shipped: SwingTiming.shippedFairLate,
          onChanged: (v) => _apply(timing.copyWith(fairLate: v)),
        ),
        _slider(
          key: const Key('centre-hit'),
          label: 'centre hit',
          value: timing.centreHit,
          dial: SwingDials.hitPhase,
          shipped: SwingTiming.shipped.whip,
          onChanged: (v) => _apply(timing.copyWith(centreHit: v)),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '0 is the start of the swing, 1 is the finish. The earliest '
            'hit goes foul left, the latest foul right, and the two fair '
            'marks leave along the base lines.',
            style: benchMono.copyWith(fontSize: 9.5),
          ),
        ),
        benchHeading('SPRITE SIZE'),
        _slider(
          key: const Key('pitcher-size'),
          label: 'pitcher size',
          value: timing.pitcherScale,
          dial: SwingDials.spriteScale,
          shipped: 1,
          unit: 'x',
          onChanged: (v) => _apply(timing.copyWith(pitcherScale: v)),
        ),
        _slider(
          key: const Key('batter-size'),
          label: 'batter size',
          value: timing.batterScale,
          dial: SwingDials.spriteScale,
          shipped: 1,
          unit: 'x',
          onChanged: (v) => _apply(timing.copyWith(batterScale: v)),
        ),
        benchHeading('PITCH SPEED'),
        for (final rock in Rocks.all)
          _slider(
            key: Key('pitch-speed-${rock.id}'),
            label: rock.name,
            value: timing.speedFor(rock.id),
            dial: SwingDials.rockSpeed,
            shipped: 1,
            unit: 'x',
            onChanged: (v) => _apply(timing.withRockSpeed(rock.id, v)),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            'Each rock has its own speed. 1x is the pitch flight on the '
            'bat-swing screen. The five pitches throw a plain ROK, so the '
            'lines stay put. Save keeps every number.',
            style: benchMono.copyWith(fontSize: 9.5),
          ),
        ),
      ],
    );
  }

  Widget _swingDials(SwingTiming timing) {
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
            'pitches is only the pitch test.',
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
                'COPY',
                benchGood,
                false,
                () => _copy(),
                expand: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              benchButton(
                'SAVE CALIBRATION',
                benchAccent,
                false,
                () => _save(),
                expand: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
