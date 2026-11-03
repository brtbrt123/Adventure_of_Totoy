# Mobile blueprint (proposal)

The owner asked on 2026-11-02: "make a blueprint for how it is gonna look if we do a mobile". This is a proposal for review. Nothing in the game changes yet.

The picture is `art/reference/mobile_v1/mobile_blueprint.png`, made by `tools/art/mobile_blueprint.py` from two captures of the real game. `presentation/review/mobile/capture_mobile_view.gd` takes both, and the inputs are kept in `art/reference/mobile_v1/source/`:
- a phone-shaped view (20:9, expand aspect, desktop HUD hidden);
- the desktop HUD alone, over magenta.

## Screen

- Landscape only.
- The game keeps whole-number (integer) pixel scaling.
- Stretch aspect "expand": a 20:9 phone sees 480 x 216 game px, i.e. more world to the sides. A 16:9 screen sees 384 x 216, as on PC.
- On a 2400 x 1080 phone the scale is 5. Tablets use the same layout at a bigger whole scale.
- The HUD is anchored to the corners, inside the display's safe area (notches, rounded corners).

## Touch layout

Sizes are for a 6.5 inch 20:9 phone, where 1 game px is about 0.31 mm. A touch target should be at least 7 mm (about 22 game px).

| Control | Place | Size |
|---|---|---|
| Move: floating stick | Left thumb. It appears where the thumb lands in the left 40% below the HUD band. | 56 px base, 18 mm |
| Attack: the weapon medallion | The right thumb's rest. Tap to swing, hold to keep the combo going. | 46 px, 14 mm |
| Parry: the gold diamond | Inner ring, left of Attack. The thumb rolls onto it. | 32 px, 10 mm |
| Dash | Inner ring, up-left of Attack | 28 px, 9 mm |
| Weapon skill (right click on PC) | Inner ring, above Attack. Its ring shows Edge. | 30 px, 9 mm |
| Aspects Z, X, C | Outer ring. They are the real HUD slots, with cooldowns as on PC. | 37 px, 12 mm |
| Items 1 and 2 | Left edge, above the stick | 26 px, 8 mm |
| Pause / character menu (Tab on PC) | Top-right corner | 22 px, 7 mm |
| Interact (E on PC) | A bubble over the person or object; tap it. Dialogue: tap anywhere to go on. | 17 px, 5 mm (still to settle) |

The HUD moves to the top, because the thumbs cover the bottom corners:
- the health, Edge and Dash bars go to the top left;
- the EXP pillar becomes its level shield, with the full bar in the menu;
- the wave or objective stays top centre;
- rewards pop in under the pause button.

The fight in the middle of the screen stays clear.

## What it takes

- **No rule changes.** The core already takes one `InputFrame`: move, attack (press and hold), parry, dash, weapon active, skill 1-3, interact and item slot. A touch layer in presentation fills it.
- **Aiming.** It already follows movement, with no mouse aim, so touch needs no aim stick.
- **Menus.** The character menu and dialogues need big touch targets: tabs as buttons instead of Q/E, and "tap to continue".
- **Export.** Android and iOS. The `gl_compatibility` renderer runs on mobile (OpenGL ES 3). Add a quality switch for the lighting and particles on older phones, and haptics on parries and hits.

## Open questions for the owner

- A wider parry window on touch? There is no key to feel. Now it is 14 ticks, perfect within 6.
- Should the floating stick also allow a fixed stick (a settings option)?
- Should the key letters stay on the Z/X/C diamonds on touch, or go?
- The interact bubble is drawn 17 px across (5 mm). To reach the 7 mm minimum it needs to be about 22 px, or the whole person or object should count as the tap target.
