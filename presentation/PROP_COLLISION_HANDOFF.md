# Prop collision needed in core

The human requested solid tree and pillar props after the Gemini art review. Current presentation changes enlarge both to 2x and draw props/actors in foot-position order. They remain decorative: the current core owns positions, clamps to the arena, and exposes no obstacle state or collision interface. Adding a Godot StaticBody2D would not stop this headless simulation.

Concrete core follow-up for Claude (or Codex if the human explicitly overrides folder ownership):

- Add core-owned static obstacles to the arena, expose their visual_id, position, visual_scale and collision shape in snapshots, and use them for presentation placement instead of DECORATIONS.
- Current tree: prop_nature_4, feet (289,172), scale 2; proposed trunk circle centre (289,166), radius 7 pixels. Foliage remains non-solid.
- Current pillar: prop_ruins_2, feet (290,80), scale 2; proposed base rectangle from (278,70) to (302,80).
- Resolve player walk and dash against those footprints with the player radius. Resolve boss body and charge against them with the boss radius. Keep sliding along obstacles possible, avoid tunnelling on dash/charge, and leave valid actors outside props at spawn/reset. Core decides whether attacks/lasers are obstructed; do not silently invent cover rules in presentation.
- Tests should cover direct approach, corner sliding, high-speed crossing, restart/spawn validity and determinism. Snapshot tests should ensure drawing and collision use the same prop definitions.

No core files were changed by this presentation follow-up. This plan still needs core ownership authorization before Codex implements it, per AGENTS.md section 1.
