extends SceneTree
## Run after validate/build/preview and Godot import.
const Arena := preload("res://presentation/arena/arena.gd")
const WeaponBuffView := preload("res://presentation/arena/weapon_buff_view.gd")
const SkillEffects := preload("res://presentation/arena/skill_effects.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const Weapons := preload("res://core/weapons.gd")
const Tuning := preload("res://core/tuning.gd")
const PlayerState := preload("res://core/player.gd")
const GameCore := preload("res://core/game_core.gd")
const InputFrame := preload("res://core/input_frame.gd")
const Snapshots := preload("res://core/snapshots.gd")
const GameEvent := preload("res://core/game_event.gd")
var failures: Array[String] = []
var player_states: Dictionary = {}
var boss_poses: Dictionary = {}
var arena: Arena

func _init() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _frame(move: Vector2 = Vector2.ZERO, dash: bool = false, parry: bool = false, attack: bool = false) -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.move = move
	frame.dash_pressed = dash
	frame.parry_pressed = parry
	frame.attack_pressed = attack
	return frame

func _observe() -> void:
	arena.snapshot = arena.core.snapshot()
	arena._age_effects()
	arena.prepare_visuals()
	for event: GameEvent in arena.core.last_events:
		arena._on_event(event)
	arena._update_hud()
	arena.queue_redraw()
	player_states[String(arena.snapshot.player.state)] = true
	for actor: Snapshots.EntitySnapshot in arena.snapshot.entities:
		boss_poses[String(arena.selected_frames.get(actor.id, ""))] = true

func _step(frame: InputFrame) -> void:
	arena.core.step(frame)
	_observe()

func _wait(ticks: int) -> void:
	for i: int in range(ticks):
		_step(_frame())

func _reset() -> void:
	arena._restart()
	arena.core.boss.cooldown = 10000
	_observe()

func _catalog() -> void:
	var file: FileAccess = FileAccess.open("res://art/build/sprites.json", FileAccess.READ)
	if file == null:
		_expect(false, "cannot open sprites.json")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_expect(false, "invalid sprites.json")
		return
	var atlas: Dictionary = parsed.get("frames", {})
	_expect(atlas.has("totoy_portrait"), "portrait missing")
	if atlas.has("totoy_portrait"):
		_expect(int(atlas["totoy_portrait"]["w"]) == 48 and int(atlas["totoy_portrait"]["h"]) == 48, "portrait canvas")
	for name_key: String in ArenaAnimation.all_names() + SkillEffects.all_names() + WeaponBuffView.all_names():
		_expect(atlas.has(name_key), "atlas missing " + name_key)
		if atlas.has(name_key) and (name_key.begins_with("hero2_") or name_key.begins_with("totoy_dagger_") or name_key.begins_with("totoy_lightning_")):
			var frame: Dictionary = atlas[name_key]
			_expect(frame.has("ax") and frame.has("ay"), "feet anchor missing: " + name_key)
			var at: Vector2 = Vector2(64, 88)
			for left: bool in [false, true]:
				var rect: Rect2 = ArenaAnimation.destination(at, frame, left)
				var foot_x: float = float(frame["w"]) - float(frame["ax"]) if left else float(frame["ax"])
				_expect(rect.position + Vector2(foot_x, frame["ay"]) == at, "frame feet detached from shadow: " + name_key)
				_expect(rect.size.x == (-float(frame["w"]) if left else float(frame["w"])), "flip width: " + name_key)
	# Exercise every directional state and every frame index the table declares.
	var snap: Snapshots.GameSnapshot = Snapshots.GameSnapshot.new()
	var actor: Snapshots.EntitySnapshot = Snapshots.EntitySnapshot.new()
	actor.visual_id = &"totoy"
	for state: String in ArenaAnimation.PLAYER:
		actor.state = StringName(state)
		for facing: Vector2 in [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]:
			actor.facing = facing
			for t: int in range(int(ArenaAnimation.PLAYER[state][0]) * int(ArenaAnimation.PLAYER[state][1]) + 2):
				actor.state_ticks = t
				_expect(atlas.has(ArenaAnimation.choose(actor, snap, {})), "selector missing player %s %s tick %d" % [state, facing, t])
	# The same for the Dual Dagger and its Lightning Form: every state, and every phase tick of swings 1-4 (also at
	# the form's doubled speed), must name a frame of the right set.
	for look: Array in [[Tuning.WEAPON_DUAL_DAGGER, &"", "totoy_dagger_"], [Tuning.WEAPON_DUAL_DAGGER, Weapons.FORM_LIGHTNING, "totoy_lightning_"]]:
		actor.weapon_id = look[0]
		actor.weapon_form = look[1]
		for state: String in ArenaAnimation.PLAYER:
			actor.state = StringName(state)
			for swing: int in range(1, Weapons.combo_max(actor.weapon_id) + 1):
				actor.combo_index = swing
				for mult: float in [1.0, Tuning.BLACK_KATANA_ATTACK_SPEED_MULT]:
					actor.attack_speed_mult = mult
					for t: int in range(int(ArenaAnimation.PLAYER[state][0]) * int(ArenaAnimation.PLAYER[state][1]) + 24):
						actor.state_ticks = t
						var chosen: String = ArenaAnimation.choose(actor, snap, {})
						_expect(atlas.has(chosen), "selector missing %s %s swing %d tick %d: %s" % [look[2], state, swing, t, chosen])
						_expect(chosen.begins_with(look[2]) or (state == "victory" and chosen.begins_with("totoy_dagger_")), "wrong set for %s %s: %s" % [look[2], state, chosen])
		for skill: StringName in [&"breaking_edge", &"gale_cut", &"moon_cleave"]:
			actor.skill_id = skill
			for state: StringName in [&"skill_windup", &"skill_active", &"skill_recovery"]:
				actor.state = state
				for t: int in range(40):
					actor.state_ticks = t
					_expect(atlas.has(ArenaAnimation.choose(actor, snap, {})), "dagger skill frame missing %s %s %d" % [skill, state, t])
		actor.skill_id = &""
		actor.combo_index = 4
		actor.state = &"attack_recovery"
		_expect(ArenaAnimation.swing_durations(actor)[2] == PlayerState.scaled_ticks(Tuning.DAGGER_SWING_RECOVERY_TICKS[3], actor.attack_speed_mult), "dagger swing 4 uses its own table")
	# Lightning Barrage: every slash (0 = the activation tick) at every age shows a Lightning dagger attack frame.
	actor.weapon_id = Tuning.WEAPON_DUAL_DAGGER
	actor.weapon_form = Weapons.FORM_LIGHTNING
	actor.state = PlayerState.STATE_LIGHTNING_BARRAGE
	snap.tick = 500
	var barrage_frames: Dictionary = {}
	for slash: int in range(0, Weapons.barrage_slashes() + 1):
		actor.lightning_barrage_slash = slash
		for age: int in range(0, Tuning.LIGHTNING_BARRAGE_INTERVAL_TICKS + Tuning.LIGHTNING_BARRAGE_RECOVERY_TICKS + 2):
			actor.lightning_barrage_slash_tick = snap.tick - age if slash > 0 else -1
			var chosen: String = ArenaAnimation.choose(actor, snap, {})
			barrage_frames[chosen] = true
			_expect(atlas.has(chosen) and chosen.begins_with("totoy_lightning_attack"), "barrage slash %d age %d: %s" % [slash, age, chosen])
	for swing: int in range(1, 5):
		_expect(barrage_frames.has("totoy_lightning_attack%d_right_4" % swing), "the barrage never shows swing %d's strike" % swing)
	actor.lightning_barrage_slash = 0
	actor.lightning_barrage_slash_tick = -1
	snap.tick = 0
	for prefix: String in [ArenaAnimation.SET_KATANA, ArenaAnimation.SET_DAGGER, ArenaAnimation.SET_LIGHTNING]:
		var expected: int = 6 * (3 if prefix == ArenaAnimation.SET_KATANA else 4)
		var attacks: int = 0
		for name_key: String in ArenaAnimation.hero_names(prefix):
			_expect(atlas.has(name_key), "set %s misses %s" % [prefix, name_key])
			if name_key.contains("_attack"):
				attacks += 1
		_expect(attacks == expected, "set %s lists %d swing frames" % [prefix, attacks])
	actor.weapon_id = &""
	actor.weapon_form = &""
	_expect(ArenaAnimation.mirrored(Vector2.LEFT), "left must mirror right")
	_expect(not ArenaAnimation.mirrored(Vector2.UP), "up must not mirror")
# Follow real core state lifetimes so a pose that is unreachable before a state
# expires cannot pass merely because the catalog can synthesize its name.
func _hero_timelines() -> void:
	for facing: Vector2 in [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]:
		_reset()
		_step(_frame(facing))
		var requested: Dictionary = {}
		for i: int in range(50):
			_step(_frame())
			requested[arena.selected_frames[arena.snapshot.player.id]] = true
		for i: int in range(40):
			_step(_frame(facing))
			requested[arena.selected_frames[arena.snapshot.player.id]] = true
		for action: int in range(3):
			_step(_frame(Vector2.ZERO, action == 0, action == 1, action == 2))
			requested[arena.selected_frames[arena.snapshot.player.id]] = true
			for i: int in range(40):
				_step(_frame())
				requested[arena.selected_frames[arena.snapshot.player.id]] = true
		_step(_frame(Vector2.ZERO, false, false, true))
		for i: int in range(100):
			var hero: Snapshots.EntitySnapshot = arena.snapshot.player
			var chain: bool = hero.state == &"attack_recovery" and hero.combo_index < 3
			_step(_frame(Vector2.ZERO, false, false, chain))
			requested[arena.selected_frames[arena.snapshot.player.id]] = true
		for name_key: String in ArenaAnimation.all_names():
			if name_key.begins_with("hero2_") and name_key.contains("_" + ArenaAnimation.direction(facing) + "_") and not name_key.contains("_hurt_") and not name_key.contains("_victory_"):
				_expect(requested.has(name_key), "real state lifetime never requests " + name_key)

## Real core lifetimes with the Dual Dagger: swap with the swap intent, chain all four swings; then activate Lightning
## Form (only the barrage): the barrage draws the lightning attack frames, and the swings after it are plain dagger
## swings again. Every swing frame must be requested, and none may be missing.
func _dagger_timelines() -> void:
	for form: bool in [false, true]:
		_reset()
		arena.core.player.edge = 100.0
		var swap: InputFrame = _frame()
		swap.weapon_swap_pressed = true
		_step(swap)
		_expect(arena.snapshot.player.weapon_id == Tuning.WEAPON_DUAL_DAGGER, "swap intent did not equip the dagger")
		_expect(String(arena.selected_frames[arena.snapshot.player.id]).begins_with("totoy_dagger_"), "dagger not drawn after the swap")
		if form:
			var active: InputFrame = _frame()
			active.weapon_active_pressed = true
			_step(active)
			_expect(arena.snapshot.player.weapon_form == Weapons.FORM_LIGHTNING, "Lightning Form did not start")
		var prefix: String = "totoy_lightning_" if form else "totoy_dagger_"
		var requested: Dictionary = {}
		var after_barrage: Dictionary = {}
		for round_index: int in range(3):
			_step(_frame(Vector2.ZERO, false, false, true))
			for i: int in range(80):
				var hero: Snapshots.EntitySnapshot = arena.snapshot.player
				requested[arena.selected_frames[hero.id]] = true
				if round_index > 0:
					after_barrage[arena.selected_frames[hero.id]] = true
				var chain: bool = hero.state == &"attack_recovery" and hero.combo_index < 4
				_step(_frame(Vector2.ZERO, false, false, chain))
				if not form and hero.state == &"idle" and i > 10:
					break
		for swing: int in range(1, 5):
			var phases: Array[int] = Weapons.swing_phases(Tuning.WEAPON_DUAL_DAGGER, swing)
			for n: int in range(1, 7):
				# a phase that lasts one tick shows only its key (second) frame
				if PlayerState.scaled_ticks(phases[(n - 1) / 2], 1.0) == 1 and n % 2 == 1:
					continue
				var name_key: String = "totoy_dagger_attack%d_right_%d" % [swing, n]
				_expect(requested.has(name_key), "dagger timeline never requests " + name_key)
			if form:
				_expect(requested.has("totoy_lightning_attack%d_right_4" % swing), "the barrage never shows swing %d's strike" % swing)
		if form:
			_expect(arena.snapshot.player.weapon_form == &"", "the form outlived its barrage")
			for name_key: String in after_barrage:
				_expect(String(name_key).begins_with("totoy_dagger_"), "after the barrage the hero must be the plain dagger: " + String(name_key))
		for name_key: String in requested:
			_expect(String(name_key).begins_with(prefix) or String(name_key).begins_with("totoy_dagger_"), "%s timeline drew another set: %s" % [prefix, name_key])

func _encounter(attack: StringName, parry_slam: bool) -> void:
	_reset()
	if attack in [&"gold_combo", &"red_charge"]:
		arena.core.boss.phase = 2
	arena.core.boss.next_attack_override = attack
	arena.core.boss.cooldown = 1
	_step(_frame())
	_expect(not arena.snapshot.telegraphs.is_empty(), "scripted boss attack did not start")
	for i: int in range(240):
		var parry: bool = false
		for tell: Snapshots.TelegraphSnapshot in arena.snapshot.telegraphs:
			if parry_slam and tell.kind == &"gold" and arena.snapshot.tick == tell.hit_tick - 2:
				parry = true
		_step(_frame(Vector2.ZERO, false, parry))
		await process_frame
		if parry_slam and arena.snapshot.entities[0].state == &"posture_broken":
			_wait(26)
			return
		if not parry_slam and arena.snapshot.entities[0].state == &"recover" and arena.snapshot.entities[0].state_ticks > ArenaAnimation.STRIKE_HOLD_TICKS + 2:
			return
	_expect(false, "encounter did not reach expected state: " + String(attack))

func _run() -> void:
	_catalog()
	var packed: PackedScene = load("res://presentation/arena/arena.tscn") as PackedScene
	if packed == null:
		printerr("ANIMATION FAIL: cannot load arena")
		quit(1)
		return
	arena = packed.instantiate() as Arena
	root.add_child(arena)
	arena.set_physics_process(false)
	_hero_timelines()
	_dagger_timelines()
	_reset()
	for facing: Vector2 in [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]:
		for i: int in range(24):
			_step(_frame(facing))
	_step(_frame(Vector2.LEFT, true))
	_wait(16)
	_step(_frame(Vector2.ZERO, false, true))
	_wait(36)
	_step(_frame(Vector2.ZERO, false, false, true))
	_wait(22)
	for attack: StringName in [&"gold_slam", &"red_sweep", &"red_shards", &"red_stomp", &"gold_combo", &"red_charge"]:
		await _encounter(attack, false)
	await _encounter(&"gold_slam", true)
	await _encounter(&"gold_combo", true)
	for state: String in ArenaAnimation.PLAYER:
		if state not in ["dead", "hurt", "victory"]:
			_expect(player_states.has(state), "script never reached player " + state)
	_expect(player_states.has(String(PlayerState.STATE_LIGHTNING_BARRAGE)), "the Lightning Form timeline never ran the barrage")
	for name_key: String in ArenaAnimation.all_names():
		if name_key.begins_with("mossbound_colossus_") and (name_key.contains("windup") or name_key.contains("strike") or name_key.contains("red_sweep_recover")):
			_expect(boss_poses.has(name_key), "fight never requested " + name_key)
	_expect(arena.missing_frames.is_empty(), "runtime missing names: " + str(arena.missing_frames.keys()))
	await process_frame
	arena.queue_free()
	if failures.is_empty():
		print("ANIMATION SMOKE OK")
		quit(0)
	else:
		for message: String in failures:
			printerr("ANIMATION FAIL: " + message)
		quit(1)
