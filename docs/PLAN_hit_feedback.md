# Hit feedback: damage numbers, health bars, kills (PLAN and progress)

The owner sent a TikTok devlog (2026-11-28, `data/audio_candidates/6fe4eeb6-58d7-4bd9-8d54-995c3258637f.mp4`; someone else's video:
reference only, never committed): "i like the damage text, and the mob health bar, i also like when he kills the mobs it feels
satisfying can we implement it?". Frames were read with the ffmpeg that Free Download Manager installed
(`C:\Program Files\Softdeluxe\Free Download Manager\ffmpeg.exe`; ffmpeg is not on PATH).

What the reference does: chunky damage numbers popping on every hit and stacking (bigger, yellow ones for big hits), a "x12 HITS"
counter by the player, a small bar with a level box over each enemy, a target bar at the top (name, level) whose lost health shows
as a white chunk that drains, and kills that react to what killed (a sword slices the enemy in half, fire leaves ash, ice shatters),
with a flash, shake and flying bits. The game had a basic version of each: small 8 px numbers merged per target
(`presentation/explore/encounter_effects.gd`), the small bar and level (`MobView.decorate`), a 24 px puff on a kill.

Colour rule kept: gold is the parry cue and red the dodge cue, so big numbers are bigger and brighter in cream and the song's blue
(not yellow), and kill debris will be sap, dirt and leaves (not red blood).

## Part 1 and 2: numbers, hit counter, the mob bar and level (2026-11-28, wired: "Yes, wire them")

First round: numbers, hit counter, the drain on the small bars and a target bar at the top (name, level, health). The owner: "remove
the hp bar at the top of the screen just improve the healthbar and lvl design on the top of the mob". So the target bar is gone
(its files were deleted before any commit) and the bar over each mob is redesigned. The real implementation, plugged into the game
only by the capture until the owner says yes:
- `presentation/explore/hit_numbers.gd`: every hero hit pops its own number in a bold 5x7 pixel font of its own (outlined in ink,
  cached as textures): a normal hit in cream pops one size bigger for 3 ticks, then rises 16 px and fades (42 ticks); hits on the same
  mob scatter round the first; a counter (exposed mob) is big pale blue, the killing blow big near-white. "xN HITS" by Totoy counts
  his hits while they come within 90 ticks of each other and hops 2 px on each.
- `MobView.draw_bar` (`presentation/explore/mob_view.gd`, on while `MobView.new_bars`, off by default): the level as a bare number in a
  framed badge (ink, copper rim, dark inside, cream 3x5 digits) joined to the left of a 34 px bar (58 for bosses): ink outline, a
  copper rim lit above and shaded below, a dark back, the fill bevelled in three greens, the health just lost as a cream chunk.
  Shown when it did before (damaged, or the hero within 72 px); a summoned moth shows no badge.
- `presentation/explore/bar_drain.gd`: keeps `MobView.ghosts`: a mob's lost health lingers 18 ticks, then drains 3 % of its full
  health a tick (as the boss panel's ghost does).

Pictures: `presentation/review/hit_feedback/capture_hits.gd` (windowed; `-- --before` is the game now, no flag plugs the new pieces
in; the same real fight with real inputs in the forest, Mosslings then Ashback Boars) and `tools/art/make_hit_feedback_gif.py`:
`hit_feedback_before_after.gif` (now, proposed, slowed; 18 MB, may stay out of git), `hit_feedback_now_vs_proposed.png` and
`mob_bars_closeup.png` (the bars at 4x, now and new).

Wired on the owner's "Yes, wire them": `explore_scene.gd` creates `hit_numbers` (a child node, drawn over the world) and
`bar_drain`, clears them with the scene, syncs them every tick and hands `hit_numbers` every event; `MobView.decorate` always draws
the new bar (the old copper `Kit.bar` and the floating "L1" label are gone, `new_bars` with them); `encounter_effects.gd` no longer
makes numbers for Totoy's hits (his own damage and heals keep its numbers). `tests/smoke_hit_feedback.gd`: a real forest fight
(numbers pop per hit, a kill pops as a kill, the counter counts, a hurt mob's bar shows the drain, no old mob numbers). The wired
game, recorded with the same inputs (`capture_hits.gd` now records `wired/`), matches the approved run in all 280 pictures, pixel
for pixel.

## Part 3: kills (next)

The killing blow's `attack_hit` event carries `weapon_id` / `skill_id`, so no core change is needed: blades (katana, daggers,
scythe, Moon Cleave, Gale Cut, Phantom Cut ...) slice the mob in two along the swing, lightning burns it to crumbling ash; every kill
a flash and a short shake; optional hit-stop (3 to 4 frames frozen on a kill), shown with and without for the owner to decide.
