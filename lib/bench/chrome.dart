// Shared furniture for the three tuning benches: colours, buttons, and the
// one slider row every dial uses.
import 'package:flutter/material.dart';

import '../game/look.dart';

const benchInk = Color(0xFFE8DCC0);
const benchDim = Color(0xFF8A8276);
const benchAccent = Color(0xFFD08B3A);
const benchGood = Color(0xFF8E9A4E);
const benchBad = Color(0xFFC4452C);
const benchBg = Color(0xFF14110D);
const benchLine = Color(0xFF2E2620);

const benchMono = TextStyle(
  fontFamily: 'monospace',
  fontSize: 11,
  color: benchDim,
);

Widget benchButton(
  String label,
  Color colour,
  bool on,
  VoidCallback tap, {
  bool expand = false,
}) {
  final w = InkWell(
    onTap: tap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: on ? colour.withValues(alpha: 0.26) : const Color(0xFF241C14),
        border: Border.all(color: on ? colour : const Color(0xFF3A3025)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          color: on ? benchInk : benchDim,
        ),
      ),
    ),
  );
  return expand ? Expanded(child: w) : w;
}

/// One labelled slider, showing the shipped value in brackets whenever the
/// live one has moved off it. Seeing what you changed FROM is most of what
/// makes a bench usable.
class BenchSlider extends StatelessWidget {
  const BenchSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.shipped,
    required this.onChanged,
    this.unit = '',
    this.scale = 1,
    this.decimals = 2,
    this.labelWidth = 128,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double shipped;
  final ValueChanged<double> onChanged;
  final String unit;
  final double scale;
  final int decimals;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final moved = (value - shipped).abs() > 1e-9;
    String fmt(double v) => (v * scale).toStringAsFixed(decimals);
    return Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(label, style: benchMono, overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 96,
          child: Text(
            moved ? '${fmt(value)} (${fmt(shipped)})' : '${fmt(value)}$unit',
            textAlign: TextAlign.right,
            style: benchMono.copyWith(color: moved ? benchAccent : benchDim),
          ),
        ),
      ],
    );
  }
}

/// A [BenchSlider] wired straight to one of the look dials.
class DialSlider extends StatelessWidget {
  const DialSlider({super.key, required this.dial, required this.after});

  final Dial dial;

  /// Called once the value has been written, so the tab can repaint.
  final VoidCallback after;

  @override
  Widget build(BuildContext context) => BenchSlider(
    label: dial.label,
    value: dial.get(Look.now),
    min: dial.min,
    max: dial.max,
    shipped: dial.shipped,
    unit: dial.unit.isEmpty ? '' : ' ${dial.unit}',
    onChanged: (v) {
      dial.set(Look.now, v);
      Look.changed();
      after();
    },
  );
}

Widget benchHeading(String text) => Padding(
  padding: const EdgeInsets.only(top: 10, bottom: 2),
  child: Row(
    children: [
      const Expanded(child: Divider(color: benchLine)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(text, style: benchMono.copyWith(color: benchAccent)),
      ),
      const Expanded(child: Divider(color: benchLine)),
    ],
  ),
);
