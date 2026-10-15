---
name: caveman-baseball-projection
description: The fake 3D — one divisor in Ground turns the flat shear into a camera set back behind the plate, and the three things it quietly broke.
metadata:
  type: project
---

Built 2026-10-11, asked for as "a fake 3D view, giving the illusion that
the camera moves slightly down to give an angle that is both zoomed in on
the pitcher/batter, but shows the outfield orientation as well."

## The whole thing is one factor

`lib/game/ground.dart`:

```dart
k(d) = camDepth / (camDepth + d)        // depthScale
x(fx, d) = fx * k(d)
y(d)     = plateY - squash * d * k(d)
```

The camera sits `camDepth` paces BEHIND home plate. The projection is the
old flat shear with `d` replaced by `d * k(d)`. That one substitution buys
all three cues at once — foul lines CONVERGE, deep field COMPRESSES, far
men are DRAWN SMALLER — and as `camDepth` goes to infinity `k` goes to 1
and it is exactly the shear it replaced. **One dial spans both looks, so
there is no second mode and no way for the two to disagree.**

Inverse (for turning a tap back into a place on the field): depth FIRST,
because how many paces across a tap is worth depends on how far down the
field it landed. `fieldY` returns infinity at or above the horizon.

Shipped: `camDepth 38`, `squash 0.70`. Horizon at `plateY - squash *
camDepth` = -12.1. A man at the wall renders at 50% of one at the plate.
`test/projection_test.dart` locks all of it.

## Three things it broke that were not obvious

1. **The sky vanished.** The true horizon is a long way off the top of the
   frame, so drawing sky above it meant the player only ever saw an
   enormous apron of desert floor. `FieldComponent._skyline` is a PAINTED
   backdrop just behind the wall — the wall occludes the horizon here, as
   a real outfield wall does. Not `Ground.horizonY`, which is still right
   and still used for the maths.
2. **The mesas became a brown slab.** They were laid out in absolute
   paces when the wall was 56 render units across; the wall is now 28.
   Everything on the backdrop is multiplied by `_backdrop` =
   `depthScale(wallRadius)`, which keeps it proportionate to the wall.
3. **`modelScaleFor` divided by `figureHeightWide`** — a CAMERA setting.
   Re-aiming the fielding view therefore resized every bag and the rock,
   and the rock came out nearly as big as the thrower. It now divides by
   `Ground.modelsDrawnAgainst`, a const 4.6, which is the man-height the
   models were actually drawn against. A test asserts model size does not
   follow the camera.

## The fielding camera had to be re-aimed

Perspective pulls the wall from 26.6 render units deep to 13.3, so the
field occupies about a quarter of the area it did. `wideZoom` 1.0 -> 2.2,
`wideLook` -4.5 -> 7.1, and `figureHeightWide` 4.6 -> 2.1 by the same
arithmetic (a man stays the same fraction of the SCREEN). The field's
SHAPE did not change — perspective or shear, it is about 2:1, wide and
shallow, against a portrait band that is tall and narrow.

## What a man's height means now

`Ground.figureHeightAt(zoom, fieldY)` — the zoom sets the near size, the
distance does the rest. **Per MAN, not per frame.** `figureHeightFor(zoom)`
alone is now only correct at the plate. Same for `modelScaleAt`,
`arcHeight(travelled, carry, atFieldY)` and the rock's radius.

`rockLift` was re-derived while this landed: anchored at the thrower's
hand (which is lower because he is drawn smaller) and at the bat's height
at the contact depth, instead of being computed from the shear. Equivalent
under the old projection, correct under this one. `lib/game/calibration.dart`
holds the same derivation and a test pins them together.

See [[caveman-baseball-tuning]] for the dials, and
[[caveman-baseball-look-first]] for why none of this went through the
balance tools.
