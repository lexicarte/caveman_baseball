// Swing tuning: the batter, close up, and nothing to time against.
//
// Separated from the pitch bench on purpose. How the bat MOVES and when it
// has to ARRIVE are two different problems, and tuning them on one screen
// means every tweak to the arc looks like a timing change. Here there is
// no rock and no window: just the sweep, its duration, and the path the
// tip takes, which is the only thing a player actually sees.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/caveman_baseball_game.dart';
import '../game/components/caveman.dart';
import '../game/components/caveman_cartoon.dart';
import '../game/ground.dart';
import 'chrome.dart';
import 'stage.dart';

class SwingTab extends StatefulWidget {
  const SwingTab({
    super.key,
    required this.seconds,
    required this.curve,
    required this.onChanged,
  });

  final double seconds;
  final SwingCurve curve;
  final void Function({double? seconds, SwingCurve? curve}) onChanged;

  @override
  State<SwingTab> createState() => _SwingTabState();
}

class _SwingTabState extends State<SwingTab>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  Duration _last = Duration.zero;

  /// Seconds into the swing. Held at the end rather than looped: a loop
  /// turns the arc into a windmill and you stop being able to see where
  /// one swing ends and the next begins.
  double playhead = 0;
  bool playing = false;
  double rate = 0.35;

  /// View only, never saved. How much closer than the batting camera to
  /// push in, so the tip of the club can be looked at properly. Starts
  /// well past the batting camera because at the batting camera the
  /// batter is 34 points tall and the club is a few pixels of it — fine
  /// to play against, useless to shape.
  double closer = 1.9;

  bool showArc = true;

  double get zoom => Ground.tightZoom * closer;

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

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (!playing || dt <= 0 || dt > 0.5) return;
    setState(() {
      playhead += dt * rate;
      if (playhead >= widget.seconds) {
        playhead = widget.seconds;
        playing = false;
      }
    });
  }

  void _swing() => setState(() {
    playhead = 0;
    playing = true;
  });

  double get phase => (playhead / widget.seconds).clamp(0.0, 0.999);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        flex: 52,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _swing(),
          child: CustomPaint(
            painter: StagePainter(
              zoom: zoom,
              // Aim at the height the BAT sweeps at, and fill the pane
              // rather than framing the player's band. This is an
              // inspection view: the question it answers is what the club
              // does, so the club belongs in the middle of it at every
              // zoom. The band framing is the UI tab's job.
              look: CavemanBaseballGame.batHeight,
              cropToBand: false,
              figures: [batterFigure(swingPhase: phase)],
              curve: widget.curve,
              swingArc: showArc
                  ? Offset(
                      CavemanBaseballGame.batterX,
                      CavemanBaseballGame.batterY,
                    )
                  : null,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
      Expanded(flex: 48, child: _controls()),
    ],
  );

  Widget _controls() => Container(
    color: benchBg,
    padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            benchButton('SWING', benchAccent, playing, _swing),
            const SizedBox(width: 6),
            benchButton('ARC', benchDim, showArc, () {
              setState(() => showArc = !showArc);
            }),
            const SizedBox(width: 10),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                ),
                child: Slider(
                  value: closer,
                  min: 0.6,
                  max: 6.0,
                  onChanged: (v) => setState(() => closer = v),
                ),
              ),
            ),
            Text('${zoom.toStringAsFixed(1)}x', style: benchMono),
          ],
        ),
        _transport(),
        _readout(),
        const Divider(height: 12, color: benchLine),
        Expanded(child: _dials()),
      ],
    ),
  );

  Widget _transport() => Row(
    children: [
      IconButton(
        iconSize: 20,
        visualDensity: VisualDensity.compact,
        onPressed: () => setState(() {
          if (playhead >= widget.seconds) playhead = 0;
          playing = !playing;
        }),
        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
      ),
      Expanded(
        child: Slider(
          value: playhead.clamp(0, widget.seconds),
          max: widget.seconds,
          onChanged: (v) => setState(() {
            playhead = v;
            playing = false;
          }),
        ),
      ),
      for (final r in [0.15, 0.35, 1.0])
        GestureDetector(
          onTap: () => setState(() => rate = r),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              r == 1.0 ? '1x' : '${r}x',
              style: benchMono.copyWith(
                color: rate == r ? benchAccent : benchDim,
              ),
            ),
          ),
        ),
    ],
  );

  Widget _readout() {
    final c = widget.curve;
    return Text(
      '${(widget.seconds * 1000).round()}ms end to end  ·  meets the ball at '
      '${(c.whip * 100).round()}% of that '
      '(${(widget.seconds * c.whip * 1000).round()}ms after the tap), '
      '${(c.contactAt * 100).round()}% through the sweep  ·  '
      'now at ${(phase * 100).round()}%',
      style: benchMono,
    );
  }

  void _setCurve(SwingCurve c) => widget.onChanged(curve: c);

  Widget _dials() => ListView(
    padding: EdgeInsets.zero,
    children: [
      BenchSlider(
        label: 'bat swing',
        value: widget.seconds,
        min: 0.12,
        max: 0.60,
        shipped: CavemanPainter.swingSeconds,
        unit: 'ms',
        scale: 1000,
        decimals: 0,
        onChanged: (v) => widget.onChanged(seconds: v),
      ),
      benchHeading('ARC'),
      _arc('load', widget.curve.back, -4.0, -1.0, SwingCurve.shipped.back,
          (v) => widget.curve.copyWith(back: v)),
      _arc('finish', widget.curve.through, -7.5, -3.5,
          SwingCurve.shipped.through, (v) => widget.curve.copyWith(through: v)),
      _arc('meets at', widget.curve.contactAt, 0.3, 0.95,
          SwingCurve.shipped.contactAt,
          (v) => widget.curve.copyWith(contactAt: v)),
      _arc('whip', widget.curve.whip, 0.08, 0.75, SwingCurve.shipped.whip,
          (v) => widget.curve.copyWith(whip: v)),
      _arc('approach', widget.curve.approach, 0.35, 2.5,
          SwingCurve.shipped.approach,
          (v) => widget.curve.copyWith(approach: v)),
      _arc('follow', widget.curve.follow, 0.5, 3.0, SwingCurve.shipped.follow,
          (v) => widget.curve.copyWith(follow: v)),
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'load/finish are the club angle in radians; meets-at is how '
                'far through the SWEEP it hits, whip how much of the TIME '
                'that takes',
                style: benchMono.copyWith(fontSize: 9.5),
              ),
            ),
            TextButton(
              onPressed: () => _setCurve(SwingCurve.shipped),
              child: const Text('reset arc'),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _arc(
    String label,
    double value,
    double min,
    double max,
    double shipped,
    SwingCurve Function(double) make,
  ) => BenchSlider(
    label: label,
    value: value,
    min: min,
    max: max,
    shipped: shipped,
    onChanged: (v) => _setCurve(make(v)),
  );
}
