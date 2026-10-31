# Codex task: the Hollow Trial room (art, effects, UI, sound) (2026-10-31)

Design: `docs/PLAN_hollow_trial.md` (read it first). The owner's idea: a **dead-end room behind Root Hollow's upper-left exit**, spacious, with many **glowing rocks, bushes and trees around the sides** and an **altar with a chest in the middle**. Pressing **E at the altar** starts a hard **trial of three waves** (Mossling, Boar and the Runebound Warden). Surviving all three **lights the altar** and lets the hero **open the chest**, which gives an **Aspect** (which one: the owner decides later). Dying ends the try; the hero can retry.

**Split:** you build everything seen and heard (ground painting, props, lighting, effects, UI, sounds, captures, presentation tests). Claude builds the map data, colliders, the trial rules in `core/`, the Root Hollow exit change, and the snapshot/events listed under "Interface". Do not edit `core/` or `data/`; if you need something from the core, write it in your notes. Work the Woodland/Root Hollow way: **ground painting first, then the prop sheet, owner approval at each step**, then import, then wiring. Read `art/reference/root_hollow_v1/` (GROUND_PROMPT.md, PROPS_PROMPT.md, IMPLEMENTATION.md) first: this task repeats that workflow.

## The layout (fixed numbers: Claude's map data uses exactly these)

Guide: **`docs/previews/hollow_trial_v1/walkable_guide.png`** (2x) and the numbers in **`docs/previews/hollow_trial_v1/layout.json`**. Flat green = walkable floor, white line = walkable outline, blue box = the fight floor (keep it clear), cream = altar base, tan = chest base, yellow dots = where the hero stands to use them, lilac dots = mob spawn points, cyan squares = glowing-rock slots, dark green rings = tree slots outside the floor, red = the exit back to Root Hollow, yellow ring = the entry, green square = checkpoint. **A layout guide only: never copy its flat colours, labels or markers into the painting.**

- Scene id `hollow_trial_layered`, **512x352** game pixels, same scale and camera as the other maps, night like Root Hollow.
- **One way in and out:** the bottom edge, x 228-284 (the hero arrives from Root Hollow walking north and enters at the bottom). No other exit: it is a dead end, surrounded by forest.
- **Walkable clearing:** a broad rounded clearing (outline in `layout.json`), about 440x320, dirt and worn grass with old flagstones near the centre. The **fight floor [112, 92, 288x184] stays completely open**: flush ground cover only, nothing that hides a gold or red warning (Boar charges cross it; Warden lines are 150 px long).
- **Altar** in the middle, feet at (256, 180), base about 44x20: an old rune-stone altar, waist high, with a socket ring on top. Two states: **dark** (rune grooves dull) and **lit** (rune grooves teal-white, a soft upward glow). **No gold and no red** (combat cue colours), and keep the lit state teal so it never reads as a warning.
- **Chest** just north of the altar, feet at (256, 136), base about 24x12: an old root-bound chest, **closed** and **open** states, same canvas and anchor. It can reuse the forest chest style if it fits.
- **Rim:** many **glowing rocks** (8 slots, teal rune light like the Root Hollow stones), **bushes** between them, **trees outside the outline** (8 slots) framing the room, roots and ferns at the edges. Spacious inside, dense outside.
- **Entry seal:** the knot of roots that already closes Root Hollow's shortcut (`root_hollow_barrier_closed/open`) is reused at this room's entry: closed while a wave is alive, open otherwise. If it does not fit the bottom edge, propose a matching variant.

## What to make, in order

1. **Ground painting**, **512x352**, ground-only, painted to fit the guide, palette-snapped like the Root Hollow ground. Owner approval.
2. **Prop sheet**: altar dark/lit, chest closed/open, 4-6 glowing rock variants, 3-4 bushes, 2-3 trees (or reuse `root_hollow_*` trees and bushes where they fit), roots and ferns. Shadows and cast-shadow masks as before. Owner approval. Then send Claude the anchors and base sizes (as in `docs/CLAUDE_TASK_root_hollow_prop_registration.md`) so the colliders and placements can be registered.
3. **Lighting and ambience**: night exposure like Root Hollow, teal light sockets on the glowing rocks, the altar's lit glow as a light source once lit, fireflies over the rim (not over the fight floor).
4. **Trial effects** (from the core's events, never invented timing):
   - Altar activation (E pressed): a rune circle spreads from the altar over the floor, the entry roots close.
   - **Spawn warning** at each spawn point before a mob appears (a rune mark and rising spores for about half a second), then the mob arrives (a root/rune burst). Mobs never appear without the warning.
   - **Wave progress on the altar:** three rune segments around the socket, one lights per cleared wave, so the player can read 1/3, 2/3 from the room itself.
   - Wave cleared: a short pulse from the altar, the entry roots open between waves only if the core says so.
   - Trial won: the altar lights fully (lit state), a column of teal light, then the chest is ready (a faint shimmer on its lock).
   - Chest open: the existing chest-open effect, then the existing **Aspect reward card** (`item_received` kind `aspect`).
   - Trial failed (hero falls): the altar dims, the rune circle fades.
5. **UI**: a wave banner ("WAVE 1 / 3", "WAVE 2 / 3", "FINAL WAVE"), "TRIAL COMPLETE", a small "mobs left" readout in the existing fight chip style, the altar hint ("E  Begin the trial", only while idle), the chest hint after a win. Same UI kit and fonts as the rest.
6. **Sound**: altar activate, entry roots close/open, spawn warning, wave start (low horn or drum), wave clear chime, trial complete, trial failed, chest open (exists: `chest_open.wav`). Warnings stay louder than everything else; credits honest as always.
7. **Tests and captures**: smoke test that every frame and effect key used exists; real-renderer captures (no fixtures once the core exists) of: the empty room, the altar dark and lit, a spawn warning, a wave in progress with a Warden, the wave banner, the win, the open chest and reward card. Full harness at the end.

## Interface (built by Claude on 2026-10-31: `core/trial.gd`, contract in `docs/architecture.md` "Trial rooms"; ask if anything is missing)

- Objects in the scene data: `altar` (kind `altar`, stand (256, 204)) and `trial_chest` (kind `chest`, stand (256, 154)); interactions as today (`interact_target`, `interact_kind`).
- Snapshot `trial`: `{state: idle | starting | wave | between | won | failed, wave (1-3), waves 3, alive (mobs left in the wave), next_tick (when the next wave or spawn comes), sealed (entry closed)}`.
- Events: `trial_started`, `trial_spawn_warned` {wave, positions, arrive_tick}, `trial_wave_started` {wave}, `trial_wave_cleared` {wave}, `trial_won`, `trial_failed`, plus the usual `flag_set` (`cleared_hollow_trial`) and `item_received` (the Aspect).
- Prop states: altar `when: "flag:cleared_hollow_trial"` -> lit; chest `when: "flag:trial_chest_opened"` -> open; entry roots `when: "trial:sealed"` -> closed (a new state key Claude adds).
- Mobs come from the core like every encounter (Mossling, Boar, Warden; summoned rules unchanged). Presentation never spawns or positions a rules-bearing mob.

## Not yours / not decided

- Which Aspect the chest gives (owner). The wave contents and numbers (Claude, `docs/PLAN_hollow_trial.md`; first guesses, tuned by play).
- Root Hollow side: Claude retargets the upper-left exit from the village to this room and updates its blocked text; the Root Hollow ground already has the trail north.

Report what you ran and what you could not judge (look, feel, sound are the owner's call). Do not merge to main.
