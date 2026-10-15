// The playing interface.
//
// Rebuilds off the game's per-frame revision counter and reads the controller
// directly, so there is one source of truth for what is on screen.
import 'package:flutter/material.dart';

import '../../model/loadout.dart';
import '../../sim/fielder_spec.dart';
import '../art/art_style.dart';
import '../caveman_baseball_game.dart';
import '../match_controller.dart';
import 'card_view.dart';
import 'scoreboard.dart';

class MatchHud extends StatelessWidget {
  const MatchHud({super.key, required this.game});

  final CavemanBaseballGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: game.revision,
      builder: (context, _, _) {
        final m = game.match;
        return SafeArea(
          child: Column(
            children: [
              // A scrim under the top HUD. The cartoon sky is a pale ochre
              // and white text on it is unreadable; the classic style is
              // dark and does not need it, but a scrim costs nothing there.
              // OPAQUE, not a scrim. The playing view is a BAND in the
              // middle of the screen — scoreboard above it, cards below —
              // and you should not be able to see the field behind either.
              // A fade just makes the crop look like a mistake.
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xFF161210),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF2E2620), width: 2),
                  ),
                ),
                child: Column(
                  children: [
                    // Two art directions are live. Flipping between them in play
                    // is the only way to judge them; from memory is useless.
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16, top: 2),
                        child: ValueListenableBuilder<ArtStyle>(
                          valueListenable: artStyle,
                          builder: (context, style, _) => TextButton(
                            onPressed: () => artStyle.value = style.next,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              foregroundColor: const Color(0xFF9A9085),
                            ),
                            child: Text(
                              style.label,
                              style: const TextStyle(
                                fontSize: 11,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: Scoreboard(
                        inningLabel: m.progress.inningLabel,
                        playerRuns: m.progress.playerRuns,
                        opponentRuns: m.progress.opponentRuns,
                        outs: m.outs,
                        runners: m.runners,
                        batting: m.playerBatting,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Banner(match: m),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
              const Spacer(),
              _Bottom(game: game),
            ],
          ),
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.match});
  final MatchController match;

  @override
  Widget build(BuildContext context) {
    final swing = match.swing;
    final showRock =
        match.phase == PitchPhase.inFlight ||
        match.phase == PitchPhase.ballInPlay ||
        match.phase == PitchPhase.outcome;
    return Column(
      children: [
        if (match.message.isNotEmpty)
          Text(
            match.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        // The rock and the scheme are readable in flight — that is when the
        // swing-or-take decision happens.
        if (showRock)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${match.rock.name}  ·  ${match.scheme.name}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                letterSpacing: 0.6,
              ),
            ),
          ),
        if (swing != null && match.phase != PitchPhase.commit)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              swing.label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 11,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );
  }
}

class _Bottom extends StatelessWidget {
  const _Bottom({required this.game});
  final CavemanBaseballGame game;

  @override
  Widget build(BuildContext context) {
    final m = game.match;
    // The other half of the crop, and also where you tap to swing.
    return ColoredBox(
      color: const Color(0xFF161210),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // No timing meter. You read the rock, not a bar — a meter turns
            // the at-bat into watching a gauge at the bottom of the screen
            // while the thing you are hitting goes by unwatched.
            Text(
              _prompt(m),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            if (!m.playerBatting && m.phase == PitchPhase.commit)
              _SchemeRow(game: game),
            SizedBox(height: 104, child: _Slots(game: game)),
          ],
        ),
      ),
    );
  }

  static String _prompt(MatchController m) => switch (m.phase) {
    PitchPhase.commit =>
      m.playerBatting ? 'PICK A CLUB' : 'SET YOUR MEN, PICK A ROCK',
    PitchPhase.windUp => 'WIND UP…',
    PitchPhase.inFlight => m.playerBatting ? 'TAP TO SWING' : 'THEY SWING…',
    PitchPhase.ballInPlay =>
      m.playerBatting
          ? 'BALL IN PLAY'
          : (m.interception == null ? 'TAP A MAN TO CHASE' : 'TAP A BAG'),
    PitchPhase.outcome => 'TAP TO GO ON',
    PitchPhase.gameOver => 'GAME OVER',
  };
}

class _SchemeRow extends StatelessWidget {
  const _SchemeRow({required this.game});
  final CavemanBaseballGame game;

  @override
  Widget build(BuildContext context) {
    final m = game.match;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final s in Schemes.all)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: () {
                  m.chooseScheme(s);
                  game.revision.value++;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: s.id == m.scheme.id
                        ? const Color(0xFFFFD166).withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    s.name,
                    style: TextStyle(
                      color: s.id == m.scheme.id
                          ? const Color(0xFF241C10)
                          : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Slots extends StatelessWidget {
  const _Slots({required this.game});
  final CavemanBaseballGame game;

  @override
  Widget build(BuildContext context) {
    final m = game.match;
    final choosing = m.phase == PitchPhase.commit;

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: slotsPerBatter,
      separatorBuilder: (_, _) => const SizedBox(width: 7),
      itemBuilder: (context, slot) {
        final spent = !m.availableSlots.contains(slot);
        void play() {
          if (m.playerBatting) {
            m.commitSlot(slot);
          } else {
            m.commitRock(slot);
          }
          game.revision.value++;
        }

        if (m.playerBatting) {
          final card = m.battingTeam.batting[m.batterIndex][slot];
          return switch (card) {
            ClubCard(:final club) => CardView.club(
              club,
              enabled: choosing,
              spent: spent,
              onTap: play,
            ),
            ItemCard(:final item) => CardView.item(
              item,
              enabled: choosing,
              spent: spent,
              onTap: play,
            ),
            // An empty slot is still a real swing — STIK, the club every
            // tribe already owns.
            null => CardView.empty(
              title: 'STIK',
              blurb: 'Mid range, any angle.',
              enabled: choosing,
              spent: spent,
              onTap: play,
            ),
          };
        }

        final rock = m.playerTeam.throwing[m.opponentBatterIndex][slot];
        return rock == null
            ? CardView.empty(
                title: 'ROK',
                blurb: 'Just a rock.',
                enabled: choosing,
                spent: spent,
                onTap: play,
              )
            : CardView.rock(rock, enabled: choosing, spent: spent, onTap: play);
      },
    );
  }
}
