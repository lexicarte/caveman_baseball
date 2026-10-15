// UI tuning: the whole screen, at any camera between fielding and batting,
// with every distance on the field on a slider underneath it.
//
// The point of showing the WHOLE screen rather than just the field is that
// the scoreboard and the cards are what make the playing area a band
// rather than a rectangle. Tune the camera against the full screen and the
// batter ends up behind the cards; tune it against the band and he does
// not.
import 'package:flutter/material.dart';

import '../game/caveman_baseball_game.dart';
import '../game/ground.dart';
import '../game/look.dart';
import '../sim/fielder_spec.dart';
import 'chrome.dart';
import 'stage.dart';

class FieldTab extends StatefulWidget {
  const FieldTab({super.key, required this.onSave, required this.saveNote});

  final Future<void> Function() onSave;
  final String saveNote;

  @override
  State<FieldTab> createState() => _FieldTabState();
}

class _FieldTabState extends State<FieldTab> {
  /// 0 is the fielding camera, 1 is the batting camera. The game only ever
  /// sits at one end, but it TRAVELS between them on every hit — so the
  /// middle has to look like something too.
  double t = 1.0;

  bool showCrop = true;

  double get zoom => Ground.wideZoom + (Ground.tightZoom - Ground.wideZoom) * t;
  double get look => Ground.wideLook + (Ground.tightLook - Ground.wideLook) * t;

  /// The men. At the batting camera the catcher is hidden, exactly as the
  /// game hides him — he stands between the camera and the batter.
  List<StageFigure> get figures {
    final scheme = Schemes.line.moundAt(Look.now.moundDistance);
    final batting = t > 0.5;
    return [
      for (final f in scheme.fielders)
        if (!(batting && !f.chases))
          StageFigure(
            x:
                f.position.x +
                (f.id == 'p' ? CavemanBaseballGame.throwerRenderOffsetX : 0),
            y: f.position.y,
          ),
      batterFigure(),
    ];
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(flex: 52, child: _screen()),
      Expanded(flex: 48, child: _controls()),
    ],
  );

  /// A phone screen, banded the way the game bands it.
  Widget _screen() => LayoutBuilder(
    builder: (context, c) {
      // Keep the mock at phone proportions however wide the pane is, or
      // the band fractions describe a shape no player will ever see.
      final h = c.maxHeight;
      final w = h * 390 / 844;
      return Center(
        child: SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: benchLine),
            ),
            child: Column(
              children: [
                Expanded(
                  flex: (Ground.bandTop * 1000).round(),
                  child: _hudStrip('0 · 0   YOU BAT   Top 1', Alignment.center),
                ),
                Expanded(
                  flex: ((Ground.bandBottom - Ground.bandTop) * 1000).round(),
                  child: ClipRect(
                    child: CustomPaint(
                      painter: StagePainter(
                        zoom: zoom,
                        look: look,
                        figures: figures,
                        cropToBand: showCrop,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                Expanded(
                  flex: ((1 - Ground.bandBottom) * 1000).round(),
                  child: _cards(),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _hudStrip(String text, Alignment align) => Container(
    color: const Color(0xFF221A12),
    alignment: align,
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: benchDim,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _cards() => Container(
    color: const Color(0xFF221A12),
    padding: const EdgeInsets.all(5),
    child: Row(
      children: [
        for (final c in ['TWIG', 'SMAK', 'KWIK'])
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF3A3228),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(
                c,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: benchDim,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _controls() => Container(
    color: benchBg,
    padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cameraRow(),
        const SizedBox(height: 4),
        _readout(),
        const Divider(height: 12, color: benchLine),
        Expanded(child: _dials()),
      ],
    ),
  );

  /// The zoom scrub. Both ends are themselves tunable, further down.
  Widget _cameraRow() => Row(
    children: [
      benchButton(
        'FIELDING',
        benchAccent,
        t < 0.02,
        () => setState(() => t = 0),
      ),
      const SizedBox(width: 5),
      Expanded(
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(value: t, onChanged: (v) => setState(() => t = v)),
        ),
      ),
      const SizedBox(width: 5),
      benchButton(
        'BATTING',
        benchAccent,
        t > 0.98,
        () => setState(() => t = 1),
      ),
      const SizedBox(width: 5),
      benchButton('CROP', benchDim, showCrop, () {
        setState(() => showCrop = !showCrop);
      }),
    ],
  );

  Widget _readout() {
    final near = Ground.figureHeightAt(zoom, 0);
    final deep = Ground.figureHeightAt(zoom, Look.now.wallRadius);
    return Text(
      'zoom ${zoom.toStringAsFixed(2)}x  ·  aim ${look.toStringAsFixed(1)}  ·  '
      'diamond ${Look.now.diamondAspect.toStringAsFixed(2)}:1  ·  '
      'horizon at ${Ground.horizonY.toStringAsFixed(1)}  ·  '
      'a man shrinks ${(deep / near * 100).round()}% from the plate to the '
      'wall  ·  plate to mound is '
      '${(Look.now.moundDistance / near).toStringAsFixed(1)} of him',
      style: benchMono,
    );
  }

  Widget _dials() => ListView(
    padding: EdgeInsets.zero,
    children: [
      // Built from the dial table, so a dial added to `Look` cannot be
      // added without a slider to drag it by.
      for (final g in Look.groups) ...[
        benchHeading(g),
        for (final d in Look.inGroup(g))
          DialSlider(dial: d, after: () => setState(() {})),
      ],
      const SizedBox(height: 8),
      Row(
        children: [
          benchButton('SAVE', benchGood, false, () async {
            await widget.onSave();
            if (mounted) setState(() {});
          }),
          const SizedBox(width: 6),
          benchButton('RESET', benchBad, false, () {
            Look.now.reset();
            setState(() {});
          }),
          const SizedBox(width: 6),
          benchButton('DART', benchDim, false, _showDart),
          const Spacer(),
          Flexible(
            child: Text(
              widget.saveNote,
              textAlign: TextAlign.right,
              style: benchMono,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
    ],
  );

  /// The current values as source. Saving keeps them on this device;
  /// pasting them over `LookDefaults` is what makes them the game.
  void _showDart() => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1C1711),
      title: const Text('Paste over LookDefaults', style: benchMono),
      content: SingleChildScrollView(
        child: SelectableText(
          Look.now.toDartSource(),
          style: benchMono.copyWith(color: benchInk, fontSize: 10),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('close'),
        ),
      ],
    ),
  );
}
