---
name: caveman-baseball-schemes
description: Measured scheme-vs-scheme standing for Caveman Baseball — LINE and WIDE are both near-dead, and why.
metadata:
  type: project
---

Measured 2026-10-04 from `tool/matchup_matrix.dart`, total bases per at-bat
at timing sigma 35ms, batter picking his best club.

| rock | CLOSE | DEEP | LINE | WIDE | WHEEL |
|---|---|---|---|---|---|
| avg | 1.51 | **0.81** | 1.00 | 0.78 | **0.73** |
| rocks it is best for | 0 | 4 | 0 | 0 | 4 |

**LINE never wins a column, but it is not useless.** Per club, averaged over
rocks, LINE is far and away the best anti-ground scheme in the game:

| club | CLOSE | DEEP | LINE | WIDE | WHEEL |
|---|---|---|---|---|---|
| STIK | 0.49 | 0.65 | **0.08** | 0.61 | 0.31 |
| KWIK | 0.64 | 0.51 | **0.19** | 0.52 | 0.41 |
| TWIG | 0.09 | 0.06 | **0.03** | 0.06 | 0.03 |
| SMAK | 1.05 | **0.31** | 1.00 | 0.38 | 0.54 |

SMAK gets **exactly 1.00 against LINE with all eight rocks** — it goes over
their heads and lands where nobody is, every time. So LINE's "best club" row
is a flat 1.00 and it loses every column, but it strangles anything on the
ground. It is the read-the-hand scheme: play it when you have seen the
batter's three cards and SMAK is not among them.

**The flaw worth fixing: against LINE the rock choice does nothing at all.**
Eight rocks, identical 1.00. Whatever else LINE is, it should interact with
at least some of them.

**WIDE is WHEEL with a smaller hat.** Geometry: WIDE is ±44° @ 21 with a
deep man at 31; WHEEL is ±38° @ 21 with a deep man at 28. Six degrees and
three paces apart. WHEEL is equal or better on 6 of 8 rocks. WIDE's entire
reason to exist is **FAT ROK, where it gives up 0.48 against WHEEL's 0.99** —
a real gap, but one pairing. If they are meant to be distinct schemes, WIDE
needs to become genuinely wide (corners on the lines, deep man much deeper).

Related: FAT ROK is the strongest rock in the game paired with a deep
alignment — `DEEP + FAT ROK` at 0.39 is the one uncountered pair of the 40,
and `WIDE + FAT ROK` at 0.48 is second.

**How to apply:** these are findings, not decisions — nothing has been
changed. Any scheme edit must be re-checked with `matchup_matrix` (the two
invariants: every rock-and-scheme has a counter, every club has a weakness)
AND `game_report`, per [[caveman_baseball_project]].

See also [[caveman-baseball-viewport]] for the tap rules these schemes live
under.


## WUNDERBAT's side bite, raised 2026-10-10

`sideBite` 0.30 -> **0.46**. It is the FLOOR on a swing's power
(`powerFactor = sideBite + (1 - sideBite) * quality`, and quality is exactly
0 at the edge of the window), so it decides how bad the worst contact looks.
At 0.30 a mis-timed WUNDERBAT died **6 paces** from the plate — not "feeble
off the line" but visibly broken, a huge club producing a ball that stops at
the batter's feet. It now travels 13.5, in line with STIK's 15.8.

Checked: both `matchup_matrix` invariants hold (every rock-and-scheme still
countered — the same 1 of 40, `DEEP + FAT ROK`; every club still has a
weakness, WUNDERBAT worst 0.01). `game_report` was **unchanged**, but only
because WUNDERBAT is not in the starter club pool — the change bites once it
is owned, and the matrix is what covers that.


## The window edge is now a FOUL BALL (2026-10-11)

`maxSpray` was below the 48-degree foul line on every club, so the earliest
and latest swings the window allowed still went fair, straight down a
baseline. It now EXCEEDS the foul line on every club: swing at the extreme
and you slice it out of play, which is what being that early or late means.

| club | maxSpray | fair while \|timing\| < |
|---|---|---|
| TWIG | 62 (was 45) | 77% of the window |
| STIK | 58 (was 42) | 83% |
| SMAK | 56 (was 40) | 86% |
| KWIK | 54 (was 38) | 89% |
| WUNDERBAT | 50 (was 22) | 96% |

The fraction of the window that stays fair is now the club's real
directional character; `sideBite` still carries how WEAK an off-centre hit
is, so WUNDERBAT keeps its identity.

A foul costs a strike but **cannot be the third**
(`MatchController._recordFoul`), so the edges are "you survive, behind in
the count" rather than an out. That is why this was affordable.

Measured effect — a big, mostly good move:

| | before | after |
|---|---|---|
| sigma 45 score | 7.7-3.0 | **5.2-3.2** |
| sigma 45 blowouts | 35% | **19%** |
| sigma 45 record | 141-46-13 | **113-61-26** |
| pitches per game | 44 | 54 |
| **sigma 70 shutouts** | 11% | **24%** |

Scorelines look like baseball now and blowouts nearly halved. **The thing to
watch is shutouts at loose timing** — a quarter of games scoreless at sigma
70 may be discouraging for a weak player.

It also closed the one uncountered pairing: `matchup_matrix` now reports all
40 combinations countered (`DEEP + FAT ROK` was the holdout). Wider spray
lets the batter reach angles that were previously out of range.
