---
name: caveman-baseball-look-first
description: On Caveman Baseball, get the look and feel right FIRST — balance numbers are fakeable, a game that looks wrong is not.
metadata:
  type: feedback
---

Said plainly on 2026-10-11, twice:

> "I think you're doing too much analysis. let's make it look and feel like
> an actual baseball game AND THEN do the analytics"

> "we can fake time between bases in all different ways to make the
> analytics work, but if it doesn't look right we don't have a game"

**Why:** the simulation's knobs are arbitrary — `secondsPerBase`,
`transferTime`, `throwSpeed`, the timing window — and any of them can be
re-tuned to restore a scoreline. The geometry the player SEES cannot be
faked back into looking right. So a visual change that costs runs is a
visual change worth making; the runs come back later from a knob.

**How to apply:** while working on look and feel, make the change, show it,
and move on. Do NOT run `game_report` / `matchup_matrix` after every edit
and do not block a visual change on its scoring cost — mention the cost in
one line if it is large and keep going. Batch the balance pass for when the
look is settled.

This does NOT retire the tools or the invariants in
[[caveman_baseball_project]] — it defers them. Anything that ships still
has to pass both `matchup_matrix` checks and a `game_report` sanity look,
and the lesson that every hand-made balance prediction here has been wrong
still holds. The change is WHEN, not whether.

Already paid for under the old habit, and worth keeping: squaring the
diamond (second base 13 -> 18.4 paces) dropped sigma-45 scoring from
4.6-3.8 to 3.2-2.8 and pushed shutouts to 32%. Keep the geometry; fix the
runs later. Also measured: `secondsPerBase` is a CLIFF, not a dial — 2.58
to 2.35 took sigma-45 scoring from 3.2 to 10.9 runs. Use `transferTime`
(much gentler) when the balance pass comes.
