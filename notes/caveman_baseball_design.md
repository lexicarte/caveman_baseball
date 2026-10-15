---
name: caveman_baseball_design
description: "Settled design decisions for Caveman Baseball — the core three-variable split, club roster, defence schemes, at-bat loop, and full per-runner base running."
metadata: 
  node_type: memory
  type: project
  originSessionId: 72f9d6b6-8f50-4884-99ce-95a688d695ff
  modified: 2026-09-18T00:15:47.646Z
---

Design decisions settled in conversation on 2026-09-16/17. These supersede
earlier shapes described in [[caveman_baseball_project]]; that file keeps the
engine choice and the balance lessons, this one keeps the design.

**The core split, and the whole game in one line:**
the CLUB picks the distance · the TIMING picks the angle · the SCHEME picks
where the defence stands. An earlier twelve-bat roster built from five
abstract "dials" was wrong because the space only has two real dimensions.

**Clubs (5-6 total, not 12).** Names are the USER'S job — do not invent brands,
they rejected both single-syllable words and phonetic misspellings.
- STIK — short, ground, any angle
- (TBD) — mid, ground, any angle
- SMAK — long, **air**, any angle. Safe passage, dies where it lands.
- (TBD) — long, ground, fast. Runs the gauntlet; extra bases if it survives.
- WUNDERBAT — very long, ground, straight only, weak at angles
- (TBD) — bunt. Identity is **"you cannot miss"**, not "shortest", or it
  duplicates STIK.

**Air is only for the long ball.** Short and mid fly over nobody but the
thrower, so the mechanic doesn't earn its place there.

**Power no longer falls off with angle** (user's call, and it was correct).
Timing used to decide direction AND contact quality because there is only one
input, which meant every side hit was feeble and a packed middle was
unbeatable. Fixing it closed the worst balance hole in the game, did not
inflate scoring, and kept the skill curve. "Side bite" is now a per-club trait:
WUNDERBAT keeps little (strong straight, weak at angles), the mid club keeps a
lot.

**Defence schemes (5):** CLOSE / DEEP / LINE / WIDE / WHEEL — depth and width bands
(code: `lib/sim/fielder_spec.dart`). Earlier names: IN/OUT/MID/WIDE/RING, and before
that Crowd/Wall/Pinch/Spread/Ring. Mapping: IN→CLOSE, OUT→DEEP, MID→LINE, RING→WHEEL.

**DECISION: LINE (formerly MID) is flattened.** All three men bunched on the middle at the
SAME depth. Previously they were bunched and also staggered front-to-back,
covering 7-39 paces of a 44-pace field, so nothing went through it or over it
— it was the only genuinely unbeatable scheme. Flattening keeps the "everybody
guard the middle" identity and makes a long ball the obvious answer.

**LOCKED: defence mirrors offence.** The thrower loads 3 rocks/modifiers
against each batter pre-game, same shape as the hitter's 3 clubs. In play the
thrower chooses the ORDER of those three and picks the SCHEME freely at every
pitch.

Scheme is NOT committed per batter — the user reversed on this deliberately:
committing it means the batter learns the scheme after pitch one and knows
exactly where to hit. Free scheme keeps every blind commit genuinely blind, and
it preserves the earlier rule that taking a strike is not free reconnaissance.

**The pitch sequence:** batter commits one club blind -> thrower commits one
rock + a scheme blind -> BOTH the scheme and the rock become visible during
the pitch's flight -> batter swings or takes -> resolve. Both sides burn a card either way, so the
two 3-card stacks stay in step. A taken risk rock costs the thrower a card and
yields no strike, which is the gamble.

**Rock visibility is a balance axis**, available only because the take is a
real-time read. An obvious rock can carry a nastier effect because the batter
can bail (burning a club and a strike); a subtle rock must be milder because
you commit before you know. Use this instead of nerfing effects.

**One angle rock is enough for now** (the bouncer). A left/right BIAS rock may
be added later. The floater was CUT: one air club against four ground clubs
means a rock countering only the air club is dead by construction, and SMAK's
counter is the deep scheme, not a rock. The dirt-biter stays but becomes rare
and very visible in flight, so the batter can bail.

**Rock roster (9):** plain (empty slot) · light-and-lively (starter junk) ·
heavy (distance: everything falls a step short) · dirt-biter (distance: kills
roll; RARE + very visible) · bouncer (angle: random, ruins the thrower's own
read too) · left spinner + right spinner (angle: predictable bias) · sticky
(risk: obvious, swing and lose that club) · sharp (risk: subtle, swing and the
club weakens). "Brittle" was proposed and CUT in favour of the spinners.

**Spinners are a readable skill test:** the spin direction IS visible, and the
batter must see it and compensate with his timing to get a good hit. A new
player plays safe up the middle; an experienced one reads the direction and
turns it around. Skill ceiling that costs only art.

**FEATURE (fun, zero gameplay impact): foul balls hit the background.** Fouls
leave the field and strike things in the surroundings, which react. Turns the
game's only dead outcome into a small reward. Consider damage accumulating
across a season.

**Card-economy deadlock rule (confirmed):** when both sides run out of cards
in an at-bat, it falls back to baseline swings against plain rocks until it
resolves normally. This caps how oppressive an all-risk-rock loadout can be.

**Rocks pick which club family they punish** — a rock that doesn't carry guts
the air club; a rock that dies on the dirt guts the ground clubs. This is what
gives the ball card a job beyond "how hard can it be hit", and it broke the
~18-distinct-ball ceiling that was pushing us toward filler cards.

**Risk rocks** (cap at ~3, rare): punish a swing, give up the free strike.
They attack the CLUB economy rather than the count — take one and you burn a
club for no strike progress, which pushes the batter toward baseline swings.
e.g. sticky rock — swing and that club is gummed up for the rest of the at-bat;
let it go and it is NOT a strike. Countered by a flat stone club nothing sticks
to, and by an item that reveals the rock.

**At-bat loop (the user's design, and the best idea in the conversation):**
before the game you load each batter with 3 clubs. At the at-bat you commit one
club BLIND, then the scheme is revealed, then you swing or take the strike.
The ROCK IS VISIBLE IN FLIGHT (corrected 2026-09-18) — seeing the rock and
the scheme during the pitch is exactly when the take-the-strike decision
happens, so taking is simply NOT TAPPING, no button needed. This kills the
"see which rock is coming" item; spy-on-defence survives because seeing the
scheme BEFORE committing a club is still information you cannot otherwise buy. Two rules it needs: taking re-rolls the scheme (else
taking is free reconnaissance) and taking burns the club too (else the tension
evaporates). Three clubs, three strikes.

**DECISION 2026-09-17: full per-runner base running.** Not a single
"bases earned" number — each runner is resolved by the actual throw distance
from where the ball was fielded to the base they are heading for. A ball
fielded at third is 0 paces from third and 18 from first, so the lead runner is
dead and the batter is safe, with no special-casing. Chosen over a coarse
angle rule because the geometry is already computed and the cheap version
produces moments that feel wrong.

**Why that decision matters beyond realism:** it is what makes tap-to-field
worth playing. With nobody on base, tapping a fielder then throwing to first is
a dexterity check with no choice in it. With runners, choosing WHICH base is
the whole decision. Tap-to-field and base running need each other.

**LOCKED 2026-09-17, do not revisit: 3 slots per batter, always.** One card
per swing, max 3 swings per at-bat, so cards and strikes map 1:1. Clubs and
items share those three slots — a batter can carry three clubs, or two clubs
and an item.

**LOCKED: player stats are speed and power only.** Speed is fast/average/slow
and also governs how much ground he covers fielding. Power multiplies ball
speed and distance, hitting AND throwing. Three archetypes: fast/weak,
average/average, slow/strong. Differences deliberately SMALL — this shifts
fielding gaps and adds strategy, it is not a stat check.

**Teams are 5 players.** 5 x 3 slots = a 15-card loadout.

**Teams:** thrower + 3 fielders + a catcher on defence; all 5 bat. The catcher
(the Mighty man) stands behind the plate, guards home and never chases
(`FielderSpec.chases == false`, see `lib/sim/fielder_spec.dart` and the
viewport note). He replaces the earlier DH idea: the slow/strong archetype
still lives in the one slot that never runs after the ball.

**LOCKED: the defensive loop.** Ball is hit -> player taps ONE fielder to chase
it -> the other three automatically cover a base each (4 defenders, 1 chases,
3 bases, exact 1:1) -> player taps the BASE to throw to. Cover men have real
travel time, so an out needs the throw to beat the runner AND the cover man to
beat the throw; throw to a bag nobody reached and it sails through. Base
assignment is solved as a set for best overall coverage, not each man grabbing
his own nearest. Tapping a fielder is therefore two decisions at once: who gets
the ball, and who is no longer covering.

**Items cost you the specialisation, not the swing.** Playing an item uses
that slot and that pitch, and you swing the BASELINE club instead of a
specialised one. (This supersedes an earlier "bare hands" rule — the baseline
club replaced it.) An item must therefore be worth about a third of an at-bat,
which disqualifies most minor utility effects.

**Baseline club replaces the bare-hands idea.** An average, mid-range,
any-angle swing happens by default. A club card specialises it; a modifier
card still swings, just at baseline. So every pitch produces a real swing and
the mid club is redundant — it IS the baseline.

**A whole game:** 3 innings / 6 half-innings / 3 outs. Roughly 4 batters a
half, ~2 pitches a batter, so about 50 pitches split evenly between batting
and fielding, ~15 of which become tap-to-field plays. Around 12-15 minutes.

**LOCKED: loadouts persist between games** and are tweaked, not rebuilt. 30
slots of setup before every game would be a longer chore than the game.

**Defensive dead pitches** (you pick a rock and a scheme, then the batter takes
or misses and you had no input) are handled by making the choice FAST — scheme
is a persistent dial you often leave alone, rock is one tap. Deliberately NOT
by giving the thrower a timing tap, which would add a third defensive variable.

**Skill-pitch rock (idea, 2026-09-27):** a rock that raises a timing meter for
the THROWER; hit the window and the pitch is hard to hit (fast — less time for
the batter to read rock and scheme). Acceptable where a universal release-tap
was rejected, because it is a CARD: scarce, chosen, not a fourth variable on
every pitch. Missing the meter must hurt (a fat pitch) or it is a free bonus.
It is the mirror of the Nok Noggin item, which slows the pitch down. Its real
value is PACING — quick-quick-quick-BIG beats a flat row of fast choices.

**SEASON STRUCTURE (decided 2026-09-27): a league ladder, NOT a roguelite.**
Full season every time, ending in a small playoff. Winning the playoff gives
the best reward. Making the playoff promotes you to a harder league; losing a
certain number of games relegates you. Leagues run from a deliberately
wimpy-sounding bottom tier upward. **Cards are kept in all cases** — there is
no run reset and no permadeath.

Difficulty scales on three axes as leagues rise: fuller opponent loadouts
(cheap to build), quicker fielding, smarter AI (expensive). Relegation is what
keeps the curve honest — the player settles at their natural level instead of
the designer having to predict it.

**Season length: 10 games plus a playoff.**

**Card levels (stone / copper / bronze), unlocked from season 2 on.** Upgrading
makes a card's ability MORE EXTREME rather than simply stronger. This is the
answer to the structural problem that cards are never thinned, so growth ends
early and only curation remains — levels give later rewards somewhere to go
without adding dead content.

CORRECTED: upgrades DO increase absolute power, not just extremity. Claude
argued for "sharpen both edges" and was wrong — that is roguelite logic, where
only relative balance matters. This is a persistent ladder where the player's
whole team AND the opponents scale, so absolute growth is required to keep
pace. Counters stay counters because they scale too.

The real constraint is therefore: UPGRADE MAGNITUDES MUST BE COMPARABLE across
the roster, and the matchup matrix must be re-run PER TIER (stone vs stone,
bronze vs bronze) to confirm counters survive at every level. A card whose
bronze tier is 2x while another's is 1.1x is what actually breaks the matrix.

**Card upgrades come from two sources:** bought with currency, AND found
randomly at the end of a match. So upgrading is not purely a wallet function —
playing produces them too, which protects the free path.

**Card tiers are gated by ages** — stronger cards require being enough seasons
in, so time gates power alongside cost.

**Currency:** a purchasable currency buys upgrades and players. Notes: this is
a single-player ladder vs AI, so it accelerates rather than beats other humans;
relegation self-limits bought power; the free path must stand on its own; and
anything purchasable should also be earnable — purchase buys TIME, never
exclusivity.

**Uniforms are INFORMATION DESIGN, not cosmetics.** They show at a glance
which archetype each player is — critical because tap-to-field is the one
time-pressured decision in the game and you must know who is fast without
thinking. Uniforms get more elaborate as a player's tier rises, so you can SEE
what you paid for. The cosmetic purchase is WHICH archetype items appear, with
identical effect to the free version.

Protecting hierarchy: ARCHETYPE reads first (silhouette + colour, the only
things that survive at phone size in motion); TIER reads second (ornament,
detail). Purchased variants change ornament ONLY, never silhouette — selling
someone a way to misread their own fast man would break the whole point.

**Playoff win = a rare player offer.** The right top reward structurally: the
5 player slots are ALWAYS full, so gaining one forces a cut, whereas a card
just fills an empty slot. Caution: this collides with the locked "player stat
differences are deliberately SMALL, not a stat check". Resolve it by making a
rare player a MORE EXTREME archetype (very fast/very weak, very slow/very
strong) rather than strictly better — rarity as specialisation, same principle
as the cards.

**SKILL IS AIMING, NOT ZEROING (learned 2026-10-03).** Once power stopped
falling off with angle, perfect timing stopped being the goal — swinging
deliberately early or late is now FREE, so a good player aims at a hole.
Every balance tool that models player skill as gaussian error around ZERO is
measuring accuracy at hitting dead centre, which is the one spot all five
schemes guard; it will report the skill curve as INVERTED. Model the player as
picking the biggest gap in the revealed scheme and executing to within his
accuracy (see bestAngleFor in tool/game_report.dart).

**FOUR bags, four cover men (catcher on home).** One man chases, the other four
cover first, second, third and home, so no bag is left open. (Superseded: the
earlier no-catcher design had three cover men and always left one bag open.) Coverage is assigned to the bags
runners are actually heading for, nearest-to-scoring first.

**Progression target: 3/4 of slots filled** by the end of a strong run, i.e.
about 11 of 15. Not all fifteen — the average swing should never disappear.

**REQUIREMENT: no scheme may blank the baseline club with the bases empty.**
Hitting to third, into any coverage gap, or at a slow fielder must all be able
to get the batter on first. Strategy arrives once there is a runner on, not
before. Check with tool/baseline_check.dart.

**Base running is automatic, not a card.** Runners take the extra base when
the geometry and their speed allow it. Keeping it emergent avoids stacking
another decision layer on the pitch.

**Offence variety lives in items, not clubs.** With only 5-6 clubs, items carry
the ~20-option target. Items bend RULES, never physics — that is why they are
explainable where swing cards were not. Swing cards are to be deleted.

Related: [[caveman_baseball_project]].
