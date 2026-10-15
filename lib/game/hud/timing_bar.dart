// Visualises pitch flight against the bat's contact window.
//
// This exists for tuning, not for shipping — seeing exactly where the window
// sits is the fastest way to judge whether a bat is fair or infuriating.
import 'package:flutter/material.dart';

class TimingBar extends StatelessWidget {
  const TimingBar({
    super.key,
    required this.progress,
    required this.windowFraction,
    required this.active,
  });

  /// Pitch progress where 1.0 is the ideal contact moment.
  final double progress;

  /// Contact window half-width, as a fraction of pitch flight time.
  final double windowFraction;

  final bool active;

  /// The bar shows a little past the plate so late swings are visible.
  static const double _span = 1.6;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final idealX = w * (1.0 / _span);
        final windowW = w * (windowFraction / _span);

        return SizedBox(
          height: 34,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              Positioned(
                left: idealX - windowW,
                width: windowW * 2,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7CC46B).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              Positioned(
                left: idealX - 1,
                child: Container(width: 2, height: 22, color: Colors.white70),
              ),
              if (active)
                Positioned(
                  left: (w * (progress / _span)).clamp(0.0, w - 3),
                  child: Container(
                    width: 3,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD166),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
