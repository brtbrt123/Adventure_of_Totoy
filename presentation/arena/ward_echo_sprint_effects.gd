extends RefCounted
## Cosmetic timing and naming for the Echo Step, Stone Ward and Sprint aspects: the echo anchor and its countdown, the
## recall (vanish, pull trail, arrival, i-frame shield), the ward pose, barrier, absorb flash, stored glow, block sparks,
## shockwave and floor cracks, and the sprint aura, afterimages, speed lines, dust, wind and start/end bursts. Pure
## functions over ticks and names taken from the snapshot and core events; no rules, no damage, no hit decisions.
## Art and anchors: art/reference/aspects_echo_ward_sprint/README.md ("In-game import") and
## art/build/echo_ward_sprint_sprites_manifest.json. Ticks per frame are the manifest's suggested ms at 60 Hz, rounded.
const Tuning := preload("res://core/tuning.gd")
const AspectEffects := preload("res://presentation/arena/aspect_effects.gd")

## Live event effects at most (the oldest is dropped first).
const MAX_LIVE: int = 40

# --- Echo Step --------------------------------------------------------------------------------------------------------
const PLACE_TICKS: Array[int] = [3, 4, 4, 4, 5]
const ANCHOR_FRAME_TICKS: int = 6  # 100 ms, 6 frames looping
## The anchor turns into the countdown for the last ticks before the recall (4 frames x 5 ticks, about 320 ms).
const COUNTDOWN_TICKS: int = 20
const COUNTDOWN_FRAME_TICKS: int = 5
const VANISH_TICKS: Array[int] = [3, 3, 4, 4, 5]
const TRAIL_TICKS: Array[int] = [2, 3, 4, 4]
const ARRIVE_TICKS: Array[int] = [3, 3, 4, 4, 5]
## The hero is drawn at the echo from arrive frame 2 (frame 1 is the echo flaring and the streaks pulling in).
const ARRIVE_HIDE_TICKS: int = 3
const ECHO_DUST_TICKS: Array[int] = [4, 4, 4, 4, 4]
const SHIELD_PHASE_TICKS: int = 4  # 70 ms; phases 1-3 loop during the i-frames, 4 on the last ticks
## The recall streak flies at chest height.
const CHEST: Vector2 = Vector2(0, -14)
## Trail tile families: base direction of the tile art (radians), the step between tiles along it, the anchor.
const TRAIL_FAMILIES: Dictionary = {
	"h": {"angle": 0.0, "step": Vector2(16, 0)},
	"d": {"angle": PI * 0.25, "step": Vector2(16, 16)},
	"v": {"angle": PI * 0.5, "step": Vector2(0, 16)},
}

# --- Stone Ward -------------------------------------------------------------------------------------------------------
const WARD_RAISE_TICKS: Array[int] = [3, 4, 4, 5]
const WARD_HOLD_FRAME_TICKS: int = 6  # 100 ms, 4 frames looping
const WARD_DROP_TICKS: Array[int] = [4, 4, 5]
const BARRIER_FRAME_TICKS: int = 5  # 90 ms, 6 frames looping
const ABSORB_TICKS: Array[int] = [2, 3, 4, 4]
const STORE_FRAME_TICKS: int = 5
const BLOCK_TICKS: Array[int] = [2, 3, 3, 4, 4]
## The block impact sits on the ward's front, relative to the feet, facing right.
const BLOCK_POINT: Vector2 = Vector2(22, -16)
const SHOCKWAVE_TICKS: Array[int] = [2, 3, 3, 3, 4, 4, 4, 5]
## Ring radius drawn by each shockwave frame (manifest radius_px); the last one is the art's full radius.
const SHOCKWAVE_RADIUS_PX: Array[int] = [6, 18, 30, 41, 50, 57, 62, 64]
const CRACKS_TICKS: Array[int] = [7, 10, 16, 18]

# --- Sprint -----------------------------------------------------------------------------------------------------------
const SPRINT_START_TICKS: Array[int] = [2, 3, 4, 4, 5]
const SPRINT_END_TICKS: Array[int] = [4, 5, 5, 6]
const AURA_PHASE_TICKS: int = 5  # 80 ms, 6 phases
const AURA_PHASES: int = 6
const LINES_FRAME_TICKS: int = 4  # 60 ms, 4 frames
const DUST_FRAME_TICKS: int = 4  # 60 ms, 6 frames
const WIND_FRAME_TICKS: int = 4  # 70 ms, 4 frames
## Afterimage k (1-3) shows where the hero was k x AFTERIMAGE_STEP ticks ago (about 150 ms each).
const AFTERIMAGES: int = 3
const AFTERIMAGE_STEP: int = 9
## Samples kept for the afterimages (one per fresh tick); the buffer never grows past this.
const TRAIL_CAP: int = AFTERIMAGES * AFTERIMAGE_STEP + 1
## An afterimage closer than this to the hero is not drawn (they overlap him when he moves slowly).
const AFTERIMAGE_MIN_GAP: float = 6.0


static func sequence_frame(durations: Array[int], age: int) -> int:
	return AspectEffects.sequence_frame(durations, age)


static func sequence_length(durations: Array[int]) -> int:
	return AspectEffects.sequence_length(durations)


static func add(effects: Array[Dictionary], effect: Dictionary) -> void:
	effects.append(effect)
	while effects.size() > MAX_LIVE:
		effects.pop_front()


# --- Echo Step --------------------------------------------------------------------------------------------------------

## The echo drawn at the anchor `age` ticks after its placement with `ticks_left` until the recall (0 while it waits for
## a barrage/coil): nothing during the placement burst, then the anchor loop, then the countdown for the last 20 ticks.
static func anchor_key(age: int, ticks_left: int) -> String:
	if age < sequence_length(PLACE_TICKS):
		return ""
	if ticks_left > 0 and ticks_left <= COUNTDOWN_TICKS:
		var n: int = clampi((COUNTDOWN_TICKS - ticks_left) / COUNTDOWN_FRAME_TICKS, 0, 3) + 1
		return "fx_echo_countdown_%d" % n
	return "fx_echo_anchor_%d" % (posmod((age - sequence_length(PLACE_TICKS)) / ANCHOR_FRAME_TICKS, 6) + 1)


## The i-frame shield phase with `invuln_ticks` left (12 on the arrival tick): 1-3 looping, 4 on the last ticks.
static func shield_phase(invuln_ticks: int) -> int:
	if invuln_ticks <= SHIELD_PHASE_TICKS - 1:
		return 4
	return posmod((Tuning.ECHO_STEP_INVULN_TICKS - invuln_ticks) / SHIELD_PHASE_TICKS, 3) + 1


## The per-frame outline shield over hero frame F (draw nothing if it is not in sprites.json and use the bubble).
static func shield_key(hero_frame: String, phase: int) -> String:
	return "fx_echo_shield_%s_%d" % [hero_frame, phase]


static func bubble_key(phase: int) -> String:
	return "fx_echo_bubble_%d" % phase


## The trail tile family for a streak at `angle` and the rotation that lines its art up with the streak: the family
## whose art direction needs the rotation closest to a quarter turn (those stay pixel-exact: h, d and v cover the 8
## main directions; any other angle rotates the nearest family with nearest filtering).
static func trail_family(angle: float) -> Dictionary:
	var best: String = "h"
	var best_score: float = INF
	var quarter: float = PI * 0.5
	for family: String in TRAIL_FAMILIES:
		var rotation: float = wrapf(angle - float(TRAIL_FAMILIES[family]["angle"]), -PI, PI)
		var residual: float = absf(rotation - roundf(rotation / quarter) * quarter)
		# the least off-grid rotation first; among exact ones the smallest turn (h for left/right, v for up/down)
		var score: float = snappedf(residual, 0.0001) * 100.0 + absf(rotation)
		if score < best_score:
			best_score = score
			best = family
	return {"family": best, "rotation": wrapf(angle - float(TRAIL_FAMILIES[best]["angle"]), -PI, PI), "step": TRAIL_FAMILIES[best]["step"]}


## The tiles of a streak of `length` px: [{"offset": distance along the art direction, "fraction": 0..1 of the tile}].
static func trail_tiles(length: float, family: String) -> Array[Dictionary]:
	var step: float = Vector2(TRAIL_FAMILIES[family]["step"]).length()
	var tiles: Array[Dictionary] = []
	var at: float = 0.0
	while at < length - 0.5:
		tiles.append({"offset": at, "fraction": clampf((length - at) / step, 0.0, 1.0)})
		at += step
	return tiles


static func trail_key(family: String, phase: int) -> String:
	return "fx_echo_trail_%s_%d" % [family, phase]


# --- Stone Ward -------------------------------------------------------------------------------------------------------

## The ward pose ("raise"/"hold"/"drop", frame) from ward_ticks_left (60 on the raise tick, 1 on the last ward tick):
## raise over its first ticks, drop over the last ones (it ends as the shockwave fires), hold in between.
static func ward_pose(ward_ticks_left: int) -> Array:
	var elapsed: int = Tuning.STONE_WARD_DURATION_TICKS - ward_ticks_left
	var drop_len: int = sequence_length(WARD_DROP_TICKS)
	if ward_ticks_left <= drop_len:
		return ["drop", maxi(1, sequence_frame(WARD_DROP_TICKS, drop_len - ward_ticks_left))]
	var raise: int = sequence_frame(WARD_RAISE_TICKS, elapsed)
	if raise > 0:
		return ["raise", raise]
	return ["hold", posmod((elapsed - sequence_length(WARD_RAISE_TICKS)) / WARD_HOLD_FRAME_TICKS, 4) + 1]


## The barrier dome stands from raise frame 3 until drop frame 1 ends.
static func barrier_visible(ward_ticks_left: int) -> bool:
	if ward_ticks_left <= 0:
		return false
	var elapsed: int = Tuning.STONE_WARD_DURATION_TICKS - ward_ticks_left
	var from: int = WARD_RAISE_TICKS[0] + WARD_RAISE_TICKS[1]
	return elapsed >= from and ward_ticks_left > sequence_length(WARD_DROP_TICKS) - WARD_DROP_TICKS[0]


static func barrier_key(ward_ticks_left: int) -> String:
	var elapsed: int = Tuning.STONE_WARD_DURATION_TICKS - ward_ticks_left
	return "fx_ward_barrier_%d" % (posmod(elapsed / BARRIER_FRAME_TICKS, 6) + 1)


## Stored-energy glow level 1-3 for `stored` damage (thirds of the cap), 0 when nothing is stored.
static func store_level(stored: int) -> int:
	if stored <= 0:
		return 0
	return clampi(ceili(3.0 * stored / Tuning.STONE_WARD_STORE_CAP), 1, 3)


static func store_key(level: int, tick: int) -> String:
	return "fx_ward_store_%d_%d" % [level, posmod(tick / STORE_FRAME_TICKS, 4) + 1]


## The slab alone (an overlay for a hero frame without the slab painted in).
static func slab_key(ward_ticks_left: int) -> String:
	var pose: Array = ward_pose(ward_ticks_left)
	return "fx_ward_slab_%s_%d" % [pose[0], pose[1]]


## Scale of the shockwave art for a core radius (1 at the art's 64 px, which is STONE_WARD_RADIUS today).
static func shockwave_scale(radius: float) -> float:
	return radius / float(SHOCKWAVE_RADIUS_PX[SHOCKWAVE_RADIUS_PX.size() - 1]) if radius > 0.0 else 1.0


## The ring radius drawn by shockwave frame n (1-8) at `scale_px`, in world pixels.
static func shockwave_radius(frame: int, scale_px: float) -> float:
	return SHOCKWAVE_RADIUS_PX[clampi(frame, 1, SHOCKWAVE_RADIUS_PX.size()) - 1] * scale_px


# --- Sprint -----------------------------------------------------------------------------------------------------------

static func since_sprint_start(sprint_ticks_left: int) -> int:
	return Tuning.SPRINT_DURATION_TICKS - sprint_ticks_left


static func aura_phase(since_start: int) -> int:
	return posmod(maxi(0, since_start) / AURA_PHASE_TICKS, AURA_PHASES) + 1


static func aura_key(hero_frame: String, since_start: int) -> String:
	return "fx_sprint_aura_%s_%d" % [hero_frame, aura_phase(since_start)]


static func after_key(hero_frame: String, k: int) -> String:
	return "fx_sprint_after_%s_%d" % [hero_frame, k]


static func lines_key(tick: int) -> String:
	return "fx_sprint_lines_%d" % (posmod(tick / LINES_FRAME_TICKS, 4) + 1)


static func dust_key(tick: int) -> String:
	return "fx_sprint_dust_%d" % (posmod(tick / DUST_FRAME_TICKS, 6) + 1)


static func wind_key(tick: int) -> String:
	return "fx_sprint_wind_%d" % (posmod(tick / WIND_FRAME_TICKS, 4) + 1)


## Every sprite these effects can request by group (the per-hero-frame overlays are looked up per frame).
static func all_names() -> Array[String]:
	var names: Array[String] = []
	for group: Array in [["fx_echo_place", 5], ["fx_echo_anchor", 6], ["fx_echo_countdown", 4], ["fx_echo_vanish", 5], ["fx_echo_trail_h", 4], ["fx_echo_trail_d", 4], ["fx_echo_trail_v", 4], ["fx_echo_trail_head", 4], ["fx_echo_arrive", 5], ["fx_echo_bubble", 4], ["fx_echo_dust", 5], ["fx_ward_slab_raise", 4], ["fx_ward_slab_hold", 4], ["fx_ward_slab_drop", 3], ["fx_ward_barrier", 6], ["fx_ward_absorb", 4], ["fx_ward_store_1", 4], ["fx_ward_store_2", 4], ["fx_ward_store_3", 4], ["fx_ward_block", 5], ["fx_ward_shockwave", 8], ["fx_ward_cracks", 4], ["fx_sprint_start", 5], ["fx_sprint_lines", 4], ["fx_sprint_wind", 4], ["fx_sprint_dust", 6], ["fx_sprint_end", 4], ["ui_aspect_echo_step_lit", 4], ["ui_aspect_stone_ward_lit", 4], ["ui_aspect_sprint_lit", 4]]:
		for n: int in range(1, int(group[1]) + 1):
			names.append("%s_%d" % [group[0], n])
	for aspect: String in ["echo_step", "stone_ward", "sprint"]:
		names.append("ui_aspect_%s_1" % aspect)
	return names
