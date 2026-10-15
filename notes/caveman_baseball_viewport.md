---
name: caveman-baseball-viewport
description: Measured constraint on portrait vs landscape for Caveman Baseball — portrait caps the field at 6.9 px/pace and no defensive scheme clears a 44pt tap target.
metadata:
  type: project
---

Measured 2026-10-04 while fixing the art scale. The field is a 96-degree
wedge: 56.5 paces across but only 38 deep, so it is a landscape-shaped object.

**Portrait is width-limited.** At 390pt the wedge caps out at 6.9 px/pace, and
the leftover vertical space can only hold cards and sky — making the phone
taller does not make the field bigger. **Landscape is depth-limited instead,
and depth is the one dimension the 0.62 ground squash already shrank**, so the
same field fits at 11-13 px/pace. 1.75x linear, 3x the area, at the game's own
camera.

Checked every scheme in `lib/sim/fielder_spec.dart` against a 44pt tap target,
centre to centre:

| scheme | portrait @6.3 | landscape @11 |
|--------|---------------|---------------|
| CLOSE  | 24px          | 41px          |
| LINE   | 35px          | 61px          |
| DEEP / WIDE / WHEEL | 39px | 68px     |

At the game's real 0.62 squash **all five schemes fail in portrait**; only
CLOSE fails in landscape, and it clears at 13 px/pace. The squeeze is always
the thrower (depth 10) against the centre fielder — CLOSE puts them 6 paces
apart, and 6 paces of *depth* is exactly what the squash eats.

**RESOLVED 2026-10-04, staying portrait.** The user chose "tap the closest
player whenever a defense tap is done". Shipped as `lib/sim/tap_regions.dart`:
a tap anywhere sends whoever could *stand on that point soonest*
(`FielderSpec.timeToReach`, the same function fielding already uses). No
cutoff radius, no dead ground, no tap that misses. Same rule for the throw —
nearest bag. The old path was a 9-pace nearest-sprite search that could miss
everybody and silently do nothing.

**The catcher is excluded entirely** (`FielderSpec.chases`, false only for
him): he guards home and is never sent, in the UI, in the AI's `_autoField`,
in `tapFielder`, and in `tool/harness.dart`. The coverage solver already gave
him home in all 20 scheme-by-chaser cases, so no pinning was needed. Cost:
+0.3 runs per game at sigma 45 (7.4 to 7.7), blowouts 33% to 35%; the matchup
matrix did not move at all, because his 4.0 range and 0.45 reaction meant he
almost never won a chase anyway.

Nearest in TIME, not paces, on purpose: it makes a swift man visibly own more
ground, and `test/tap_regions_test.dart` guards both that and the invariant
that no lineup lets one man own a majority of the field.

**Residual, accepted:** sweeping all 5 schemes against all 243 archetype
assignments, no man is ever unreachable, but in portrait CLOSE's thrower and
LINE's centre fielder get regions narrower than a thumb, so there the tap
chooses between two men for you. **No squash or depth tweak fixes this** —
those squeezes are lateral, and `tool/tap_fix_sweep.dart` shows LINE pinned at
14px from squash 0.62 all the way to 1.0.

**How to apply:** do not quietly re-tune `fielder_spec.dart` depths to widen a
tap region — those depths are balance-tuned and [[caveman_baseball_project]]
records that every hand-made balance prediction in this project has been
wrong. `tool/game_report.dart` and `tool/playbyplay.dart` now model the
player's chaser choice with the shipped resolver, so they price cards for a
player who can actually make that choice; scoring was unchanged by the switch
(7.3-3.1 to 7.4-3.1 at sigma 45).

Also fixed the same day: in-field sprites must be a **separate, smaller
redrawn set**, not the hero sprites scaled. Scaling a pixel sprite breaks the
grid. Hero figures are ~21 cells tall, the in-field set ~14, which puts a man
at 15% of field depth instead of 22%.

Artifact: https://claude.ai/artifact/WKrhmUxtX6EH7fcyajPvWj
