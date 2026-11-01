# Editing animations in Godot

Since 2026-11-01 every character animation and every animated effect is a Godot `SpriteFrames` resource the game plays from, and
every frame can be repainted by hand.

## Watch

- `presentation/library/animation_gallery.tscn`: every animation looping in the editor's 2D view. Characters and effects play with
  your order and timing from their `SpriteFrames`; the few without one at the gallery's `ticks_per_frame`. Inspector: `filter`, `speed`, `playing`,
  `facing_left`, `reload` (after editing a resource or rebuilding art).
- `presentation/library/warden_gallery.tscn`: the Warden with its attacks, effects and particles.

## Change frame order and timing

Open a set in `presentation/animations/`: `hero2.tres` (katana hero), `totoy_dagger.tres`, `totoy_lightning.tres`,
`totoy_scythe.tres`, `totoy_unarmed.tres`, `golem2.tres` (arena boss), `warden.tres`, `stag.tres`, `boar.tres`, `mossling.tres`,
`glowmoth.tres`, `npc_<name>.tres`. Godot opens the SpriteFrames panel at the bottom. Then:

| You change | The game shows |
|---|---|
| **Speed (FPS)** of an animation | every frame of it shorter or longer |
| A frame's **duration** (the number under the frame) | that frame alone shorter or longer (NPC idles already use this) |
| **Loop** on or off | a free-running animation loops or holds its last frame |
| Frame **order** (drag), **remove** a frame, **repeat** one (copy and paste) | that sequence |
| **Add** a frame: drag a PNG from `art/build/sprites/` into the animation | that frame, in that place |

Save (Ctrl+S). The galleries show it after `reload`; the game on its next run.

**Paced by the combat, not by you** (their frames and order are yours, their speed is not): the hero's swings (`attack1`-`attack4`),
`dash`, `parry` recovery and the Stone Ward poses; every attack wind-up and strike (`*_tell`, `*_strike`, the Thornback's slam, the
golem's attack poses); deaths of mobs. Their length comes from the core's timing, so a hit lands on the frame it should. Changing
their FPS does nothing; change the order or the frames.

A mob state that plays a pose at a pace of its own (the Thornback's quick startled idle, the boar's and mossling's looping stun)
keeps that pace and uses your frames.

## Effects

`presentation/animations/effects/fx_<family>.tres`, one per effect family, an animation per effect: `fx_lantern.tres` holds
`place`, `pulse`, `fade`, `pool_open`, ...; `fx_ward.tres` holds `cracks`, `shockwave`, `block`, `absorb`; `fx_warden2.tres` the
Warden's attack effects; `fx_stag.tres` the Thornback's; a family's own sequence (`fx_counter`, `fx_parry`) is the animation `play`.

- **Frame order: every effect.** Reorder, remove or repeat frames and the game shows them in that order. (How it works: the game's
  frame table is rewritten when it loads, so an effect that asks for its frame n gets the frame you put at n. An effect never asks
  for more frames than its art had, so adding frames does nothing there, except for the effects below.)
- **Timing too, for 30 effects** that run on per-frame tick lists: `fx_lantern` (place, pulse, fade, pool_open, pool_pulse, motes,
  spark), `fx_phantom` (start, end, spark), `fx_lightning` (spark, blink, strike, ground), `fx_chain` (hook, land, stagger, dust,
  scuff), `fx_echo` (place, vanish, trail_head, arrive, dust), `fx_ward` (absorb, block, shockwave, cracks), `fx_sprint` (start,
  end). Speed and per-frame durations change the frames AND how long the effect stays (its life is the sum), and frames you add
  play.
- **The other effects keep the code's pace** (their frame is worked out from their age: the parry and hit bursts, the dash, the
  auras, the Warden's and the Thornback's attack effects, ...). Their speed in the resource does nothing; change their order or
  frames.
- Hero-frame overlays (the Phantom glow, the echo shield outline, the sprint aura) follow the hero's own frames, so they are not
  separate animations: edit the hero animation.

## Repaint a frame

1. Copy the frame from `art/build/sprites/<frame>.png` to `art/overrides/<frame>.png` (same name).
2. Paint it in any editor (Aseprite, Krita, ...). Keep the canvas size so the feet stay put.
3. `python tools/art/build_art.py` (then validate and preview as usual). The build uses your PNG instead of the generated frame, every
   time, and says how many it took from `art/overrides`. It snaps your colours to Totoy 36 and makes every pixel fully opaque or
   fully transparent, so soft brushes are fine but they come out hard-edged.

Delete the file from `art/overrides` to get the generated frame back. A file whose name matches no frame is reported.

## When new art arrives

New frames (a re-rig, a new import) appear in `art/build/sprites/` after `build_art.py`. To put new animations into the resources:

```powershell
$godot = "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --import --quit
& $godot --headless --path . --script res://tools/godot/generate_sprite_frames.gd
```

It keeps everything you edited and only adds the animations that are new; frames whose PNG is gone are dropped. To throw your edits
away and start a set again from the code's tables, delete its `.tres` (or pass `-- --reset` for all of them). If a re-rig changes an
animation's frame count, add or remove those frames in the resource yourself (or delete the animation and run the generator).

## How it works

- `presentation/common/anim_library.gd` reads the resources: per animation, the frame names in order, each frame's ticks
  (`60 / speed * duration`) and the loop flag. A set or animation with no resource uses the code's old tables.
- The game still picks which animation plays and when it starts from the core's state (`presentation/arena/animation.gd`,
  `presentation/explore/mob_view.gd`, `explore_scene.gd` for the unarmed hero and NPCs); only the frames and the free-running
  timing come from the resources.
- `tests/smoke_anim_library.gd` checks every resource loads, every frame is a built sprite and every animation stays in range. It
  does not pin timings: those are yours.
