# Gemini presentation migration

Branch: `agent/art/gemini-import`. No core, tool, source art, or generated atlas changes. Old frames remain available. This handoff is here because this task restricts edits to presentation and tests (plus explicitly requested arena screenshots); docs/STATUS.md was left unchanged.

## Mapping and cadence

All actors use sprites.json feet anchors; left-facing hero frames mirror around that anchor. Head anchors are measured from every golem2 frame using the existing silhouette measurement. Core hitboxes and exact warning geometry remain unchanged. The larger body is decorative and does not enlarge damage areas; arena_gemini_hitboxes.png exposes the existing radii for review.

Hero: idle 4 at 12 ticks/frame; walk 6 at 5; dash 4 at 1 (the core dash lasts 6 ticks, final frame holds); parry 6 at 2, recovery holds frame 6. There is no combo index in EntitySnapshot, so attack1 frames 1–2 are windup (4 ticks/frame), 3–4 active (2), 5–6 recovery (5). Damage events play hurt 4 at 3; defeat holds hurt 4 because no hero death art exists. Victory plays 6 at 8 using result_ticks.

Golem: idle 4 at 16; walk 6 at 5 is supported although the current core has no walk state. gold_slam and gold_combo use slam; red_sweep uses sweep; red_stomp uses stomp; red_charge uses charge; red_shards uses beam. Windups select 1–3 from telegraph progress; frame 4 begins exactly at hit_tick, then 5–6 at 3 ticks/frame including recovery. Combo timing uses the preceding strike hold before re-raising, independently of telegraph array order. Posture break uses staggered 4 at 8; damage uses hurt 4 at 3; phase events use roar 6 at 5; death uses 8 at 6 from result_ticks. Reactions never override death, posture break, dash, or an active boss impact.

Imported impact textures are clipped to the core circle/cone/ring geometry; stomp leaves its safe centre empty. Beam body repeats along the line, with start/end pieces. Exact capsule warning boundaries remain visible, including rounded end caps. Slam landing dust, charge dust, dash trails, hit/counter/parry and warning icons use imported art. The small supplemental particles, white damage silhouette and exact geometric warning boundaries remain. The existing geometry plans remain available for smoke assertions. Imported FX artwork has irregular opaque edges: the warning outline remains the authority for the full hit area.

HUD: ui_profile at 156x60, portrait retained from totoy_portrait, live HP/Edge/dash meters fitted to its openings; ui_boss at 104x24 with live HP/posture and counter prompt. Imported edge/dash/parry icons and animated red/gold warning icons. Four anchored, collision-free edge props; selected sources contain no reserved combat colours.

## Verification and review

Installed Godot reports 4.7.2.stable.official.ed1daf0bf. `python tools/art/validate_art.py`: pass (369 sources, 371 built PNGs). `python harness/checks/run_tests.py --worktree . --timeout 45`: all suites pass, including Python, Godot import, core tests and smoke_animation, smoke_arena, smoke_boss_attacks, smoke_effects, smoke_golem, smoke_new_hero, smoke_profile and smoke_project.

Windowed `tests/smoke_gemini_capture.gd`: pass. Review images in art/build/arena_gemini_*.png: hero walk, attack, parry; golem slam, staggered, death; HUD and debug hitboxes. These are labelled snapshot fixtures rendered through production presentation, not evidence of animation feel. No missing requested atlas frames were found. No judgement of art quality, readability in motion, animation feel or fun is possible here; the human approves those.

Claude cross-review remains pending: three read-only CLI attempts (sandboxed, escalated, then a minimal no-plugin invocation) returned no review output and were interrupted. No pass/fail result was obtained. This does not constitute the required cross-review or human art approval. Nothing was merged.
