---
name: caveman_baseball_project
description: "Side-project game at ~/Development/caveman_baseball — deckbuilding caveman baseball; engine choice, the balance findings that are easy to re-break, and the tool-driven tuning workflow."
metadata: 
  node_type: memory
  type: project
  originSessionId: 72f9d6b6-8f50-4884-99ce-95a688d695ff
  modified: 2026-09-15T11:27:59.829Z
---

Started 2026-09-14. Top-down 2D **deckbuilding** caveman baseball at
`the repo root`. Side project, maybe ship.
iOS + Android, **portrait**. Steam explicitly demoted to afterthought.

**Engine: Flutter + Flame 1.38**, not Godot. Godot was the initial
recommendation purely for Steam; once Steam was demoted, the user's existing
Flutter depth and prior Flame use (`~/Development/game_tutorial`) decided it.

**Shape:** offence deck + defence deck, one card per pitch on each side, no
energy system. Bat cards and swing cards share the offence deck and the same
single play (user's call). The effect pipeline folds a *list* of cards, so
multi-card combos are a rule change, not a rewrite — the user explicitly wanted
combos kept open. 3 innings, 3 outs, no walks. All hits are ground balls.

**Batting was unfun for a UX reason, not a balance one:** there was no visible
ball. The only cue was a thin timing bar while the player looked at the field.
Fixed with a wind-up at the mound and the swing timer starting at release
(`MatchController.windupTime`). Any future "batting feels impossible" report
should check the visual cue before touching balance numbers.

**Loft (lob) is a card effect, never a timing outcome** — input is 1D and
already maps to direction + power; a hidden third outcome would be unreadable.
A lofted ball cannot be fielded inside its carry distance, loses most of its
speed on landing, and can be caught if it drops on someone.

**Balance findings that cost real effort — do not silently undo:**
- A fielder standing on **straightaway centre inverts the skill curve**.
  Perfect timing goes up the middle, so sharp timing hit *worse* than sloppy
  (measured spread −0.072). The 4-fielder formation deliberately splits ±13°
  with nobody on centre. This is why 3 fielders is rejected: it hits .542 and
  punishes skill.
- **Never hand-pick "sensible middle values" over the sweep's output.** Doing
  that once collapsed BA to .042 and made an aim card worth .001.
- Outfield plays must not throw the batter out at first, or a small field makes
  every ball an out (BA .012).
- `secondsPerExtraBase` is measured *relative to* `runnerToFirst`, so it must
  be re-tuned every single time that changes, or extra-base hits vanish and
  games become shutout grinds. This has bitten three times.
- The pair is violently sensitive: runnerToFirst 2.7 gives ~21 runs a game and
  3.6 gives ~1.0. Current 3.1 / 1.5 lands ~4-5 runs.
- The throw target must be SYMMETRIC (currently home plate). Throwing to first
  made mirror cards pay 3x differently - Push Slap .071 vs Pull Hook .203 -
  because one side of the field is simply nearer the target.
- Defence must leave a lane up the middle AND be reachable. An earlier
  baseball-shaped set covered a continuous 8.5-28.5m band of a 38m field, so
  there was nowhere to put the ball at all and every loft landed on someone.

**A silently failed edit shipped dead code.** The whole loft branch was never
inserted because a string replace targeted a comment that an earlier edit had
already rewritten - it analysed clean and tested clean while every loft card
resolved as a ground ball. Assert that a replacement matched before writing,
and `test/fielding_test.dart` now guards this specific failure.

**Tuning is tool-driven, not by hand.** `dart run tool/balance_sweep.dart`
searches knobs against constraints (starter deck weak but functional, upgrades
felt, skill monotonic); `tool/card_report.dart` prices every card;
`tool/game_report.dart` plays 300 full games and reports scorelines;
`tool/fielding_report.dart` and `tool/tuning_report.dart` cover fielding and
ball roll-out. Always check `game_report` after changing anything — per-swing
numbers can look fine while whole games are 0-0.

**Not built:** NO DEFENSIVE GAMEPLAY — the player picks a ball card and then
watches; fielding resolves automatically. The user flagged this as the next
real gap. Also: no season meta, no art, no lineup mechanic (user leans toward
lineup power coming from deck composition), and Chop is cut from the starter
deck because a guaranteed-contact bunt that is always thrown out is just a
strikeout with extra steps - it needs sacrifice rules first.

Related: [[feedback_stage_new_files]], [[dart_format_repo_style]].
