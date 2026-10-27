# Selected soft moonlit night (2026-10-27)

**The human selected the softer night screenshot and asked to revert the later high-contrast blue treatment. Keep this look unless the human asks for another change.**

Canonical review: `night_selected_on.png`. Its mean RGB difference from the earlier chosen `moonlight_on.png` is below 0.02 on the 0..255 scale (minor shadow-mask edge sampling); the atmosphere, light positions and exposure are restored. Walking reviews: `art/reference/layered_village/review/night_selected/`.

## Separate objects and shadows

All 51 original glade/village prop cut-outs remain pixel-identical. Each has two separate native shadow masks, normal and mirrored (102 `art/src/fx_shadow_*.txt` sources and matching PNGs in art/build/sprites). Object hashes, original anchors, mask names and padded mask anchors are in manifest.json. `layers_final_1..9.png` and featured_layers.png show object / shadow mask / a neutral combined preview.

The selected projection is (+0.30,+0.25) per pixel of height: cool moonlight from above-left, short casts down-right. A flipped object has its own projected mask so the key direction remains fixed. Filled pixel areas avoid gaps. Four transparent guard pixels allow runtime softness without changing hard-alpha source art. PNG masks use palette ink only; no reserved red/gold.

Props draw the separate cast layer beneath their contact shadow. The current hero/NPC animation also projects onto the ground, anchored to the feet in both facings. There is no generic ellipse for prop casts. Actor contact shadows remain small and close to feet.

## Moonlight and lamps

The selected shader uses cool moon colour (village 0.64,0.77,1; glade 0.60,0.79,1), restrained exposure (0.48 + 0.20 patch + 0.07 shaft + 0.03 upper light), and subtle soft shadows. The rejected long opaque casts and silver/white highlight boost are removed. Sprite alpha, nearest filtering and the HUD remain sharp.

Five visible fixtures have their measured light sockets in presentation/common/local_lights.json: the hanging lamp post, the tree lantern, forge fire and two cottage windows. Each supplies a local halo and a warm pool below; source positions follow shared placements and mirroring. Emissive painted cores remain bright. Local lights provide illumination/spill; the moon controls the primary directional casts. These are visual effects only.

Review controls: 5/F7 layered village, 6/F8 layered glade, 7/F9 toggle night lighting. The normal chapter route still uses core's existing painted-scene connections.

## Verification

Art validate/build/preview completed. The separate-shadow test checks source hashes, both masks per object, palette, hard alpha, dimensions, atlas anchors and renderer pairing. The layered smoke checks walking, interactions, east exit, both debug scenes, exact lamp count and lamp-post bulb position, clearing village lamps on entering the glade, cool moon colour, actor anchor attachment and fixed facing-independent projection. Windowed comparison and ten walking captures completed without script/shader errors. Variant atlas checks pass after the final restore. Earlier full background regression runs passed; final restore was checked with the focused scene, art and variant suites. Godot still logs the known system certificate-store message.

No core/data/tools/harness edits. Art strength and gameplay readability in manual play remain the human's judgment; Claude cross-reviews presentation. No merge to main.
