# Caveman Baseball

A deckbuilding baseball game for phones, built in Flutter and Flame. Every
ball is a ground ball, every at-bat is one tap, and the deck is clubs,
rocks and defensive schemes rather than cards that read their own rules to
you.

Portrait, iOS and Android. A side project.

## Running it

```sh
flutter run                          # the game
flutter run -t lib/main_calibrate.dart   # the tuning bench (UI / SWING / PITCH)
flutter run -t lib/main_anim.dart        # the animation workbench
flutter test
```

The two extra entry points are instruments, not separate apps. They import
the shipping renderers, so they cannot drift from what the game draws, and
they are covered by tests so a dev tool that throws on launch cannot be
committed.

## How it is laid out

| | |
|---|---|
| `lib/sim/` | the simulation. Pure Dart, no Flame, no Flutter. Swing resolution, ball flight, fielding, base running. |
| `lib/game/` | everything that draws. `ground.dart` is the only place field coordinates become screen coordinates. |
| `lib/game/look.dart` | every number that decides how the game LOOKS, in one mutable place, so the bench can drag them. |
| `lib/bench/` | the tuning bench's three tabs. |
| `lib/data/`, `lib/model/` | clubs, rocks, players, the field. |
| `tool/` | headless balance tools — `game_report`, `matchup_matrix`, `playbyplay`. |
| `notes/` | design notes: what was measured, what was decided, what is still owed. |

Two rules the code is built around, both of which were learned the hard
way and are written up in `notes/`:

- **Nothing in `lib/sim/` reads the look.** A number that decides how the
  game is drawn must not be able to decide an outcome, or tuning the
  picture silently retunes the sport.
- **Instruments read the live constants, never copies.** Tests assert the
  bench's rock path and bat height match the game's to 1e-6.

## Status

Playable, not balanced. The look was settled first on purpose — see
`notes/caveman_baseball_look_first.md` — so several geometry changes still
owe a pass through the balance tools before their numbers mean anything.
