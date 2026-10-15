---
name: caveman-baseball-art
description: Art direction history for Caveman Baseball — what the pixel-art exploration settled, and what any style must carry forward.
metadata:
  type: project
---

**Style is unsettled. Two live candidates — and as of 2026-10-04 BOTH ARE
PLAYABLE IN THE GAME.** Toggle with the CARTOON/PIXEL button at the top
right of the HUD, mid-match. The old semi-realistic "classic" renderer is
retired from the game (2026-10-04) — `CavemanPainter` stays because it owns
the `Pose` type and the stride arithmetic, but nothing draws with it. `lib/game/art/art_style.dart` holds the enum and
a `ValueNotifier`; `FieldComponent` and `FiguresComponent` branch on it, and
the workbench (`flutter run -t lib/main_anim.dart`) previews both.

The cartoon figures live in `lib/game/components/caveman_cartoon.dart`, ported
from the canvas. Leg-swing amplitude is borrowed from the classic rig on
purpose so `CavemanPainter.strideFor` stays true for both — see
[[caveman-baseball-animation]].

- **Pixel art** — https://claude.ai/artifact/WKrhmUxtX6EH7fcyajPvWj
- **Flat cartoon** (Simpsons idiom, original tribe, sun-baked tan not yellow)
  — https://claude.ai/artifact/G7n2vMZwNHjsHG9XxqY4qp

Neither is chosen. Each canvas has Portrait, Landscape, Tap map, Caveman
sheet and Stone tablets; portrait runs 6.3 px/pace at 0.8 squash, landscape
11 at 0.62, and a 28px man in both.

**The deciding question is figure size.** At the 28px the game actually
stands them at, pixel art was designed for that height and the cartoon idiom
was not — big round eyes land at about three pixels across and the overbite
disappears. Both canvases have a SHOW AT IN-GAME SIZE toggle on the caveman
sheet; judge there, not on the hero figures.

## The cartoon direction

Scratchpad `cartoon/project/`: `cartoon.js` (the figure system) +
`scene.js` (field and backdrop), assembled into the boards by a node step.
Everything is emitted as **path data** from one shared module rather than
drawn as markup, because an artboard's UI must stay declarative — the boards
carry one generic `<sc-for>` over `{d, fill, stroke, sw}`. That also keeps one
caveman across all boards instead of three that drift.

Build is a single number (body width 0.74 / 1.00 / 1.34) plus hide colour.
Poses: stand, swing, crouch, throw. Palette: skin #D99A5B, outline #1E1710,
hides pale #D8C79E / mid #A8794A / dark #5E4028, grass #7FA845, dirt #C98D4E,
chalk #FFF6E0, sky #F2C878.

## The pixel-art direction (kept, not cancelled)

Canvas: https://claude.ai/artifact/WKrhmUxtX6EH7fcyajPvWj — boards Portrait,
Landscape, Tap map, Caveman sheet, Stone tablets. Source lives in the session
scratchpad under `pixel/project/`, built from `sprites.js` + `scene.js` and
assembled by a small node step.

What it established, all of which survives a style change:

- **Painted background, flat-shaded figures over it.** Rocky canyon: dusty
  sky gradient, flat-topped mesas, near spires, dry plain, scattered
  boulders. Earthy: grass greens, dirt browns, bone creams, ochre.
- **Figures need a dark outline** against a painted background or they
  dissolve into it. Generated from the silhouette, not hand-drawn.
- **A caveman reads from four things, in order:** jagged hair silhouette,
  a beard wider than the jaw, a ragged hem so the body does not end in a
  straight line, bare limbs outside the hide. Archetype is then width and
  hide colour only — SWIFT narrow and pale, MIGHTY slab-shouldered and dark.
- **Two figure sizes, redrawn not scaled.** Hero ~21 units tall for menus and
  card art, in-field ~14. Scaling a sprite breaks the grid.

## The playing view is a BAND, not the screen (2026-10-11)

Scoreboard above, cards and the tap-to-swing area below, field in between —
and the field is CROPPED at both, not faded. The HUD's top and bottom blocks
are opaque (`Color(0xFF161210)` with a 2px edge), and `_InsetCap` in
`main.dart` covers the status-bar and home-indicator insets, without which
the field shows through behind them and the crop reads as a bug.

The camera therefore aims at the middle of the BAND, not the middle of the
glass: `wideLook -4.5`, `tightLook 6.0`. Aim at the screen centre and the
batter ends up behind the cards.

During an at-bat you cannot see the outfield at all. That is deliberate —
the scheme is read from the banner by name.

## FIGURES SHRINK AS THE CAMERA PUSHES IN (2026-10-11)

The root cause of the at-bat never looking like baseball: held at one size,
a figure put the mound **1.65 body heights** from the plate. Real baseball
is ten or eleven. A man was 100pt tall at the close view — a quarter of the
screen width — so the batter and thrower read as two giants on top of each
other.

`Ground.figureHeightFor(zoom)` now interpolates **4.6 units wide → 1.56
tight**, which is 34pt at the at-bat view and **4.9 body heights**. The wide
view keeps men large on purpose: there they are markers for WHERE PEOPLE
ARE, which is all they need to be while you pick a scheme.

`Ground.modelScaleFor(zoom)` scales everything drawn as a **model** —
figures, bases, the rock. Ground **markings** do not: the wedge, the chalk,
the base paths, the mound, the wall, the standing stones. Those are the
field, and the field does not change size.

**The batter's offset had to become relative.** `batterSideInHeights =
-0.545`, `batterDepthInHeights = 0.031`, multiplied by the drawn height.
Absolute paces would leave a shrunken batter stranded with a club that no
longer reaches the plate; `test/batter_alignment_test.dart` now asserts the
club's reach exceeds the offset at any figure scale.

**All swing geometry is measured at the TIGHT height** — the camera is held
still for the whole at-bat, so it does not move while it matters.
`CavemanBaseballGame.drawnHeight` and `Calibration.figureHeight` both
default to `Ground.figureHeightTight`.

Costs nothing in the simulation: `game_report` byte-identical.

Two things only became visible once the figures shrank: the mound was
**8 paces across** (now 3.2, the real 18ft-against-60ft fraction), and the
standing stones had been scaling down into gravel.

The camera constants moved to `Ground` so the figure scale and the swing
bench can read them without importing the game.

## Camera and the at-bat, settled 2026-10-04

- **Ground squash is 0.8**, not 0.62.
- **The camera does NOT move during a pitch.** `tightZoom 3.6`,
  `tightLook 3.8` for the whole at-bat, easing wide once the ball is struck.
  Pushing in during the flight was unplayable — you cannot time a swing
  against a moving camera. Both eases are ~0.3s (`3.2 * dt` out, `5.0 * dt`
  in); snapping out of a 3.6x close-up reads as a cut to another scene.
- Tight only when `playerBatting`; fielding, you need the whole field.
- **At 3.6x the WIDE scheme's corner men are off screen** (44 degrees, 21
  paces). Accepted deliberately: the scheme is read from the banner.
- Figure scale: see the section above — this is what fixes the at-bat.
- **THERE IS NO TIMING METER.** Removed on purpose — you read the rock. That
  makes the rock the interface, so it is drawn oversized with a heavy outline
  and a strong trail, and it leaves from `Scheme.thrower.depth` (10), offset
  to his side and lifted, NOT from `FieldSpec.moundDistance` (15) which is
  where nobody stands. See [[caveman-baseball-base-geometry]].
- **The catcher is not drawn while the player bats** — the camera is behind
  the plate and he covers the batter.

## A play has to be PLAYED before it resolves

`_autoField()` used to settle the whole play on the same frame as the hit,
so `ballInPlay` never ticked: the ball never moved, nobody ran, and the
outcome banner appeared before you saw anything. The controller now defers
the resolution (`_defer`/`_pending`/`settleHold` in `match_controller.dart`)
until `playback` reaches the throw's arrival, and the ball flies to the bag
after the pickup instead of sitting in the outfield.

**THE TRAP:** every headless driver taps a base in a loop while
`throwResult == null`. On a CAUGHT ball there is no throw, so with the
deferral they tap forever, burn the 40000-iteration guard and silently
TRUNCATE every game — `game_report` dropped from 7.7-3.0 to 6.8-2.5 and
shutouts doubled, with nothing in the sim actually changed. Every driver
(`test/match_test.dart`, `tool/game_report.dart`, `tool/playbyplay.dart`)
now ticks when `interception.caught`. After fixing them the numbers came
back exactly, confirming the deferral is sim-neutral.

## WHAT THE PLAYER SEES IS THE INTERFACE

With no timing meter the swing is timed BY EYE, so **the rock meeting the
bat on screen and the swing scoring as on-time must be the same instant**.
Two separate things broke that, each worth more than a club's whole window,
and neither showed up anywhere — the simulation was correct throughout, the
input path was correct, and the balance tools never look at where anything
is drawn. On screen it just looked like the player was bad at the game.

When this comes up again: **probe the sim and the input path first to rule
them out** (a throwaway test that ticks the controller and taps the real
widget tree takes two minutes), then compare DRAWN positions in render
units. Do not tune the windows — the windows were never the problem.

### 1. The batter must stand level with the plate

The worst bug of the lot, because nothing failed. With no timing meter the
swing is timed by eye off the rock, and `timingError` is zero at the instant
the rock reaches **depth 0**. The batter was drawn at `fieldY: 1.2`, i.e.
1.2 paces further out — so "the rock is in front of the batter" and "on
time" were **174ms apart**, wider than every club window except TWIG's.
Swinging when the rock was in front of him was a strike, every time, while
every number in the simulation was correct.

Now `batterX = -2.6`, `batterY = 0.15` — 22ms of residual error.

### 1b. Contact is IN FRONT of the plate

`MatchController.contactDepth = 0.5` paces, so a perfect swing lands at
`contactTime = pitchFlightTime * (1 - contactDepth / throwerDepth)` — 95% of
the flight, not 100%. A hitter meets the ball out in front, and it makes a
slightly early swing the good one and a slightly late one the miss.

**Everything that scores or models a swing measures from `contactTime`, not
`pitchFlightTime`** — `swingNow`, the take threshold, the opponent's
resolution, and all three drivers (`game_report`, `playbyplay`,
`match_test`). Miss one and that driver's swings are biased by the 5%
difference and the balance silently moves.

Pitch speed: `GameRules.pitchFlightSeconds` is **1.21** (was 1.45), i.e. 20%
faster at 8.26 paces/s. Windows are absolute milliseconds, so this changes
no simulation outcome — `game_report` was byte-identical afterwards — it
just gives the player less ground to read the pitch in.

### 2. The rock must FLY AT HAND HEIGHT

I had given the pitch a lift that sank from 2.8 to 0.8 units as it came in,
so it arrived at the batter's ankles and **crossed the bat's height 214ms
before** the on-time moment. Swinging at what you saw was early on every
single pitch, outside the window of every club.

It now leaves the thrower's hand at hand height and is pitched so it meets
the bat EXACTLY at `contactDepth` — see `CavemanBaseballGame.rockLift()`,
with `handDrop = 0.45` (where BOTH painters put the hands). Mismatch is
zero.

`test/batter_alignment_test.dart` guards both: the batter's drawn depth must
convert to under a quarter of the tightest club window and fit inside every
club, and the rock's drawn height at the plate must be within 0.05 units of
the bat. Any change to where the batter, the bat or the pitch is drawn has
to be re-checked against it.

Related: the rock leaves from `Scheme.thrower.depth` (10), NOT
`FieldSpec.moundDistance` (15) — see [[caveman-baseball-base-geometry]].

## Two things that made the swing invisible

1. **Draw order.** In `caveman_cartoon.dart` the arms and club were painted
   with the other limbs, i.e. BEFORE the tunic, beard and head. The club
   sweeps across the chest, so most of its arc was behind the body and the
   swing looked like nothing happened. It is now a `swingOverlay` closure
   fired at the very END of `paint()`, with a motion smear.
2. **He was batting left-handed.** The batter was drawn at `fieldX: +3.4`,
   the first-base side, which from behind home is screen-RIGHT — the
   LEFT-hander's box. A right-hander stands on the third-base side, so
   `fieldX: -3.4`, and the club must sweep LEFT to RIGHT (angle `-2.5` to
   `+2.3`). Reversed, it swings away from the plate.

Also: the swing animation is **front-loaded**. The simulation scores the tap
instant but the bat still has to travel, and easing INTO the arc put visible
contact ~180ms after the tap, so a perfect swing looked late. Contact is now
at 30% of a 300ms swing (90ms), with a near-linear follow-through — ease the
tail too hard and seven of eight frames are the same picture of a stopped
bat.

Judge a swing in the workbench filmstrip, not in play: the whole thing is
300ms and you cannot see a draw-order or direction bug at that speed.

## Fielders actually move

They used to stand on their posts and get a tint, which is why a hit was
unreadable. Now the chaser runs at the ball and everyone else runs to the bag
they were assigned, using `placeFielder()` in `lib/game/field_motion.dart` —
a pure function so it can be tested, because an arrival at the wrong moment
never shows up in a screenshot. It reproduces `FielderSpec.timeToReach`
exactly (stand still for the reaction, then constant rate, arrive on the
tick the sim scored), and drives the stride from distance covered.
`test/field_motion_test.dart` covers it.

## The viewport was the "screen is too small" bug

`CameraComponent.withFixedResolution(width: 67, height: 38)` is a LANDSCAPE
viewport letterboxed into a portrait screen — that black band above and below
the field was the letterbox, not a background. Changed to **67 x 145**
(portrait, same aspect as the phone).

**The field does not get bigger either way** — 67 wide sets the scale and
390/67 = 5.8 points per pace in both cases. What changes is that the camera
now renders the world where the black used to be, so sky and foreground fill
the screen and the HUD sits over them. `wideLook` went 1.0 to -9.0 to drop
the field into the gap between the scoreboard and the cards, and the top HUD
needed a dark scrim because white text on a pale ochre sky is unreadable.

## Rules any style must obey

- **Scale:** a man should be about **15% of the field's on-screen depth**.
  The first attempt had him at 22% and men stood on top of each other in the
  infield.
- **The field only reads as a baseball field with four cues present at
  once:** two chalked foul lines, a dirt diamond with the base paths actually
  drawn in, a boundary on the outfield arc, and something behind the plate.
  A bare wedge of green reads as nothing. The base paths do the most work.
- **Five men, four tap regions.** The catcher stands behind the plate and is
  never sent — see [[caveman-baseball-viewport]].
- Portrait caps the field at 6.9 px/pace; the leftover vertical space is for
  cards and sky, not field.

Related: [[caveman_baseball_design]], [[caveman-baseball-schemes]].
