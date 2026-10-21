extends RefCounted
## Cosmetic timing and naming for the Spirit Lantern and Phantom Cut aspects (lantern prop, light pool, pulse rings,
## heal motes, Edge sparks, fade; Phantom Cut start/end bursts, the buff glow over the hero frame, the echo-pending
## marker, the phantom ghost, its arc and the landing spark). Pure functions over ticks and names taken from the
## snapshot and core events; no rules, no damage, no hit decisions.
## Art and anchors: art/reference/aspects_lantern_phantom/README.md ("In-game sprites") and
## art/build/lantern_phantom_sprites_manifest.json. Ticks per frame are the manifest's suggested ms at 60 Hz.
const Snapshots := preload("res://core/snapshots.gd")
const Tuning := preload("res://core/tuning.gd")

## Live event effects at most (the oldest is dropped first).
const MAX_LIVE: int = 32

## Spirit Lantern (frame n = entry n-1, ticks).
const PLACE_TICKS: Array[int] = [4, 4, 4, 5]
const IDLE_FRAME_TICKS: int = 7  # about 110 ms, 6 frames looping
const PULSE_TICKS: Array[int] = [3, 4, 4, 5]  # the lantern itself flaring on a pulse
const FADE_TICKS: Array[int] = [5, 5, 6, 7, 5, 5]
const POOL_OPEN_TICKS: Array[int] = [3, 3, 3]
const POOL_IDLE_FRAME_TICKS: int = 8  # about 140 ms, 4 frames looping
const POOL_PULSE_TICKS: Array[int] = [3, 3, 3, 3, 3]
const MOTES_TICKS: Array[int] = [4, 4, 4, 4, 4, 4]
const SPARK_TICKS: Array[int] = [3, 3, 3, 3, 3, 3]
## The Edge sparks start this many ticks after the heal motes ("1-2 frames after motes 1").
const SPARK_DELAY: int = 4
## Where the Edge sparks sit (their anchor is the chest), relative to the feet, facing right.
const CHEST: Vector2 = Vector2(2, -15)
## The pool art's ellipse radius (rx) in pixels: the art matches SPIRIT_LANTERN_RADIUS at scale 1.
const POOL_RADIUS_PX: float = 44.0

## Phantom Cut.
const START_TICKS: Array[int] = [3, 4, 4, 4, 5]
const END_TICKS: Array[int] = [4, 4, 5, 5]
const GHOST_TICKS: Array[int] = [2, 4, 4, 4]
const ARC_TICKS: Array[int] = [2, 3, 3, 4]
const ECHO_SPARK_TICKS: Array[int] = [2, 3, 3, 3, 4]
## The landing spark starts with arc phase 2 (the phantom hit).
const ECHO_SPARK_DELAY: int = 2
const GLOW_PHASE_TICKS: int = 5  # (ticks since the buff started / 5) % 6 + 1
const GLOW_PHASES: int = 6
const MARKER_FRAME_TICKS: int = 7  # about 120 ms, 4 frames looping
## The marker floats this far above the top of the hero's head.
const MARKER_GAP: int = 3
## The ghost stands this far ahead of the hero along his facing (manifest ghost_offset_px).
const GHOST_OFFSET: float = 8.0
## A phantom hit flashes the boss white this long (a real hit: 6) and the hurt recoil is short.
const ECHO_FLASH_TICKS: int = 2
const ECHO_RECOIL_TICKS: int = 6

const WEAPON_KEYS: Dictionary = {Tuning.WEAPON_BLACK_KATANA: "katana", Tuning.WEAPON_DUAL_DAGGER: "dagger", Tuning.WEAPON_CHAIN_SCYTHE: "scythe"}
const SWINGS: Dictionary = {"katana": 3, "dagger": 4, "scythe": 3}


## The 1-based frame showing `age` ticks into a sequence, 0 before it starts or after it ends.
static func sequence_frame(durations: Array[int], age: int) -> int:
	if age < 0:
		return 0
	var elapsed: int = 0
	for index: int in range(durations.size()):
		elapsed += durations[index]
		if age < elapsed:
			return index + 1
	return 0


static func sequence_length(durations: Array[int]) -> int:
	var total: int = 0
	for ticks: int in durations:
		total += ticks
	return total


## Adds an effect and drops the oldest past MAX_LIVE.
static func add(effects: Array[Dictionary], effect: Dictionary) -> void:
	effects.append(effect)
	while effects.size() > MAX_LIVE:
		effects.pop_front()


# --- Spirit Lantern ---------------------------------------------------------------------------------------------------

## The lantern prop frame `age` ticks after its placement; `since_pulse` is the ticks since its latest pulse (-1: none).
static func lantern_key(age: int, since_pulse: int) -> String:
	var place: int = sequence_frame(PLACE_TICKS, age)
	if place > 0:
		return "fx_lantern_place_%d" % place
	var pulse: int = sequence_frame(PULSE_TICKS, since_pulse)
	if pulse > 0:
		return "fx_lantern_pulse_%d" % pulse
	return "fx_lantern_idle_%d" % (posmod((age - sequence_length(PLACE_TICKS)) / IDLE_FRAME_TICKS, 6) + 1)


## The floor pool frame `age` ticks after the placement: it opens with place 2-4, then loops.
static func pool_key(age: int) -> String:
	var open_age: int = age - PLACE_TICKS[0]
	if open_age < 0:
		return ""
	var open: int = sequence_frame(POOL_OPEN_TICKS, open_age)
	if open > 0:
		return "fx_lantern_pool_open_%d" % open
	return "fx_lantern_pool_idle_%d" % (posmod((open_age - sequence_length(POOL_OPEN_TICKS)) / POOL_IDLE_FRAME_TICKS, 4) + 1)


## Ticks since the lantern's latest pulse, from the snapshot alone (-1 before the first pulse).
static func since_pulse(lantern: Snapshots.LanternSnapshot, tick: int) -> int:
	if lantern.pulse_index <= 0:
		return -1
	return tick - (lantern.placed_tick + lantern.pulse_index * Tuning.SPIRIT_LANTERN_PULSE_INTERVAL_TICKS)


## The pool's scale for a light radius (1 at the art's 44 px).
static func pool_scale(radius: float) -> float:
	return radius / POOL_RADIUS_PX if radius > 0.0 else 1.0


## On a fade the pool closes again (open frames backwards) over the first ticks of the lantern's fade.
static func pool_close_key(age: int) -> String:
	var frame: int = sequence_frame(POOL_OPEN_TICKS, age)
	return "fx_lantern_pool_open_%d" % (POOL_OPEN_TICKS.size() + 1 - frame) if frame > 0 else ""


# --- Phantom Cut ------------------------------------------------------------------------------------------------------

## "katana" / "dagger" / "scythe" for a weapon id (the katana for anything unknown).
static func weapon_key(weapon_id: StringName) -> String:
	return String(WEAPON_KEYS.get(weapon_id, "katana"))


## Glow shimmer phase 1-6 at `since_start` ticks into the buff (independent of the hero frame).
static func glow_phase(since_start: int) -> int:
	return posmod(maxi(0, since_start) / GLOW_PHASE_TICKS, GLOW_PHASES) + 1


## The glow overlay of a hero frame (manifest naming rule); the caller draws nothing when it is not in sprites.json.
static func glow_key(hero_frame: String, since_start: int) -> String:
	return "fx_phantom_glow_%s_%d" % [hero_frame, glow_phase(since_start)]


## Ticks since the running buff started, from the snapshot alone.
static func since_start(phantom_ticks_left: int) -> int:
	return Tuning.PHANTOM_CUT_DURATION_TICKS - phantom_ticks_left


static func marker_key(tick: int) -> String:
	return "fx_phantom_marker_%d" % (posmod(tick / MARKER_FRAME_TICKS, 4) + 1)


static func ghost_key(weapon: String, swing: int, frame: int) -> String:
	return "fx_phantom_ghost_%s_%d_%d" % [weapon, clampi(swing, 1, int(SWINGS.get(weapon, 3))), frame]


static func arc_key(weapon: String, swing: int, frame: int) -> String:
	return "fx_phantom_arc_%s_%d_%d" % [weapon, clampi(swing, 1, int(SWINGS.get(weapon, 3))), frame]


## How long one echo's effects run (ghost, arc, delayed spark).
static func echo_life() -> int:
	return maxi(sequence_length(GHOST_TICKS), maxi(sequence_length(ARC_TICKS), ECHO_SPARK_DELAY + sequence_length(ECHO_SPARK_TICKS)))


## Every sprite these effects can request (the glow overlays excepted: they are looked up per hero frame).
static func all_names() -> Array[String]:
	var names: Array[String] = []
	for group: Array in [["fx_lantern_place", 4], ["fx_lantern_idle", 6], ["fx_lantern_pulse", 4], ["fx_lantern_fade", 6], ["fx_lantern_pool_open", 3], ["fx_lantern_pool_idle", 4], ["fx_lantern_pool_pulse", 5], ["fx_lantern_motes", 6], ["fx_lantern_spark", 6], ["fx_phantom_start", 5], ["fx_phantom_end", 4], ["fx_phantom_spark", 5], ["fx_phantom_marker", 4], ["ui_aspect_spirit_lantern_lit", 4]]:
		for n: int in range(1, int(group[1]) + 1):
			names.append("%s_%d" % [group[0], n])
	for weapon: String in SWINGS:
		for swing: int in range(1, int(SWINGS[weapon]) + 1):
			for n: int in range(1, 5):
				names.append(ghost_key(weapon, swing, n))
				names.append(arc_key(weapon, swing, n))
	names.append("ui_aspect_spirit_lantern_1")
	names.append("ui_aspect_phantom_cut_1")
	return names
