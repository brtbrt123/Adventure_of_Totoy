extends SceneTree
## Writes presentation/animations/<set>.tres, a Godot SpriteFrames per character frame set, for the owner to edit in the editor
## (owner 2026-11-01: "make all of it editable"; the game reads them through presentation/common/anim_library.gd).
##
##   godot --headless --path . --script res://tools/godot/generate_sprite_frames.gd            # after build_art.py and an import
##   godot --headless --path . --script res://tools/godot/generate_sprite_frames.gd -- --reset # rebuild every set from the code tables
##
## Each animation's frames are the built PNGs (art/build/sprites/<set>_<anim>[_right]_<n>.png) in frame order. Speed, per-frame
## durations and looping start from the game's own tables (presentation/arena/animation.gd PLAYER and BOSS, mob_view.gd STATES and
## its pose overrides, the unarmed hero, the NPC manifest's per-frame idle and walk ticks), so the game looks the same until the
## owner changes them.
## An existing resource is the owner's: its animations, frame order, speeds, durations and loop flags are kept. This only adds the
## animations that are new in the art, drops frames whose PNG is gone, and saves only when something changed. --reset ignores them.

const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const MobView := preload("res://presentation/explore/mob_view.gd")
const AnimLib := preload("res://presentation/common/anim_library.gd")
const AspectEffects := preload("res://presentation/arena/aspect_effects.gd")
const LightningEffects := preload("res://presentation/arena/lightning_effects.gd")
const ScytheEffects := preload("res://presentation/arena/scythe_effects.gd")
const WardEchoSprintEffects := preload("res://presentation/arena/ward_echo_sprint_effects.gd")
const Particles := preload("res://presentation/explore/creature_particles.gd")
const ParticleKind := preload("res://presentation/effects/particle_kind.gd")
const ParticleLayer := preload("res://presentation/effects/particle_layer.gd")
const FxSettings := preload("res://presentation/effects/fx_settings.gd")
const OUT: String = "res://presentation/animations/"
const EFFECT_TICKS: int = 3  # an effect sequence without a per-frame tick list in the code (its pace stays in code: order only)
const SPRITES: String = "res://art/build/sprites/"
const DEFAULT_TICKS: int = 6
const NPC_MANIFEST: String = "res://art/build/chapter1_npc_sprites_manifest.json"
## The unarmed hero's table (presentation/explore/explore_scene.gd UNARMED_FRAMES).
const UNARMED: Dictionary = {"idle": [6, 12, true], "walk": [6, 5, true], "dash": [6, 1, false]}
## Poses mob_view.gd picks outside its STATES table: [ticks per frame, loop].
const MOB_EXTRA: Dictionary = {
	"stag": {"breathe": [6, true], "amble": [5, true], "chant": [3, false], "summon": [6, false], "charge_tell": [1, false], "charge_run": [3, true]},
	"mossling": {"hurt": [6, true]},
	"boar": {"charge_tell": [6, false]},
	"warden": {"lash_tell": [1, false], "lash_strike": [1, false], "ring_tell": [1, false], "ring_strike": [1, false], "guard_hit": [5, false],
		"exposed": [8, true]},
}


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var reset: bool = "--reset" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUT)
	var names: Array[String] = []
	for file: String in DirAccess.get_files_at(SPRITES):
		if file.ends_with(".png"):
			names.append(file.get_basename())
	var written: int = 0
	var kept: int = 0
	for set_name: String in sets():
		var anims: Dictionary = animations(set_name, names)
		if anims.is_empty():
			continue
		if write(set_name, anims, defaults(set_name), reset):
			written += 1
		else:
			kept += 1
	# Effects: one resource per family (fx_lantern.tres ...), an animation per animated sequence; the hero-frame overlays (names with
	# _right/_left: Phantom glow, echo shield, sprint aura) follow the hero's frames and are left out.
	DirAccess.make_dir_recursive_absolute(AnimLib.EFFECTS_DIR)
	var families: Dictionary = {}
	var number: RegEx = RegEx.create_from_string("^(fx_.*)_(\\d+)$")
	var counts: Dictionary = {}
	for name: String in names:
		var m: RegExMatch = number.search(name)
		if m == null or m.get_string(1).contains("_right") or m.get_string(1).contains("_left"):
			continue
		counts[m.get_string(1)] = maxi(int(counts.get(m.get_string(1), 0)), int(m.get_string(2)))
	for sequence: String in counts:
		if int(counts[sequence]) < 2:
			continue
		var where: Array[String] = AnimLib.effect_of(sequence)
		if not families.has(where[0]):
			families[where[0]] = {}
		var keys: Array[String] = []
		for n: int in range(1, int(counts[sequence]) + 1):
			keys.append("%s_%d" % [sequence, n])
		families[where[0]][where[1]] = keys
	var timed: Dictionary = effect_timing()
	var paced: Dictionary = effect_paced()
	var effects: int = 0
	for family: String in families:
		var timing: Dictionary = {}
		for anim: String in families[family]:
			var sequence: String = family if anim == "play" else family + "_" + anim
			var spec: Array = paced.get(sequence, paced.get("fx_stag_horn_" if sequence.begins_with("fx_stag_horn_") else "", []))
			if not spec.is_empty():
				var ticks: Array = []
				for i: int in int(spec[0]):
					ticks.append(int(spec[1]))
				timing[anim] = [ticks, bool(spec[2])]
			else:
				timing[anim] = [timed.get(sequence, [EFFECT_TICKS]), false]
		if write(family, families[family], timing, reset, AnimLib.EFFECTS_DIR, true):
			effects += 1
	# Particle burst kinds (presentation/effects/particles/<kind>.tres) and the code-drawn shapes' settings: written once, then the owner's.
	DirAccess.make_dir_recursive_absolute(Particles.KINDS_DIR)
	var kinds: int = 0
	for kind: String in Particles.DEFAULT_LAYERS:
		var path: String = Particles.KINDS_DIR + kind + ".tres"
		if ResourceLoader.exists(path) and not reset:
			continue
		var res: Resource = ParticleKind.new()
		var layers: Array[Resource] = []
		for layer: Dictionary in Particles.DEFAULT_LAYERS[kind]:
			var edit: Resource = ParticleLayer.new()
			edit.call("from_layer", layer)
			layers.append(edit)
		res.set("layers", layers)
		ResourceSaver.save(res, path)
		kinds += 1
	var settings: bool = reset or not ResourceLoader.exists(FxSettings.PATH)
	if settings:
		ResourceSaver.save(FxSettings.new(), FxSettings.PATH)
	print("SPRITE FRAMES OK: %d written, %d unchanged in %s; %d of %d effect families written in %s; %d particle kinds written; settings %s" % [written, kept, OUT, effects, families.size(), AnimLib.EFFECTS_DIR, kinds, "written" if settings else "kept"])
	quit(0)


## Every character frame set (the legacy totoy and mossbound_colossus frames are not used by the game and are left out).
func sets() -> Array[String]:
	var out: Array[String] = [ArenaAnimation.SET_KATANA, ArenaAnimation.SET_DAGGER, ArenaAnimation.SET_LIGHTNING, ArenaAnimation.SET_SCYTHE,
		"totoy_unarmed", "golem2", "warden", "stag", "boar", "mossling", "glowmoth"]
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NPC_MANIFEST))
	for npc: String in Dictionary(manifest.get("states", {})).keys():
		out.append("npc_" + npc)
	return out


## {animation: [frame names in order]} from the built PNG names `<set>_<anim>[_right]_<n>`.
func animations(set_name: String, names: Array[String]) -> Dictionary:
	var numbered: Dictionary = {}
	var pattern: RegEx = RegEx.create_from_string("^" + set_name + "_(.+?)(_right)?_(\\d+)$")
	for name: String in names:
		var m: RegExMatch = pattern.search(name)
		if m == null:
			continue
		var anim: String = m.get_string(1)
		# a longer set (totoy_dagger inside totoy_...) or an NPC's other set never matches: the sets do not share prefixes
		if not numbered.has(anim):
			numbered[anim] = {}
		numbered[anim][int(m.get_string(3))] = name
	var out: Dictionary = {}
	for anim: String in numbered:
		var order: Array = numbered[anim].keys()
		order.sort()
		var keys: Array[String] = []
		for n: int in order:
			keys.append(numbered[anim][n])
		out[anim] = keys
	return out


## {animation: [per-frame ticks or a single ticks value, loop]} from the game's tables.
func defaults(set_name: String) -> Dictionary:
	var out: Dictionary = {}
	if set_name in [ArenaAnimation.SET_KATANA, ArenaAnimation.SET_DAGGER, ArenaAnimation.SET_LIGHTNING, ArenaAnimation.SET_SCYTHE]:
		for anim: String in ArenaAnimation.PLAYER:
			out[anim] = [int(ArenaAnimation.PLAYER[anim][1]), bool(ArenaAnimation.PLAYER[anim][2])]
		out["ward_hold"] = [DEFAULT_TICKS, true]
	elif set_name == "totoy_unarmed":
		for anim: String in UNARMED:
			out[anim] = [int(UNARMED[anim][1]), bool(UNARMED[anim][2])]
	elif set_name == "golem2":
		for anim: String in ArenaAnimation.BOSS:
			out[anim] = [int(ArenaAnimation.BOSS[anim][1]), bool(ArenaAnimation.BOSS[anim][2])]
	elif MobView.STATES.has(set_name):
		for state: String in MobView.STATES[set_name]:
			var pose: Array = MobView.STATES[set_name][state]
			if not out.has(pose[0]):
				out[pose[0]] = [int(pose[2]), bool(pose[3])]
		var extra: Dictionary = MOB_EXTRA.get(set_name, {})
		for anim: String in extra:
			if not out.has(anim):
				out[anim] = extra[anim]
	elif set_name.begins_with("npc_"):
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NPC_MANIFEST))
		var states: Dictionary = Dictionary(manifest["states"]).get(set_name.trim_prefix("npc_"), {})
		for anim: String in states:
			out[anim] = [Dictionary(states[anim]).get("ticks", [DEFAULT_TICKS]), true]
	return out


## The effects that run on a per-frame tick list in the code: their lists are the starting durations (and, once the resource exists,
## the game reads them back from it: presentation/arena/*_effects.gd `static var ..._TICKS`).
func effect_timing() -> Dictionary:
	return {
		"fx_lantern_place": AspectEffects.PLACE_TICKS, "fx_lantern_pulse": AspectEffects.PULSE_TICKS, "fx_lantern_fade": AspectEffects.FADE_TICKS,
		"fx_lantern_pool_open": AspectEffects.POOL_OPEN_TICKS, "fx_lantern_pool_pulse": AspectEffects.POOL_PULSE_TICKS,
		"fx_lantern_motes": AspectEffects.MOTES_TICKS, "fx_lantern_spark": AspectEffects.SPARK_TICKS, "fx_phantom_start": AspectEffects.START_TICKS,
		"fx_phantom_end": AspectEffects.END_TICKS, "fx_phantom_spark": AspectEffects.ECHO_SPARK_TICKS,
		"fx_lightning_spark": LightningEffects.SPARK_TICKS, "fx_lightning_blink": LightningEffects.BLINK_TICKS,
		"fx_lightning_strike": LightningEffects.STRIKE_TICKS, "fx_lightning_ground": LightningEffects.GROUND_TICKS,
		"fx_chain_hook": ScytheEffects.HOOK_TICKS, "fx_chain_land": ScytheEffects.LAND_TICKS, "fx_chain_stagger": ScytheEffects.STAGGER_TICKS,
		"fx_chain_dust": ScytheEffects.DUST_TICKS, "fx_chain_scuff": ScytheEffects.SCUFF_TICKS,
		"fx_echo_place": WardEchoSprintEffects.PLACE_TICKS, "fx_echo_vanish": WardEchoSprintEffects.VANISH_TICKS,
		"fx_echo_trail_head": WardEchoSprintEffects.TRAIL_TICKS, "fx_echo_arrive": WardEchoSprintEffects.ARRIVE_TICKS,
		"fx_echo_dust": WardEchoSprintEffects.ECHO_DUST_TICKS, "fx_ward_absorb": WardEchoSprintEffects.ABSORB_TICKS,
		"fx_ward_block": WardEchoSprintEffects.BLOCK_TICKS, "fx_ward_shockwave": WardEchoSprintEffects.SHOCKWAVE_TICKS,
		"fx_ward_cracks": WardEchoSprintEffects.CRACKS_TICKS, "fx_sprint_start": WardEchoSprintEffects.SPRINT_START_TICKS,
		"fx_sprint_end": WardEchoSprintEffects.SPRINT_END_TICKS,
	}


## The effects whose frame the code works out from their age at a steady pace: [frame count, ticks per frame, loop] (their code
## reads AnimLib.effect_at with the same spec, so the resource's starting values play exactly as before).
func effect_paced() -> Dictionary:
	return {
		"fx_lantern_idle": [6, AspectEffects.IDLE_FRAME_TICKS, true], "fx_lantern_pool_idle": [4, AspectEffects.POOL_IDLE_FRAME_TICKS, true],
		"fx_phantom_marker": [4, AspectEffects.MARKER_FRAME_TICKS, true], "fx_charge": [6, 2, true], "fx_slam": [6, 2, false],
		"fx_sweep": [6, 2, false], "fx_stomp": [6, 2, false], "fx_beam_body": [4, 2, false],
		"fx_echo_anchor": [6, WardEchoSprintEffects.ANCHOR_FRAME_TICKS, true], "fx_ward_barrier": [6, WardEchoSprintEffects.BARRIER_FRAME_TICKS, true],
		"fx_sprint_lines": [4, WardEchoSprintEffects.LINES_FRAME_TICKS, true], "fx_sprint_dust": [6, WardEchoSprintEffects.DUST_FRAME_TICKS, true],
		"fx_sprint_wind": [4, WardEchoSprintEffects.WIND_FRAME_TICKS, true],
		"fx_parry": [6, 2, false], "fx_hit": [6, 2, false], "fx_counter": [6, 2, false], "fx_black_aura_back": [6, 5, true], "fx_dash": [6, 2, false],
		"fx_lightning_aura_back": [10, 1, false], "fx_ch1_moth_trail": [4, 4, true], "fx_glowmoth_orb": [4, 4, true], "fx_glowmoth_orb_pop": [4, 4, false],
		"fx_stag_horn_": [4, 3, true],
		"fx_warden_death_flash": [4, 3, false], "fx_warden_idle_spores": [6, 8, true], "fx_warden_exposed_dust": [6, 6, true], "fx_warden_arrival": [6, 3, false],
		"fx_warden2_ring_charge": [4, 6, true], "fx_warden2_guard_hit": [4, 3, false], "fx_warden2_guard_break": [6, 3, false],
		"fx_warden2_footstep": [4, 4, false], "fx_warden2_lash": [8, 2, false],
	}


## True when an effect animation still has the placeholder timing the first effect pass gave every effect (EFFECT_TICKS a frame,
## no loop, nothing changed by the owner): it can take its code's real pace without overwriting an edit.
func _placeholder(frames: SpriteFrames, anim: StringName) -> bool:
	if not is_equal_approx(frames.get_animation_speed(anim), 60.0 / EFFECT_TICKS) or frames.get_animation_loop(anim):
		return false
	for i: int in frames.get_frame_count(anim):
		if not is_equal_approx(frames.get_frame_duration(anim, i), 1.0):
			return false
	return true


## Sets an animation's speed, per-frame durations (from ticks) and loop flag, keeping its frames.
func _time(frames: SpriteFrames, anim: StringName, spec: Array) -> void:
	var ticks: Array = spec[0] if spec[0] is Array else [spec[0]]
	var base: int = int(ticks[0])
	for t: Variant in ticks:
		base = mini(base, int(t))
	base = maxi(1, base)
	frames.set_animation_speed(anim, 60.0 / base)
	frames.set_animation_loop(anim, bool(spec[1]))
	for i: int in frames.get_frame_count(anim):
		var t: int = int(ticks[mini(i, ticks.size() - 1)])
		frames.set_frame(anim, i, frames.get_frame_texture(anim, i), float(t) / float(base))


## Builds or updates the set's resource; true when the file was written. `effects`: an effect animation still on the placeholder
## timing takes its code's real pace.
func write(set_name: String, anims: Dictionary, timing: Dictionary, reset: bool, folder: String = OUT, effects: bool = false) -> bool:
	var path: String = folder + set_name + ".tres"
	var frames: SpriteFrames = null
	if not reset and ResourceLoader.exists(path):
		frames = load(path) as SpriteFrames
	var changed: bool = false
	if frames == null:
		frames = SpriteFrames.new()
		frames.remove_animation(&"default")
		changed = true
	# frames whose PNG is gone are dropped (an owner's animation keeps everything else)
	for anim: StringName in frames.get_animation_names():
		for i: int in range(frames.get_frame_count(anim) - 1, -1, -1):
			var texture: Texture2D = frames.get_frame_texture(anim, i)
			if texture == null or not FileAccess.file_exists(texture.resource_path):
				frames.remove_frame(anim, i)
				changed = true
	var order: Array = anims.keys()
	order.sort()
	for anim: String in order:
		if frames.has_animation(anim):
			var spec: Array = timing.get(anim, [])
			if effects and not spec.is_empty() and _placeholder(frames, anim) and not (spec[0] is Array and (spec[0] as Array).all(func(t: Variant) -> bool: return int(t) == EFFECT_TICKS) and not bool(spec[1])):
				_time(frames, anim, spec)
				changed = true
			continue
		var spec: Array = timing.get(anim, [DEFAULT_TICKS, false])
		var ticks: Array = spec[0] if spec[0] is Array else [spec[0]]
		var base: int = int(ticks[0])  # the shortest frame is 1.0; longer frames get a longer duration (NPC idles)
		for t: Variant in ticks:
			base = mini(base, int(t))
		base = maxi(1, base)
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 60.0 / base)
		frames.set_animation_loop(anim, bool(spec[1]))
		var keys: Array = anims[anim]
		for i: int in keys.size():
			var t: int = int(ticks[mini(i, ticks.size() - 1)])
			frames.add_frame(anim, load(SPRITES + String(keys[i]) + ".png"), float(t) / float(base))
		changed = true
	if changed:
		var err: Error = ResourceSaver.save(frames, path)
		if err != OK:
			push_error("cannot save %s: %d" % [path, err])
	return changed
