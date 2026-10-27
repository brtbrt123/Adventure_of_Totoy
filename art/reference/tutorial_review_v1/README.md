# Village tutorial and dialogue review

Windowed Godot 4.7.2 captures from `tests/capture_village_tutorial.gd`, for both painted and layered villages at 1280x720. Existing portrait sheet and HUD fonts/panel reused, no generated or reimported source art.

- `*_controls.png`: first-visit controls card.
- `*_dialogue.png`: Mira opening line, fully revealed for readability.
- `*_gold.png` / `*_red.png`: core warning snapshots, ten ticks before impact. The capture fixture seeds `met_tovan`, `lesson_dash`, `lesson_attack` and then `lesson_parry` to show each prompt. These screenshots do not prove progression.
- `*_post_hit.png`: impact tick, event sparks/post reaction.

`tests/smoke_village_tutorial.gd` separately earns all four lessons through real exploration input and checks saved flags. Human approval of appearance, teaching quality and gameplay feel remains pending. See newest STATUS for the core combo snapshot finding.
