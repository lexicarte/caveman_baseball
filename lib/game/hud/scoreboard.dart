// Score, inning, outs and who is on base.
import 'package:flutter/material.dart';

import '../../sim/base_running.dart';
import '../../sim/game_rules.dart';

class Scoreboard extends StatelessWidget {
  const Scoreboard({
    super.key,
    required this.inningLabel,
    required this.playerRuns,
    required this.opponentRuns,
    required this.outs,
    required this.runners,
    required this.batting,
  });

  final String inningLabel;
  final int playerRuns;
  final int opponentRuns;
  final int outs;
  final List<Runner> runners;
  final bool batting;

  @override
  Widget build(BuildContext context) {
    final occupied = {
      for (final r in runners)
        if (!r.out) r.from,
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$playerRuns · $opponentRuns',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              batting ? 'YOU BAT' : 'YOU THROW',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              inningLabel,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _Diamond(occupied: occupied),
                const SizedBox(width: 10),
                for (var i = 0; i < GameRules.outsPerHalf; i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < outs
                            ? const Color(0xFFE07A5F)
                            : Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _Diamond extends StatelessWidget {
  const _Diamond({required this.occupied});
  final Set<int> occupied;

  @override
  Widget build(BuildContext context) {
    Widget pip(bool on) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: on
            ? const Color(0xFFFFD166)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(2),
      ),
    );
    return SizedBox(
      width: 34,
      height: 26,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: pip(occupied.contains(secondBase)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: pip(occupied.contains(thirdBase)),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: pip(occupied.contains(firstBase)),
          ),
        ],
      ),
    );
  }
}
