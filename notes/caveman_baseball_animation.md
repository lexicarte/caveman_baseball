---
name: caveman-baseball-animation
description: The animation workbench, the pose API, and the foot-slip arithmetic that any run cycle has to satisfy.
metadata:
  type: project
---

**Do not build a separate animation app.** Decided 2026-10-04 after the user
raised it. Two correct shapes instead:

- **Procedural rig** (what this project already does): animate by
  interpolating parameters. The workbench below is the editor.
- **Frame-by-frame** (what pixel art forces, since you cannot tween a 28px
  sprite without breaking the grid): buy **Aseprite**, ~$20 — onion skinning,
  tags, sprite-sheet export, and Flame reads the sheets via
  `SpriteAnimation.fromFrameData`. Do not try to out-build it.

Rough volume if frame-by-frame: ~10 actions x 3 builds x ~6 frames is **~180
sprites**. Procedural is ~10 functions and no assets, because build is one
number so one rig serves all three archetypes.

## Two instruments, both second entry points in this repo

```
flutter run -t lib/main_anim.dart       # animation workbench
flutter run -t lib/main_calibrate.dart  # tuning bench: UI / SWING / PITCH
```

The calibration bench became three tabs on 2026-10-11 — see
[[caveman-baseball-tuning]]. Bat swing and the arc moved to its SWING tab;
everything described below as "the swing bench" is now its PITCH tab.

Neither is a separate app. Both import the shipping code, so they cannot
drift from it, and both are covered by tests so a dev tool that throws on
launch cannot be committed.

## The swing bench

`lib/game/calibration.dart` (pure model) + `lib/main_calibrate.dart` (UI).
Set up a scenario — club, rock, ball speed, defence — and **watch it play**.

- **PLAY** — the clip, drawn with the GAME'S OWN renderers.
  `FieldComponent`, `CartoonCavemanPainter` and `BallComponent` all take a
  bare `Canvas`, so the bench calls them directly. A replay drawn by a
  second renderer would look however the bench decided, which answers
  nothing. Play/pause, scrub, and 0.15x / 0.35x slow motion.
- **FIELD** — plan view, one arrow per swing, with the defence and their
  reach drawn behind so you can see whether the extremes find the gaps.
- Three scenarios: EARLY (as early as the bat can reach), CENTRE, LATE.
  Every outcome runs the REAL `SwingResolver` and `BallFlightSim` with
  `jitter: 0` and a fixed seed — a bench that wobbles is telling you about
  its dice.

**`PlayClip.contactMoment` is the detail that makes it look right.** The
rock must switch onto its batted path when the BAT ARRIVES, not when the
player taps — those are `swingSeconds * contactPhase` apart (~90ms). Switch
at the tap and the ball leaps off a bat that has not got there yet, which
is the single thing that most makes a replay look fake.

The chaser also runs: `PlayClip.fielderAt()` finds the earliest interception
with `chaseBy` and animates that man with `placeFielder`.

## The calibration chart (now part of the bench)

`lib/game/calibration.dart` (pure model) + `lib/main_calibrate.dart` (UI).
Answers one question in two pictures: **does the bat meet the rock, and
when?**

- **TRAJECTORY** — the rock's drawn path against the club's swept arc, in
  render units. If they do not cross, no timing produces a hit.
- **TIMING** — rock height vs bat height over the flight, with every club's
  window shaded around the scoring instant. A crossing anywhere but the
  centre line is error the player can neither see nor correct for.

Readout gives the crossing error in ms, the gap in units, rock speed, and
a per-club pass/fail. Sliders show LIVE code values beside any change.

**Every default is read from the shipping constants** — `GameRules`,
`MatchController.contactDepth`, `CavemanBaseballGame.batterX/batterY/
handDrop`, and the real swing arc via
`CartoonCavemanPainter.swingGeometry()`. An instrument holding its own copy
of the numbers measures the wrong thing, and
`test/calibration_test.dart` asserts the chart's rock path and bat height
match the game's to 1e-6.

**Two traps it fell into about itself, both now commented in the code:**
1. `CartoonCavemanPainter.contactAt` (0.67) is a fraction of the EASED arc,
   not the raw animation phase. Use `Calibration.contactPhase`, which
   solves for it (~0.30).
2. The club is a SHAFT. Measuring rock-to-TIP reports a miss on a perfectly
   good swing — the rock is struck by the middle of the bat. Measure to the
   segment hand-to-tip.

## The workbench

`flutter run -t lib/main_anim.dart` — a SECOND ENTRY POINT in this repo, not
a second app. It imports the real `CavemanPainter`, so there is no export
step and it cannot drift. Hot reload works.

Three panels: the stage, an **at-in-game-size (28px)** row, and an
eight-frame **filmstrip** (a moving figure hides a dead frame; a strip does
not). Controls: action, play/scrub, speed, size, onion skin, travel.
`test/anim_workbench_test.dart` pumps it so a dev tool that throws on launch
cannot be committed.

## The pose API

`CavemanPainter.paint(..., pose: Pose)` replaced the old nullable `swing`
double. `Act { still, swing, run, throwing }`, with
`Pose.still() / .swing(t) / .run(t) / .throwing(t)`. Durations live on
`CavemanPainter` (`swingSeconds` 0.42, `throwSeconds` 0.60) so the harness
and the game cannot disagree.

## Foot slip is arithmetic, not taste

**Drive a run cycle from DISTANCE TRAVELLED, never from a timer.** Then slip
is impossible by construction. `CavemanPainter.runCycleSecondsFor()` does the
sum: each foot is planted for half the cycle and the two are half a cycle
apart, so the body covers `4 x strideAmp x shoulder` per cycle, and
`cycle = stride / speed`. `test/anim_workbench_test.dart` asserts
`cycle * speed == stride` at three heights for all three archetypes.

At in-game scale (28px figure, 6.3 px/pace, `secondsPerBase` 2.58):

| | stride | slip-free cycle | strides/sec |
|---|---|---|---|
| swift | 31.8px | 0.90s | 1.12 |
| steady | 37.6px | 1.19s | 0.84 |
| mighty | 47.1px | 1.65s | 0.61 |

**Mighty at 0.61 strides/sec is a real problem to watch**: stride grows with
build but speed falls with it, so the biggest man takes enormous slow steps.
If it reads as wading, shrink `_strideAmp` for the wider builds rather than
speeding up the cycle — speeding it up reintroduces slip.

Running is the most-watched animation in the game by a wide margin
(`secondsPerBase` 2.58, up to four bases, several runners), so judge an art
direction on its run cycle, not its swing. See
[[caveman-baseball-art]] for the two candidate styles.
