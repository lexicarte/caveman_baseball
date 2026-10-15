---
name: caveman-baseball-base-geometry
description: RESOLVED — second base was short, it is now its own tunable; the mound's two disagreeing numbers were reconciled to 10.
metadata:
  type: project
---

Spotted 2026-10-04, fixed 2026-10-11.

`basePosition()` in `lib/sim/base_running.dart` used to put second at
`(0, d)` = `(0, 13)` while first and third sat at `(±9.19, 9.19)`. Home to
first was 13 paces but **first to second only 9.95** — not a diamond, and
it parked the bag three paces behind the thrower so the two read as one
cluster.

**Now:** `FieldSpec.secondDistance` is its own field, shipping at
`13 * sqrt2 = 18.385`. First and third stay on the 45s at `baseDistance`.
It is separate rather than derived because the view is from behind the
plate: how deep the diamond looks is a drawing decision, and the simulation
runs on whatever shape that decision produces.

Consequence that was flagged in advance and is still unmeasured: `resolveThrow`
takes bag positions from `basePosition`, so **throws to second are now
longer** and first-to-second runners are harder to retire than before. Base
running itself charges a flat `secondsPerBase` and is unaffected. This has
NOT been through `tool/game_report.dart` or `tool/matchup_matrix.dart` —
deferred on purpose under [[caveman-baseball-look-first]]. Run both before
treating the current balance numbers as real.

The infield apron had to grow with it: `FieldComponent.infieldRadius` 21 →
23, then 22.818 when the user tuned it.

**Then the whole diamond grew.** Tuned on the simulator 2026-10-11: home
to first 13 → **16.364**, second 18.385 → 18.764, mound 10 → **11.273**.
`secondsPerBase` did not move, so every throw and every cover-walk got
longer while the runner's time stayed flat — a real shift toward the
offence. `test/fielding_test.dart` now RECORDS one case of it: the thrower
can no longer cover first against a quick runner, where he used to. That
is a consequence, not a regression, and the lever if it reads as too
generous is `secondsPerBase`.

**Also resolved:** `FieldSpec.moundDistance` was 15 while
`Schemes._thrower.depth` was 10, and the cartoon field drew the mound at 10
so the man stood on it. Both say 10 now, and `Scheme.moundAt(depth)` moves
him when the dial moves.

All of these are sliders on the bench's UI tab —
[[caveman-baseball-tuning]].
