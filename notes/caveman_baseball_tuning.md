---
name: caveman-baseball-tuning
description: The Look layer and the three-tab bench — where every visual number lives now, and the rule that keeps look dials out of the simulation.
metadata:
  type: project
---

Built 2026-10-11, on the user's instruction: "make pretty much every UI
element tunable so I can make it look right."

## Every visual number lives in `lib/game/look.dart`

`LookDefaults` holds the shipped constants. `Look.now` holds the live,
MUTABLE copy. `Ground.squash`, `Ground.plateY`, the four camera numbers,
the two figure heights and `FieldComponent.infieldRadius` are now
**getters** that read `Look.now` — call sites were left alone.

This forced a chain of `static const` in `CavemanBaseballGame` to become
getters: `drawnHeight`, `batterX`, `batterY`, `batHeight`,
`throwerRenderOffsetX`. `Calibration`'s constructor defaults had to become
nullable fields with fallback getters for the same reason — a const default
would freeze the bench at the shipped values while the view beside it moved.

**The rule, stated in the file: nothing in `lib/sim/` reads `Look`.** The
one deliberate bridge is `Look.fieldSpec`, which builds a `FieldSpec` from
the tuned distances, because the diamond you see has to be the diamond
that is played on.

`Look.dials` is a single table — name, label, range, shipped value, getter,
setter, group. Saving, loading, resetting, the slider list and the Dart
dump all iterate it, so adding a dial adds it everywhere. The bench's
sections are built from `Dial.group`, and a test asserts the groups
partition the table.

## `FieldSpec` gained `secondDistance`

Home-to-second is its own number now, not `baseDistance * sqrt2`. Seen from
behind the plate, how DEEP the diamond looks is a separate decision from
how wide. See [[caveman-baseball-base-geometry]].

`FieldSpec.moundDistance` was 15 while the thrower stood at 10; they now
both say 10, and `Scheme.moundAt(depth)` is how a tuned mound reaches him.

## The shipped geometry was tuned on the simulator, 2026-10-11

The user dragged these and they are now `LookDefaults`: corners 16.364,
second 18.764, mound 11.273, infield 21.5, wall **54**. The diamond is
deliberately WIDER than deep.

The wall went 38 -> 54 purely to get grass back: perspective eats the
outfield harder than anything else on screen, because it is the furthest
thing on it, and 38 left a stripe barely thicker than the chalk. The user
waved this through with "time should not depend on distance, we can
account for that" — so a drawing distance may be moved freely and the
timing consequences are settled separately. Bags came down with it:
`FieldComponent.bagWidth` 3.4 -> 2.6, since 3.4 was set against a man
drawn three times taller than he is now. `Look.diamondAspect` reports it live and
measures through the live projection, which since the camera was set back
is no longer the same as `1 / squash`.

`FieldSpec.compact` and `Schemes._thrower.depth` mirror these, and a test
holds all three together — the sim keeps its own consts so it never
reaches into the render layer, which is exactly how they can drift.

## Three tabs, because there are three separable problems

`flutter run -t lib/main_calibrate.dart`

- **UI** — the whole phone screen, scoreboard and cards included, with a
  scrub between the fielding and batting cameras (both ends themselves
  tunable). SAVE persists to `shared_preferences`; **DART** dumps the
  values as source to paste over `LookDefaults`, which is the only thing
  that makes them the game. The shipping game does NOT read the saved
  values — tuning on one device must not silently retune everyone's.
- **SWING** — the batter alone, pushed in past the batting camera and
  aimed at `batHeight`, with the bat's arc drawn. Owns `swingSeconds` and
  the six `SwingCurve` numbers.
- **PITCH** — window, flight, slow multiplier, and the three contact
  scenarios. Bat swing was REMOVED from it: tuning the arc beside a timing
  window made every change to one look like a change to the other.

`lib/bench/stage.dart` is the one place a camera becomes pixels, shared by
all three, and it calls the GAME'S renderers. A bench drawing its own
approximation is a bench you can tune to look right while the game still
looks wrong.

`camDepth` ("camera set back") joined the GROUND group when the fake 3D
landed — see [[caveman-baseball-projection]].

Deliberately NOT tunable: `viewportWidth/Height`, the band fractions, the
zoom rates, and `Ground.modelsDrawnAgainst` (which must NOT follow a
camera setting).

Still true that look changes do not go through the balance tools first —
[[caveman-baseball-look-first]].
