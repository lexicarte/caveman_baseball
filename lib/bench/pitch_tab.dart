// Pitch and contact tuning.
//
// TOP is exactly what the player sees while batting — the same cropped
// band, the same camera, the same figure scale, drawn by the game's own
// renderers through `StagePainter`.
//
// BOTTOM tunes WHEN the swing has to happen and nothing else:
//
//   WINDOW   how far either side of perfect still connects. ONE window for
//            the whole game, not a club property.
//   PITCH    the normal flight, and what a slow pitch multiplies it by.
//
// How the bat MOVES lives on the swing bench. Club, rock and defence are
// out of scope on purpose: they change where a hit GOES, not whether the
// swing feels like baseball.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/calibration.dart';
import '../game/caveman_baseball_game.dart';
import '../game/components/caveman_cartoon.dart';
import '../game/look.dart';
import '../sim/fielder_spec.dart';
import '../sim/game_rules.dart';
import 'chrome.dart';
import 'stage.dart';

const _caseColour = {
  ContactCase.early: Color(0xFF5BA3CF),
  ContactCase.centre: Color(0xFF9FC44E),
  ContactCase.late: Color(0xFFE08A3C),
};

const _caseName = {
  ContactCase.early: 'EARLIEST — foul left',
  ContactCase.centre: 'CENTRE — straight',
  ContactCase.late: 'LATEST — foul right',
};

class PitchTab extends StatefulWidget {
  const PitchTab({
    super.key,
    required this.swingSeconds,
    required this.curve,
    required this.window,
    required this.pitch,
    required this.slowScale,
    required this.onChanged,
  });

  /// Owned by the swing bench; read here so the two screens cannot
  /// disagree about how long a swing takes.
  final double swingSeconds;
  final SwingCurve curve;

  final double window;
  final double pitch;
  final double slowScale;
  final void Function({double? window, double? pitch, double? slowScale})
  onChanged;

  @override
  State<PitchTab> createState() => _PitchTabState();
}

class _PitchTabState extends State<PitchTab>
    with SingleTickerProviderStateMixin {
  bool slow = false;
  ContactCase chosen = ContactCase.centre;
  bool live = false;
  double rate = 0.35;

  Ticker? _ticker;
  Duration _last = Duration.zero;
  double playhead = 0;
  bool playing = false;

  /// In live mode: when you tapped.
  double? tappedAt;

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
      if (playhead >= clip.duration) {
        playhead = clip.duration;
        playing = false;
      }
    });
  }

  Calibration get cal => Calibration(
    flightSeconds: widget.pitch,
    timingWindow: widget.window,
    swingSeconds: widget.swingSeconds,
    slow: slow,
    slowScale: widget.slowScale,
    curve: widget.curve,
  );

  HitOutcome get outcome {
    if (live && tappedAt != null) {
      final err = (tappedAt! - cal.contactTime).clamp(
        -widget.window,
        widget.window,
      );
      return cal.outcomeFor(
        err.abs() < widget.window * 0.02
            ? ContactCase.centre
            : (err < 0 ? ContactCase.early : ContactCase.late),
      );
    }
    return cal.outcomeFor(chosen);
  }

  PlayClip get clip =>
      PlayClip(cal, outcome, Schemes.line.moundAt(Look.now.moundDistance));

  void _run(ContactCase k) => setState(() {
    chosen = k;
    live = false;
    tappedAt = null;
    playhead = 0;
    playing = true;
  });

  void _startLive() => setState(() {
    live = true;
    tappedAt = null;
    playhead = 0;
    playing = true;
    rate = 1.0;
  });

  void _tapSwing() {
    if (!live || tappedAt != null) return;
    setState(() => tappedAt = playhead);
  }

  /// Everyone on the field at the playhead, plus the batter mid-swing.
  List<StageFigure> get _figures {
    final c = clip;
    return [
      for (final post in c.scheme.fielders)
        if (post.chases)
          () {
            final at = c.fielderAt(post, playhead);
            return StageFigure(
              x:
                  at.x +
                  (post.id == 'p'
                      ? CavemanBaseballGame.throwerRenderOffsetX
                      : 0),
              y: at.y,
              pose: at.pose,
            );
          }(),
      batterFigure(swingPhase: c.swingAt(playhead)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = clip;
    final cam = c.cameraAt(playhead);
    final r = c.rockAt(playhead);
    return Column(
      children: [
        Expanded(
          flex: 52,
          child: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _tapSwing(),
                child: CustomPaint(
                  painter: StagePainter(
                    zoom: cam.zoom,
                    look: cam.look,
                    figures: _figures,
                    rock: StageRock(
                      x: r.x,
                      y: r.y,
                      lift: r.lift,
                      rock: cal.rock,
                    ),
                    curve: widget.curve,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              if ((playhead - c.contactMoment).abs() < 0.05)
                const Positioned(
                  left: 10,
                  top: 8,
                  child: Text(
                    'CONTACT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: benchGood,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(flex: 48, child: _controls()),
      ],
    );
  }

  Widget _controls() => Container(
    color: benchBg,
    padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _scenarioRow(),
        const SizedBox(height: 6),
        _transport(),
        _verdict(),
        const Divider(height: 12, color: benchLine),
        Expanded(child: _dials()),
      ],
    ),
  );

  Widget _scenarioRow() => Row(
    children: [
      for (final k in ContactCase.values)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 5),
            child: benchButton(
              k.label,
              _caseColour[k]!,
              !live && chosen == k,
              () => _run(k),
            ),
          ),
        ),
      benchButton('LIVE', benchAccent, live, _startLive),
    ],
  );

  Widget _transport() => Row(
    children: [
      IconButton(
        iconSize: 20,
        visualDensity: VisualDensity.compact,
        onPressed: () => setState(() {
          if (playhead >= clip.duration) playhead = 0;
          playing = !playing;
        }),
        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
      ),
      IconButton(
        iconSize: 18,
        visualDensity: VisualDensity.compact,
        onPressed: () => setState(() {
          playhead = 0;
          tappedAt = null;
          playing = true;
        }),
        icon: const Icon(Icons.replay),
      ),
      Expanded(
        child: Slider(
          value: playhead.clamp(0, clip.duration),
          max: clip.duration,
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

  /// Where bat and ball actually meet, which is the thing being calibrated.
  Widget _verdict() {
    final o = outcome;
    final ballDepth = cal.depthAt(clip.contactMoment);
    final gap = cal.gapAtContact();
    final liveNote = live
        ? (tappedAt == null
              ? '  ·  TAP THE VIEW TO SWING'
              : '  ·  you were '
                    '${((tappedAt! - cal.contactTime) * 1000).toStringAsFixed(0)}ms'
                    ' ${tappedAt! < cal.contactTime ? "early" : "late"}')
        : '';
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_caseName[o.kind]}$liveNote',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: _caseColour[o.kind],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'meets the rock ${ballDepth.toStringAsFixed(2)} paces off the '
            'plate  ·  bat '
            '${gap < 0.4 ? "on it" : "${gap.toStringAsFixed(2)} off"}'
            '  ·  ${o.swing.sprayDegrees.toStringAsFixed(0)}° '
            '${o.foul ? "FOUL" : "fair"}  ·  '
            '${o.distance.toStringAsFixed(1)} paces',
            style: benchMono.copyWith(color: gap < 0.4 ? benchGood : benchBad),
          ),
        ],
      ),
    );
  }

  Widget _dials() => ListView(
    padding: EdgeInsets.zero,
    children: [
      BenchSlider(
        label: 'window',
        value: widget.window,
        min: 0.06,
        max: 0.30,
        shipped: GameRules.timingWindow,
        unit: 'ms',
        scale: 1000,
        decimals: 0,
        onChanged: (v) => widget.onChanged(window: v),
      ),
      BenchSlider(
        label: 'pitch',
        value: widget.pitch,
        min: 0.6,
        max: 2.0,
        shipped: GameRules.pitchFlightSeconds,
        unit: 's',
        onChanged: (v) => widget.onChanged(pitch: v),
      ),
      BenchSlider(
        label: 'slow x',
        value: widget.slowScale,
        min: 1.0,
        max: 2.5,
        shipped: GameRules.slowPitchScale,
        unit: 'x',
        onChanged: (v) => widget.onChanged(slowScale: v),
      ),
      Row(
        children: [
          const SizedBox(width: 128, child: Text('pitch kind', style: benchMono)),
          benchButton('NORMAL', benchAccent, !slow, () {
            setState(() => slow = false);
          }),
          const SizedBox(width: 6),
          benchButton('SLOW', benchAccent, slow, () {
            setState(() => slow = true);
          }),
          const Spacer(),
          Text(
            '${(Look.now.moundDistance / cal.flight).toStringAsFixed(1)} '
            'paces/s',
            style: benchMono,
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Text(
          'the bat takes ${(widget.swingSeconds * 1000).round()}ms and meets '
          'the ball ${(widget.swingSeconds * widget.curve.whip * 1000).round()}ms '
          'in — tune that on the SWING bench',
          style: benchMono.copyWith(fontSize: 9.5),
        ),
      ),
    ],
  );
}
