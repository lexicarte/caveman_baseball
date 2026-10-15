# Design notes

Working notes kept alongside the code: what was measured, what was decided,
and what is still owed. They are written to be re-read before touching the
thing they describe, so most of them lead with the mistake that made the
note necessary.


- [Caveman Baseball project](caveman_baseball_project.md) — deckbuilding ground-ball baseball; engine choice, balance findings that are easy to re-break, and the tool-driven tuning workflow.

- [Design decisions](caveman_baseball_design.md) — club roster, the club/timing/scheme split, at-bat loop, and full per-runner base running.

- [Portrait vs landscape](caveman_baseball_viewport.md) — measured viewport ceiling; no defensive scheme clears a 44pt tap target in portrait.

- [Scheme standings](caveman_baseball_schemes.md) — measured: LINE loses to SMAK every time, WIDE is WHEEL with one extra trick.

- [Art direction](caveman_baseball_art.md) — two live candidates (pixel art, flat cartoon), both built at the same camera, plus the scale/field-legibility rules any style must obey.

- [Animation](caveman_baseball_animation.md) — the workbench entry point, the Pose API, and the foot-slip arithmetic a run cycle must satisfy.

- [Base geometry](caveman_baseball_base_geometry.md) — RESOLVED: second base squared up and the mound's two numbers reconciled; the balance recheck is still owed.

- [Fake 3D projection](caveman_baseball_projection.md) — one divisor in Ground is the whole camera; what it bought and the three things it broke.

- [Tuning bench](caveman_baseball_tuning.md) — the Look layer, the three-tab bench, and the rule that keeps look dials out of the simulation.

- [Look first, analytics later](caveman_baseball_look_first.md) — don't block or follow every visual change with the balance tools; numbers are fakeable, the look is not.
