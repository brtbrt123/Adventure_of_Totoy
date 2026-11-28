extends RefCounted
## How the road's Mossbound Colossus is drawn (docs/PLAN_colossus_step3.md, the owner's choices of 2026-11-27; its body since step 4,
## docs/PLAN_colossus_step4.md): the rigged body frames (tools/art/rig_colossus.py, approved 2026-11-28) picked per state and attack,
## its appearing, the fight camera that keeps it whole on screen, the hero's outline when he walks behind it, the glowing edges of
## its warnings, its chest light, and the sounds, shake and dust of its blows. It reads the snapshot only: the core
## (core/colossus.gd) decides every hit and time.
const ExploreCore := preload("res://core/explore_core.gd")
const Snapshots := preload("res://core/snapshots.gd")
const Tuning := preload("res://core/tuning.gd")
const TelegraphView := preload("res://presentation/arena/telegraph_view.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const WHITE := preload("res://art/build/sprites_white.png")
const Fireflies := preload("res://presentation/common/ambient_fireflies.gd")

const TYPE: StringName = &"colossus"
const FRAME: String = "colossus_idle_right_1"  # the standing frame: the camera and the hero's outline test use its size, every pose
const HEIGHT: float = 116.0  # its visible height standing (the owner's choice B)
const CHEST: float = 57.0  # the song's light above the feet, standing (colossus_frames.json has it per frame)
## The body (step 4, the owner's "Approve, do 4c", 2026-11-28): frames colossus_<set>_right_<n>, generated with the fists' and chest's
## points per frame and the appearing's ticks in colossus_frames.json. COUNTS is every set; ATTACK_SETS says which sets each attack
## plays (attacks that move alike share them).
const BODY: String = "colossus_%s_right_%d"
const FRAMES_DATA: String = "res://presentation/explore/colossus_frames.json"
const COUNTS: Dictionary = {"sleep": 2, "idle": 4, "walk": 6, "slam_windup": 3, "slam_strike": 2, "slam_recover": 1, "sweep_windup": 2,
	"sweep_strike": 4, "sweep_recover": 2, "shards_windup": 2, "shards_strike": 1, "shards_recover": 1, "stomp_windup": 2, "stomp_strike": 1,
	"stomp_recover": 1, "charge_windup": 2, "charge_run": 2, "charge_recover": 1, "snare_windup": 2, "snare_strike": 2, "boulder_windup": 2,
	"boulder_strike": 1, "grab_windup": 2, "grab_strike": 1, "grab_recover": 1, "broken": 2, "stagger": 2, "roar": 2, "death": 8}
const ATTACK_SETS: Dictionary = {
	&"gold_slam": {"windup": "slam_windup", "strike": "slam_strike", "recover": "slam_recover"},
	&"gold_combo": {"windup": "slam_windup", "strike": "slam_strike", "recover": "slam_recover"},
	&"red_sweep": {"windup": "sweep_windup", "strike": "sweep_strike", "recover": "sweep_recover"},
	&"red_shards": {"windup": "shards_windup", "strike": "shards_strike", "recover": "shards_recover"},
	&"red_stomp": {"windup": "stomp_windup", "strike": "stomp_strike", "recover": "stomp_recover"},
	&"red_charge": {"windup": "charge_windup", "strike": "charge_run", "recover": "charge_recover"},
	&"root_snare": {"windup": "snare_windup", "strike": "snare_strike", "recover": "slam_recover"},
	&"boulder_toss": {"windup": "boulder_windup", "strike": "boulder_strike", "recover": "slam_recover"},
	&"heartroot_grab": {"windup": "grab_windup", "strike": "grab_strike", "recover": "grab_recover"},
	&"song_flare": {"windup": "shards_windup", "strike": "shards_strike", "recover": "shards_recover"},
}
const SLEEP_TICKS: int = 40  # asleep it breathes this slowly (on the simulation tick: its state_ticks stay 0)
const IDLE_TICKS: int = 12
const WALK_TICKS: int = 8
const BROKEN_TICKS: int = 8  # the song flickers while the posture is broken
const STAGGER_TICKS: int = 4
const ROAR_TICKS: int = 6
const DEATH_TICKS: int = 5  # 8 frames in the 40 ticks it stays dead in the snapshot
const WINDUP_SPREAD: float = 0.75  # the windup frames play over this share of a warning; the last holds, trembling from TREMBLE
const TREMBLE: float = 0.8
const FALL_TICKS: int = 3  # the falling frame (a set's first strike frame, when it has two) shows this many ticks before the blow
const IMPACT_HOLD: int = 10  # between a combo's blows the impact holds this long before it raises its fists again
const RECOVER_HOLD: int = 16  # the recover frames (spread over this), then standing
## The Gold Sweep's swing (reworked, the owner's "Looks good, wire it", 2026-11-28): its four strike frames begin these ticks from the
## blow (each shows at least 2 ticks, so the arc reads), after the windup over its warning. Its dust: puffs across the real cone,
## two rows, one column a tick later than the last in the order the arm swings through it.
const SWEEP_SWING: Array[int] = [-4, -2, 0, 4]
const SWEEP_DUST: String = "fx_colossus_dust_%d"
const SWEEP_DUST_COUNT: int = 8
const SWEEP_PUFFS: int = 7
const SWEEP_ROWS: Array[float] = [0.55, 0.85]
## Step 5 (the owner's "Wire all five", 2026-11-28): the Gold Slam's and each Combo blow's impact (PixelFX impacts/ground-slam in stone
## and the song's blue, on the real circle), stone shards round the Red Stomp's ring and racing along the Red Shards' lanes (the
## approved fx_colossus_shard), and the pale dust trailing the Red Charge along its lane (fx_colossus_dust).
const SLAM: String = "fx_colossus_slam_%d"
const SLAM_COUNT: int = 15
const STOMP_SPACING: float = 40.0  # one shard every this many px round the middle of the ring's band
const LANE_FIRST: float = 30.0  # the Shards' first shard this far along its lane, then one every LANE_SPACING, a tick later each
const LANE_SPACING: float = 22.0
const CHARGE_SIDE: float = 22.0  # its two trails this far either side of the lane's middle (its feet)
## The Boulder Toss: it tears the stone up, holds it overhead until BOULDER_THROW of the warning, then throws; the stone lands on the
## warned circle on the tick it strikes (the flight is drawn shorter, the warning and its timing are the core's).
const BOULDER_RIP: float = 0.2
const BOULDER_THROW: float = 0.45
## The appearing (state alert): the body shakes while it breaks out, and at these alert ticks the floor breaks: stone shards where a
## fist bursts out, dust where both fists plant ([tick, x from its feet, kind, with a stomp and a shake]).
const APPEAR_SHAKE: Vector2i = Vector2i(14, 76)
const APPEAR_CUES: Array = [[20, -44.0, &"burst", true], [22, -32.0, &"burst", false], [24, -54.0, &"burst", false],
	[44, 44.0, &"burst", true], [46, 32.0, &"burst", false], [48, 54.0, &"burst", false], [70, -60.0, &"dust", true], [70, 60.0, &"dust", false]]
const VIEW: Vector2 = Vector2(384, 216)
## The fight camera: how near each screen edge the hero may get, and how fast the view slides when the fight starts or ends.
const HERO_SIDE: float = 28.0
const HERO_TOP: float = 44.0
const HERO_BOTTOM: float = 20.0
const SNAP_DISTANCE: float = 160.0  # a jump this far (a respawn) is not eased
const REACH: Vector2 = Vector2(116, 142)  # its widest and tallest poses round its feet (fists flung wide, fists overhead)
const OUTLINE: Color = Color("e0f0ec")  # water_6
const CHEST_COLOUR: Vector3 = Vector3(0.36, 0.82, 1.0)
const CHEST_CORE: Vector3 = Vector3(0.80, 0.96, 1.0)
## The sound of each blow as it lands (the arena's recordings).
const STRIKE_CUES: Dictionary = {&"gold_slam": "golem_slam", &"gold_combo": "golem_slam", &"red_stomp": "golem_stomp", &"red_sweep": "golem_sweep",
	&"red_charge": "golem_charge", &"red_shards": "golem_beam", &"root_snare": "golem_stomp", &"boulder_toss": "golem_slam", &"heartroot_grab": "golem_sweep",
	&"song_flare": "golem_beam", &"briar_ring": "golem_stomp"}
const BRIAR: StringName = &"briar_ring"  # the zone that rises at a phase change (core/colossus.gd): no marker, its edge stays drawn
const HEAVY: Array[StringName] = [&"gold_slam", &"gold_combo", &"red_stomp", &"boulder_toss"]

## The attacks' effects (PixelFX in Totoy 36, approved 2026-11-27; tools/art/import_pixelfx.py --install). Frames last 4 ticks.
const THORN: String = "fx_colossus_thorn_%d"
const THORN_COUNT: int = 11
const THORN_LEAD: int = 4  # the first frame (the floor cracking) shows this many ticks before the blow
const THORN_SPACING: float = 22.0  # one thorn every this many px along the lane, from the body's edge to the lane's real end
const THORN_FIRST: float = 50.0
const SHARD: String = "fx_colossus_shard_%d"  # the same burst in stone (the owner's option B, 2026-11-28), set round a ring of shock
const SHARDS: int = 14  # round the middle of the ring's real band (inner to outer radius)
## Part 3c (the owner's "Yes, wire them", 2026-11-28). The Briar Ring's wall: the root thorns standing just outside its safe circle
## while the briars stand (rise, hold, sink as they end). The Song Flare: song-blue shards on each ring as it strikes (sparse: denser
## ones hid the hero in a gap) and the song's light blowing out of its chest on the gold blow (PixelFX arcane/mana-burst, its frames
## SONG_BURST_FIRST.. every second one; SONG_BURST_LASH is the blow-out and meets the blow).
const WALL_OUTSIDE: float = 12.0  # the wall stands this far outside the safe circle
const WALL_SPACING: float = 22.0
const WALL_HOLD: Array[int] = [6, 7]  # the thorn frames that hold while the briars stand
const SONG_SHARD: String = "fx_colossus_song_shard_%d"
const SONG_SPACING: float = 56.0
const SONG_BURST: String = "fx_colossus_song_burst_%d"
const SONG_BURST_COUNT: int = 23
const SONG_BURST_FIRST: int = 10
const SONG_BURST_LASH: int = 16
const STONE_SPIN: String = "fx_colossus_stone_spin_%d"
const STONE_SPIN_COUNT: int = 18
const STONE_LAND: String = "fx_colossus_stone_land_%d"
const STONE_LAND_COUNT: int = 21
const APPEAR_DUST_FRAMES: int = 10  # the stone landing before its ring spreads
const STONE_HELD: String = "colossus_boulder_windup_right_2"  # the frame that holds the stone overhead, between its fists
const STONE_ARC: float = 70.0  # how high the throw rises above the straight line
const FRAME_TICKS: int = 4
## The Heartroot Grab's root-arm (PixelFX nature/vine-whip, the owner's "Yes, wire it", 2026-11-28): rendered every 15 degrees from -90
## (up the screen) to 90 (down), the left half drawn mirrored; ARM_SOURCES are the PixelFX frames kept (30 fps, 2 game ticks each),
## frame ARM_LASH is the lash and meets the blow. It grows out of the floor ARM_ROOT px along the lane, at the body's edge.
const ARM: String = "fx_colossus_arm_%d_%d"
const ARM_SOURCES: Array[int] = [1, 3, 5, 7, 9, 11, 13, 14, 15, 16, 18, 21, 24, 28, 32]
const ARM_ANGLES: int = 13
const ARM_LASH: int = 15
const ARM_ROOT: float = 40.0

var _seen_hits: Dictionary = {}  # telegraph id -> true once its blow landed (sound, shake, dust once)
var _previous: Array[Snapshots.TelegraphSnapshot] = []
var _ghosts: Dictionary = {}  # hero frame key -> ImageTexture (outline + every other pixel)
var _atlas_image: Image = null
var _last_tick: int = -1
## Effects still playing after their blow: {kind (&"thorns", &"land", &"shards" or &"arm"), tick (the blow), at, direction, size, radius}.
var effects: Array[Dictionary] = []
var missing: Dictionary = {}  # body and effect frames asked for but not in the atlas (warned once)
var _appear_seen: Dictionary = {}  # APPEAR_CUES index -> true once played this waking
var _body_tick: int = -1
var _body_at: Vector2 = Vector2.INF
var _walking: bool = false
static var _data: Dictionary = {}


func clear() -> void:
	_seen_hits.clear()
	_previous.clear()
	_last_tick = -1
	effects.clear()
	_appear_seen.clear()
	_body_tick = -1
	_body_at = Vector2.INF
	_walking = false


## Every effect frame this view may ask for (smoke_colossus checks they are all in the atlas).
static func effect_frames() -> Array[String]:
	var out: Array[String] = []
	for n: int in range(1, THORN_COUNT + 1):
		out.append(THORN % n)
		out.append(SHARD % n)
		out.append(SONG_SHARD % n)
	for n: int in range(1, SONG_BURST_COUNT + 1):
		out.append(SONG_BURST % n)
	for n: int in range(1, SWEEP_DUST_COUNT + 1):
		out.append(SWEEP_DUST % n)
	for n: int in range(1, SLAM_COUNT + 1):
		out.append(SLAM % n)
	for n: int in range(1, STONE_SPIN_COUNT + 1):
		out.append(STONE_SPIN % n)
	for n: int in range(1, STONE_LAND_COUNT + 1):
		out.append(STONE_LAND % n)
	for a: int in ARM_ANGLES:
		for n: int in range(1, ARM_SOURCES.size() + 1):
			out.append(ARM % [a, n])
	return out


## The song burst's frame `ticks` after the gold blow (negative before it); 0 = not shown. PixelFX runs at 30 fps: 2 ticks a frame.
static func _burst_frame(ticks: int) -> int:
	var source: int = SONG_BURST_LASH + floori(float(ticks) / 2.0)
	if source < SONG_BURST_FIRST:
		return 0
	var n: int = (source - SONG_BURST_FIRST) / 2 + 1
	return n if n <= SONG_BURST_COUNT else 0


## The thorn wall round a standing Briar Ring `t`: up as the briars rise, holding, down over the last ticks.
func _wall_items(t: Snapshots.TelegraphSnapshot, tick: int, tint: Color) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var radius: float = t.inner_size + WALL_OUTSIDE
	var count: int = roundi(TAU * radius / WALL_SPACING)
	var age: int = tick - t.hit_tick
	var left: int = t.end_tick - tick
	for k: int in count:
		var n: int = WALL_HOLD[k % WALL_HOLD.size()]
		var rising: int = floori(float(age - k % 4 + THORN_LEAD) / FRAME_TICKS) + 1
		if rising < WALL_HOLD[0]:
			n = rising
		if left < (THORN_COUNT - WALL_HOLD[-1]) * FRAME_TICKS:  # sinking as the briars end
			n = THORN_COUNT - left / FRAME_TICKS
		if n < 1 or n > THORN_COUNT:
			continue
		var spot: Vector2 = t.center + Vector2.from_angle(TAU * float(k) / float(count)) * radius
		out.append({"kind": &"colossus_fx", "id": "colossus_wall_%d" % k, "at": spot.round(), "frame": THORN % n, "tint": tint})
	return out


## The root-arm's frame (1-based in ARM_SOURCES) `ticks` after the lash (negative before it); 0 = not shown.
static func arm_frame(ticks: int) -> int:
	var source: float = float(ticks) / 2.0 + float(ARM_LASH)
	if source < float(ARM_SOURCES[0]) or source > float(ARM_SOURCES[-1] + 3):
		return 0
	var n: int = 0
	for i: int in ARM_SOURCES.size():
		if float(ARM_SOURCES[i]) <= source:
			n = i + 1
	return n


## The rendered angle nearest the lane: [angle index 0..12, mirrored (the lane points left)].
static func arm_angle(direction: Vector2) -> Array:
	var mirrored: bool = direction.x < 0.0
	var degrees: float = rad_to_deg(atan2(direction.y, absf(direction.x)))
	return [clampi(roundi((degrees + 90.0) / 15.0), 0, ARM_ANGLES - 1), mirrored]


func _arm_item(id: String, root: Vector2, direction: Vector2, ticks: int, tint: Color) -> Dictionary:
	var n: int = arm_frame(ticks)
	if n == 0:
		return {}
	var angle: Array = arm_angle(direction)
	return {"kind": &"colossus_fx", "id": id, "at": root.round(), "frame": ARM % [int(angle[0]), n], "left": bool(angle[1]), "tint": tint}


## The effects standing on the floor, as items for the scene's depth sort ({kind colossus_fx, id, at (feet), frame, tint}).
func effect_items(view: ExploreCore.ExploreSnapshot, tint: Color) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	effects = effects.filter(func(e: Dictionary) -> bool: return view.tick - int(e["tick"]) < _lifetime(e) and view.tick >= int(e["tick"]) - THORN_LEAD)
	for t: Snapshots.TelegraphSnapshot in view.telegraphs:  # the Briar Ring's thorn wall while the briars stand
		if t.attack == BRIAR and view.tick >= t.hit_tick and view.tick <= t.end_tick:
			out.append_array(_wall_items(t, view.tick, tint))
		elif t.attack == &"song_flare" and t.kind == &"gold" and view.tick < t.hit_tick:  # the song gathers before the gold blow
			var n: int = _burst_frame(view.tick - t.hit_tick)
			if n > 0:
				out.append({"kind": &"colossus_fx", "id": "colossus_burst_%d" % t.id, "at": t.center.round(), "frame": SONG_BURST % n, "tint": tint})
	for t: Snapshots.TelegraphSnapshot in view.telegraphs:  # the root-arm rises during the Grab's warning
		if t.attack == &"heartroot_grab" and view.tick < t.hit_tick:
			var rising: Dictionary = _arm_item("colossus_arm_%d" % t.id, t.center + t.direction * ARM_ROOT, t.direction, view.tick - t.hit_tick, tint)
			if not rising.is_empty():
				out.append(rising)
	for i: int in effects.size():
		var e: Dictionary = effects[i]
		var age: int = view.tick - int(e["tick"])
		if e["kind"] == &"thorns":  # one thorn after another along the lane, a tick later each: the crack races out
			var k: int = 0
			var d: float = THORN_FIRST
			while d <= float(e["size"]):
				var n: int = floori(float(age - k + THORN_LEAD) / FRAME_TICKS) + 1  # floor: not yet = 0
				if n >= 1 and n <= THORN_COUNT:
					var side: Vector2 = Vector2(e["direction"]).orthogonal() * (4.0 if k % 2 == 0 else -4.0)
					out.append({"kind": &"colossus_fx", "id": "colossus_fx_%d_%d" % [i, k], "at": (Vector2(e["at"]) + Vector2(e["direction"]) * d + side).round(), "frame": THORN % n, "tint": tint})
				d += THORN_SPACING
				k += 1
		elif e["kind"] == &"arm":  # the lash, then the arm sliding back into the floor
			var lashing: Dictionary = _arm_item("colossus_fx_%d" % i, e["at"], e["direction"], age, tint)
			if not lashing.is_empty():
				out.append(lashing)
		elif e["kind"] == &"song_ring":  # song-blue shards on a Song Flare ring
			var count: int = maxi(6, roundi(TAU * float(e["radius"]) / SONG_SPACING))
			for k: int in count:
				var n: int = floori(float(age - k % 3 + THORN_LEAD) / FRAME_TICKS) + 1
				if n >= 1 and n <= THORN_COUNT:
					var spot: Vector2 = Vector2(e["at"]) + Vector2.from_angle(TAU * float(k) / float(count)) * float(e["radius"])
					out.append({"kind": &"colossus_fx", "id": "colossus_fx_%d_%d" % [i, k], "at": spot.round(), "frame": SONG_SHARD % n, "tint": tint})
		elif e["kind"] == &"song_burst":
			var b: int = _burst_frame(age)
			if b > 0:
				out.append({"kind": &"colossus_fx", "id": "colossus_fx_%d" % i, "at": Vector2(e["at"]).round(), "frame": SONG_BURST % b, "tint": tint})
		elif e["kind"] == &"sweep_dust":  # the Gold Sweep: pale dust across the real cone, in the order the arm swings through it
			for k: int in SWEEP_PUFFS:
				var angle: float = Vector2(e["direction"]).angle() - float(e["half"]) * (1.0 - 2.0 * float(k) / float(SWEEP_PUFFS - 1))
				var n: int = floori(float(age - k) / FRAME_TICKS) + 1
				if n < 1 or n > SWEEP_DUST_COUNT:
					continue
				for r: int in SWEEP_ROWS.size():
					var spot: Vector2 = Vector2(e["at"]) + Vector2.from_angle(angle) * float(e["size"]) * SWEEP_ROWS[r]
					out.append({"kind": &"colossus_fx", "id": "colossus_fx_%d_%d_%d" % [i, k, r], "at": spot.round(), "frame": SWEEP_DUST % n, "tint": tint})
		elif e["kind"] == &"slam":
			var n: int = age / FRAME_TICKS + 1
			if n >= 1 and n <= SLAM_COUNT:
				out.append({"kind": &"colossus_fx", "id": "colossus_fx_%d" % i, "at": Vector2(e["at"]).round(), "frame": SLAM % n, "tint": tint})
		elif e["kind"] == &"stomp":
			var count: int = roundi(TAU * float(e["radius"]) / STOMP_SPACING)
			for k: int in count:
				var n: int = floori(float(age - k % 3) / FRAME_TICKS) + 1
				if n >= 1 and n <= THORN_COUNT:
					var spot: Vector2 = Vector2(e["at"]) + Vector2.from_angle(TAU * float(k) / float(count)) * float(e["radius"])
					out.append({"kind": &"colossus_fx", "id": "colossus_fx_%d_%d" % [i, k], "at": spot.round(), "frame": SHARD % n, "tint": tint})
		elif e["kind"] == &"shard_lane":
			var k: int = 0
			var d: float = LANE_FIRST
			while d <= float(e["size"]):
				var n: int = floori(float(age - k) / FRAME_TICKS) + 1
				if n >= 1 and n <= THORN_COUNT:
					var side: Vector2 = Vector2(e["direction"]).orthogonal() * (3.0 if k % 2 == 0 else -3.0)
					out.append({"kind": &"colossus_fx", "id": "colossus_fx_%d_%d" % [i, k], "at": (Vector2(e["at"]) + Vector2(e["direction"]) * d + side).round(), "frame": SHARD % n, "tint": tint})
				d += LANE_SPACING
				k += 1
		elif e["kind"] == &"charge_dust":
			var run: int = int(e["run"])
			for k: int in range(0, run, 2):
				var n: int = (age - k) / FRAME_TICKS + 1
				if age < k or n > SWEEP_DUST_COUNT:
					continue
				var along: Vector2 = Vector2(e["at"]) + Vector2(e["direction"]) * float(e["size"]) * float(k + 1) / float(run)
				for s: int in 2:
					var spot: Vector2 = along + Vector2(e["direction"]).orthogonal() * (CHARGE_SIDE if s == 0 else -CHARGE_SIDE)
					out.append({"kind": &"colossus_fx", "id": "colossus_fx_%d_%d_%d" % [i, k, s], "at": spot.round(), "frame": SWEEP_DUST % n, "tint": tint})
		elif e["kind"] == &"burst":  # the appearing: stone shards where a fist breaks out of the floor
			var n: int = floori(float(age) / FRAME_TICKS) + 1
			if n >= 1 and n <= THORN_COUNT:
				out.append({"kind": &"colossus_fx", "id": "colossus_fx_%d" % i, "at": Vector2(e["at"]).round(), "frame": SHARD % n, "tint": tint})
		elif e["kind"] == &"dust":  # the appearing: dust where its fists plant (the stone landing's first, dust-only frames)
			var n: int = age / 2 + 1
			if n >= 1 and n <= APPEAR_DUST_FRAMES:
				out.append({"kind": &"colossus_fx", "id": "colossus_fx_%d" % i, "at": Vector2(e["at"]).round(), "frame": STONE_LAND % n, "tint": tint})
		elif e["kind"] == &"shards":  # stone shards burst up round the ring of shock, over its whole band
			for k: int in SHARDS:
				var n: int = floori(float(age - k % 3 + THORN_LEAD) / FRAME_TICKS) + 1
				if n >= 1 and n <= THORN_COUNT:
					var spot: Vector2 = Vector2(e["at"]) + Vector2.from_angle(TAU * float(k) / float(SHARDS)) * float(e["radius"])
					out.append({"kind": &"colossus_fx", "id": "colossus_fx_%d_%d" % [i, k], "at": spot.round(), "frame": SHARD % n, "tint": tint})
		else:
			var n: int = age / FRAME_TICKS + 1
			if n >= 1 and n <= STONE_LAND_COUNT:
				out.append({"kind": &"colossus_fx", "id": "colossus_fx_%d" % i, "at": Vector2(e["at"]).round(), "frame": STONE_LAND % n, "tint": tint})
	return out


static func _lifetime(e: Dictionary) -> int:
	if e["kind"] == &"thorns":
		return THORN_COUNT * FRAME_TICKS + int(float(e["size"]) / THORN_SPACING) + 1
	if e["kind"] == &"shards" or e["kind"] == &"song_ring":
		return THORN_COUNT * FRAME_TICKS + 3
	if e["kind"] == &"burst":
		return THORN_COUNT * FRAME_TICKS
	if e["kind"] == &"sweep_dust":
		return SWEEP_DUST_COUNT * FRAME_TICKS + SWEEP_PUFFS
	if e["kind"] == &"slam":
		return SLAM_COUNT * FRAME_TICKS
	if e["kind"] == &"stomp":
		return THORN_COUNT * FRAME_TICKS + 3
	if e["kind"] == &"shard_lane":
		return THORN_COUNT * FRAME_TICKS + int(float(e["size"]) / LANE_SPACING) + 1
	if e["kind"] == &"charge_dust":
		return SWEEP_DUST_COUNT * FRAME_TICKS + int(e["run"])
	if e["kind"] == &"dust":
		return APPEAR_DUST_FRAMES * 2
	if e["kind"] == &"song_burst":
		return (SONG_BURST_FIRST + SONG_BURST_COUNT * 2 - SONG_BURST_LASH) * 2
	if e["kind"] == &"arm":
		return (ARM_SOURCES[-1] + 3 - ARM_LASH) * 2 + 1
	return STONE_LAND_COUNT * FRAME_TICKS


## One effect item at its anchor (`frame` of the atlas); a missing frame warns once and draws nothing.
func draw_effect(canvas: CanvasItem, item: Dictionary, frames: Dictionary, sprites: Texture2D) -> void:
	var key: String = item["frame"]
	if not frames.has(key):
		if not missing.has(key):
			missing[key] = true
			push_warning("Missing Colossus effect frame: " + key)
		return
	var f: Dictionary = frames[key]
	var rect: Rect2 = ArenaAnimation.destination(Vector2(item["at"]), f, bool(item.get("left", false)))  # the actors' rule, mirroring too
	canvas.draw_texture_rect_region(sprites, rect, Rect2(f["x"], f["y"], f["w"], f["h"]), item["tint"])


## The stone of a Boulder Toss: held overhead between its fists, then thrown along an arc onto the warned circle, landing on the
## tick the warning strikes. Its shadow on the floor grows as it falls (stone_shadows, under the actors).
func draw_stones(canvas: CanvasItem, view: ExploreCore.ExploreSnapshot, frames: Dictionary, sprites: Texture2D, tint: Color) -> void:
	for t: Snapshots.TelegraphSnapshot in view.telegraphs:
		if t.attack != &"boulder_toss" or t.shape != &"circle" or view.tick >= t.hit_tick:
			continue
		var progress: float = _warned(t, view.tick)
		if progress < BOULDER_RIP:
			continue
		var held: Vector2 = t.muzzle + (attach(STONE_HELD, "fist_l") + attach(STONE_HELD, "fist_r")) * 0.5 + Vector2(0, -4)
		if progress < BOULDER_THROW:
			draw_effect(canvas, {"at": held, "frame": STONE_SPIN % 1, "tint": tint}, frames, sprites)
			continue
		var flight: float = (progress - BOULDER_THROW) / (1.0 - BOULDER_THROW)
		var at: Vector2 = held.lerp(t.center, flight) + Vector2(0, -sin(flight * PI) * STONE_ARC)
		var n: int = posmod(view.tick / 2, STONE_SPIN_COUNT) + 1
		draw_effect(canvas, {"at": at, "frame": STONE_SPIN % n, "tint": tint}, frames, sprites)


func stone_shadows(view: ExploreCore.ExploreSnapshot) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Snapshots.TelegraphSnapshot in view.telegraphs:
		if t.attack == &"boulder_toss" and t.shape == &"circle" and view.tick < t.hit_tick and _warned(t, view.tick) >= BOULDER_THROW:
			var flight: float = (_warned(t, view.tick) - BOULDER_THROW) / (1.0 - BOULDER_THROW)
			out.append({"at": t.center, "radius": 4.0 + 12.0 * flight})
	return out


## How far a warning has run, 0 at its start to 1 when it strikes.
static func _warned(t: Snapshots.TelegraphSnapshot, tick: int) -> float:
	return clampf(float(tick - t.start_tick) / maxf(1.0, float(t.hit_tick - t.start_tick)), 0.0, 1.0)


static func is_colossus(mob: Dictionary) -> bool:
	return mob.get("type", &"") == TYPE


## The Colossus of the snapshot, {} when the scene has none.
static func find(view: ExploreCore.ExploreSnapshot) -> Dictionary:
	for mob: Dictionary in view.mobs:
		if is_colossus(mob):
			return mob
	return {}


## The Colossus whose fight is on (awake, alive): the camera frames it and the HUD shows its panel.
static func fighting(view: ExploreCore.ExploreSnapshot) -> Dictionary:
	var mob: Dictionary = find(view)
	if mob.is_empty() or mob["state"] in [&"idle", &"dead"]:
		return {}
	return mob


# ---- the body ---------------------------------------------------------------------------------------------------------------

## The data of the generated frames (fists and chest per frame, the appearing's ticks), read once.
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FRAMES_DATA))
		_data = parsed if parsed is Dictionary else {"appear_ticks": [0], "attach": {}}
	return _data


## A frame's point (`fist_l`, `fist_r` or `chest`) in pixels from its feet; the standing chest when the frame has none.
static func attach(frame: String, point: String) -> Vector2:
	var pair: Variant = data()["attach"].get(frame, {}).get(point, null)
	return Vector2(float(pair[0]), float(pair[1])) if pair is Array else Vector2(0, -CHEST)


## Every body frame this view may ask for (smoke_colossus checks they are all in the atlas).
static func body_frames() -> Array[String]:
	var out: Array[String] = []
	for set_name: String in COUNTS:
		for n: int in range(1, int(COUNTS[set_name]) + 1):
			out.append(BODY % [set_name, n])
	for n: int in range(1, (data()["appear_ticks"] as Array).size() + 1):
		out.append(BODY % ["appear", n])
	return out


static func _f(set_name: String, n: int, shake: int = 0) -> Dictionary:
	return {"frame": BODY % [set_name, n], "shake": shake}


## The body frame for this tick and how hard it shakes ({frame, shake}), from the snapshot only: its state and state_ticks, its
## attack and the ticks of that attack's warnings. `moving`: it walked since the last tick (chase plays the walk only then).
static func body_frame(mob: Dictionary, tells: Array[Snapshots.TelegraphSnapshot], tick: int, moving: bool) -> Dictionary:
	var t: int = int(mob["state_ticks"])
	match mob["state"]:
		&"idle":
			return _f("sleep", 1 + posmod(tick / SLEEP_TICKS, 2))
		&"alert":
			var ticks: Array = data()["appear_ticks"]
			var n: int = 1
			for i: int in ticks.size():
				if t >= int(ticks[i]):
					n = i + 1
			return _f("appear", n, 1 if t >= APPEAR_SHAKE.x and t < APPEAR_SHAKE.y else 0)
		&"chase":
			return _f("walk", 1 + posmod(tick / WALK_TICKS, 6)) if moving else _f("idle", 1 + posmod(tick / IDLE_TICKS, 4))
		&"windup", &"strike":
			return _attack_frame(mob, tells, tick)
		&"recover":
			var sets: Dictionary = ATTACK_SETS.get(StringName(mob.get("attack_id", &"")), {})
			if t >= RECOVER_HOLD or sets.is_empty():
				return _f("idle", 1)
			return _f(sets["recover"], 1 + t * int(COUNTS[sets["recover"]]) / RECOVER_HOLD)
		&"posture_broken":
			return _f("broken", 1 + posmod(t / BROKEN_TICKS, 2))
		&"stagger":
			return _f("stagger", 1 + posmod(t / STAGGER_TICKS, 2), 1)
		&"roar":
			return _f("roar", 1 + posmod(t / ROAR_TICKS, 2), 1)
		&"dead":
			return _f("death", mini(int(COUNTS["death"]), t / DEATH_TICKS + 1), 1 if t < 15 else 0)
	return _f("idle", 1)


## An attack's frame: the windup over its first warning, then the blows. Between a combo's blows the fists rise again; the Root
## Snare's second lane takes the other fist; the Boulder Toss holds and throws its stone; the Song Flare bursts on each ring and
## gathers the song (the roar) for its gold blow.
static func _attack_frame(mob: Dictionary, tells: Array[Snapshots.TelegraphSnapshot], tick: int) -> Dictionary:
	var attack: StringName = StringName(mob.get("attack_id", &""))
	var sets: Dictionary = ATTACK_SETS.get(attack, ATTACK_SETS[&"gold_slam"])
	var mine: Array[Snapshots.TelegraphSnapshot] = []
	for tell: Snapshots.TelegraphSnapshot in tells:
		if tell.owner_id == int(mob["id"]) and tell.attack != BRIAR:
			mine.append(tell)
	if mine.is_empty():
		return _f("idle", 1)
	mine.sort_custom(func(a: Snapshots.TelegraphSnapshot, b: Snapshots.TelegraphSnapshot) -> bool: return a.hit_tick < b.hit_tick)
	var last: Snapshots.TelegraphSnapshot = null  # the latest blow that has landed
	var next: Snapshots.TelegraphSnapshot = null  # the next one to land
	var landed_count: int = 0
	for tell: Snapshots.TelegraphSnapshot in mine:
		if tell.hit_tick <= tick:
			last = tell
			landed_count += 1
		elif next == null:
			next = tell
	var windup: String = sets["windup"]
	var strike: String = sets["strike"]
	var wn: int = int(COUNTS[windup])
	var sn: int = int(COUNTS[strike])
	match attack:
		&"song_flare":
			var gold: Snapshots.TelegraphSnapshot = null
			for tell: Snapshots.TelegraphSnapshot in mine:
				if tell.kind == &"gold":
					gold = tell
			if last == null:
				return _windup(windup, wn, strike, 1, next, tick)
			if gold != null and tick >= gold.hit_tick:
				return _f("roar", 2, 2 if tick - gold.hit_tick < 8 else 0)
			if gold != null and next == gold:  # the rings are done: the song gathers for the gold blow
				return _f("roar", 1, 1 if gold.hit_tick - tick <= 12 else 0)
			return _f(strike, 1, 1) if tick - last.hit_tick < 6 else _f(windup, wn)
		&"boulder_toss":
			if last == null:
				var p: float = _warned(next, tick)
				if p < BOULDER_RIP:
					return _f(windup, 1)
				if p < BOULDER_THROW:
					return _f(windup, 2, 1 if p > BOULDER_THROW - 0.08 else 0)
				return _f(strike, 1)
			return _f("slam_recover", 1) if tick - mine[0].hit_tick < 24 else _f("idle", 1)
		&"root_snare":
			if last == null:
				return _f(windup, 1, 1 if _warned(next, tick) > TREMBLE else 0)
			if landed_count == 1 and next != null and tick - last.hit_tick >= IMPACT_HOLD - 2:  # the second lane: the other fist
				return _f(windup, 2, 1 if next.hit_tick - tick <= 8 else 0)
			return _f(strike, mini(landed_count, sn), 1 if tick - last.hit_tick < 6 else 0)
		&"red_sweep":  # the windup, then the swing's frames on their own ticks round the blow
			var blow: Snapshots.TelegraphSnapshot = next if last == null else last
			var to: int = tick - blow.hit_tick
			if to < SWEEP_SWING[0]:
				return _windup(windup, wn, strike, 1, blow, tick)
			var n: int = 1
			for i: int in SWEEP_SWING.size():
				if to >= SWEEP_SWING[i]:
					n = i + 1
			return _f(strike, n)
		&"red_charge":
			if last == null:
				return _windup(windup, wn, strike, 1, next, tick)
			return _f(strike, 1 + posmod(tick / 3, 2)) if tick <= last.end_tick else _f(sets["recover"], 1)
	if last == null:
		return _windup(windup, wn, strike, sn, next, tick)
	if next != null:  # between a combo's blows: hold the impact, raise the fists again, let them fall
		var since: int = tick - last.hit_tick
		var to: int = next.hit_tick - tick
		if to <= FALL_TICKS and sn > 1:
			return _f(strike, 1)
		if since > IMPACT_HOLD:
			var q: float = float(since - IMPACT_HOLD) / float(maxi(1, since - IMPACT_HOLD + to - FALL_TICKS))
			return _f(windup, clampi(2 + floori(q * float(wn - 1)), mini(2, wn), wn), 1 if to <= 12 else 0)
		return _f(strike, sn)
	return _f(strike, sn, 1 if tick - last.hit_tick < 8 else 0)


## The windup toward warning `next`: its frames over WINDUP_SPREAD of it, the last held and trembling from TREMBLE, and with two
## strike frames the first (the blow falling) in the last FALL_TICKS.
static func _windup(windup: String, wn: int, strike: String, sn: int, next: Snapshots.TelegraphSnapshot, tick: int) -> Dictionary:
	var p: float = _warned(next, tick)
	if sn > 1 and next.hit_tick - tick <= FALL_TICKS:
		return _f(strike, 1)
	return _f(windup, mini(wn, 1 + floori(p / WINDUP_SPREAD * float(wn))), 1 if p > TREMBLE else 0)


## Whether it walked since the last tick (position memory for the walk cycle only; nothing rules-bearing).
func _moved(mob: Dictionary, tick: int) -> bool:
	if tick != _body_tick:
		var at: Vector2 = mob["position"]
		_walking = _body_at != Vector2.INF and at.distance_to(_body_at) > 0.05
		_body_at = at
		_body_tick = tick
	return _walking


## Draws the body at its feet: this tick's frame (body_frame), shaking sideways when it trembles, white for a few ticks after a blow.
## A frame missing from the atlas warns once and draws the standing frame instead.
func draw_body(canvas: CanvasItem, item: Dictionary, frames: Dictionary, sprites: Texture2D, tells: Array[Snapshots.TelegraphSnapshot], tick: int) -> void:
	var mob: Dictionary = item["mob"]
	var pick: Dictionary = body_frame(mob, tells, tick, _moved(mob, tick))
	var key: String = pick["frame"]
	if not frames.has(key):
		if not missing.has(key):
			missing[key] = true
			push_warning("Missing Colossus body frame: " + key)
		key = FRAME
		if not frames.has(key):
			return
	var frame: Dictionary = frames[key]
	var shake: float = float(int(pick["shake"]) * (1 if posmod(tick / 2, 2) == 0 else -1))
	var corner: Vector2 = (Vector2(item["at"]).round() - Vector2(float(frame["ax"]), float(frame["ay"])) + Vector2(shake, 0.0)).round()
	var white: bool = int(mob.get("since_hit", 1000)) < 4 and mob["state"] != &"dead"
	var size: Vector2 = Vector2(float(frame["w"]), float(frame["h"]))
	canvas.draw_texture_rect_region(WHITE if white else sprites, Rect2(corner, size), Rect2(float(frame["x"]), float(frame["y"]), size.x, size.y), item["tint"])


## Where the song's light sits in its chest this tick (asleep and while it is still in the ground: just above the floor).
static func chest_at(mob: Dictionary, tells: Array[Snapshots.TelegraphSnapshot], tick: int) -> Vector2:
	var feet: Vector2 = mob["position"]
	if mob["state"] == &"idle":
		return feet - Vector2(0, 7)
	var chest: Vector2 = feet + attach(String(body_frame(mob, tells, tick, false)["frame"]), "chest")
	return Vector2(chest.x, minf(chest.y, feet.y - 7.0))


## The drawn rectangle of the body (for the hero's outline test and the camera).
static func body_rect(mob: Dictionary, frames: Dictionary) -> Rect2:
	var frame: Dictionary = frames.get(FRAME, {"w": 144, "h": 120, "ax": 72, "ay": 118})
	return Rect2(Vector2(mob["position"]) - Vector2(float(frame["ax"]), float(frame["ay"])), Vector2(float(frame["w"]), float(frame["h"])))


## Where the hero's blow meets the body: on its side facing him, at chest height.
static func contact(mob: Dictionary, hero: Vector2) -> Vector2:
	var at: Vector2 = mob["position"]
	var toward: Vector2 = (hero - at).normalized() if hero.distance_to(at) > 0.5 else Vector2.DOWN
	return at + toward * (float(mob["radius"]) - 6.0) + Vector2(0, -30)


# ---- the hero behind it -----------------------------------------------------------------------------------------------------

## The hero stands behind the body: a pale one-pixel outline of his frame and every other pixel of it, over the boss.
func draw_hero_ghost(canvas: CanvasItem, mob: Dictionary, hero_at: Vector2, hero_key: String, left: bool, frames: Dictionary, sprites: Texture2D, tint: Color) -> void:
	if not frames.has(hero_key) or mob["state"] == &"dead" or hero_at.y >= Vector2(mob["position"]).y:
		return
	var frame: Dictionary = frames[hero_key]
	var rect: Rect2 = ArenaAnimation.destination(hero_at, frame, left).abs()
	if not rect.intersects(body_rect(mob, frames)):
		return
	var ghost: ImageTexture = _ghost(hero_key, frame, sprites)
	if ghost != null:
		canvas.draw_texture_rect(ghost, ArenaAnimation.destination(hero_at, frame, left), false, tint)


func _ghost(key: String, frame: Dictionary, sprites: Texture2D) -> ImageTexture:
	if _ghosts.has(key):
		return _ghosts[key]
	if _atlas_image == null:
		_atlas_image = sprites.get_image()
		if _atlas_image == null:
			return null
		_atlas_image.convert(Image.FORMAT_RGBA8)
	var source: Image = _atlas_image.get_region(Rect2i(int(frame["x"]), int(frame["y"]), int(frame["w"]), int(frame["h"])))
	var out: Image = Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	var bounds: Rect2i = Rect2i(Vector2i.ZERO, source.get_size())
	for y: int in source.get_height():
		for x: int in source.get_width():
			if source.get_pixel(x, y).a > 0.5:
				if (x + y) % 2 == 0:
					out.set_pixel(x, y, source.get_pixel(x, y))
				continue
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var near: Vector2i = Vector2i(x, y) + step
				if bounds.has_point(near) and source.get_pixelv(near).a > 0.5:
					out.set_pixel(x, y, OUTLINE)
					break
	var texture: ImageTexture = ImageTexture.create_from_image(out)
	_ghosts[key] = texture
	return texture


# ---- warnings ---------------------------------------------------------------------------------------------------------------

## Its warnings' edges once more, unlit and 2 px wide, so the night floor does not dim them; and while the Briar Ring stands, the
## edge of its safe circle.
static func draw_glowing_edges(canvas: CanvasItem, view: ExploreCore.ExploreSnapshot, colors: Dictionary) -> void:
	var boss: Dictionary = find(view)
	if boss.is_empty():
		return
	for t: Snapshots.TelegraphSnapshot in view.telegraphs:
		if t.attack == BRIAR and view.tick >= t.hit_tick and view.tick <= t.end_tick:  # standing: the safe circle's edge stays drawn
			var edge: PackedVector2Array = TelegraphView.ring_points(t.center, t.inner_size)
			canvas.draw_polyline(edge, Color(colors["0"], Fireflies.EMISSIVE_ALPHA), 4.0)
			canvas.draw_polyline(edge, Color(colors["z"], Fireflies.EMISSIVE_ALPHA), 2.0)
			continue
		if t.owner_id != int(boss["id"]) or not TelegraphView.warning_visible(t, view.tick):
			continue
		var colour: Color = colors["x"] if t.kind == &"gold" else colors["z"]
		var edges: Array[PackedVector2Array] = [TelegraphView.outline(t)]
		if t.shape == &"ring":
			edges.append(TelegraphView.ring_points(t.center, t.inner_size))
		for edge: PackedVector2Array in edges:
			canvas.draw_polyline(edge, Color(colors["0"], Fireflies.EMISSIVE_ALPHA), 4.0)
			canvas.draw_polyline(edge, Color(colour, Fireflies.EMISSIVE_ALPHA), 2.0)


# ---- the camera -------------------------------------------------------------------------------------------------------------

## The view's top-left corner in the fight: the hero-centred view slid only as far as it takes to show the whole body (and, where
## it fits, its reach: fists raised overhead or flung wide), the hero kept off the screen's edges, inside the scene.
static func fight_view(hero: Vector2, mob: Dictionary, frames: Dictionary, scene_size: Vector2) -> Vector2:
	var origin: Vector2 = hero - VIEW * 0.5
	var reach: Rect2 = Rect2(Vector2(mob["position"]) - REACH, Vector2(REACH.x * 2.0, REACH.y + 2.0)).grow(4.0)
	origin = origin.clamp(reach.end - VIEW, reach.position.max(reach.end - VIEW))
	var box: Rect2 = body_rect(mob, frames).grow(4.0)
	origin = origin.clamp(box.end - VIEW, box.position.max(box.end - VIEW))
	origin = origin.clamp(hero - VIEW + Vector2(HERO_SIDE, HERO_BOTTOM), hero - Vector2(HERO_SIDE, HERO_TOP))
	return origin.round().clamp(Vector2.ZERO, (scene_size - VIEW).max(Vector2.ZERO))


## One step of the view toward `target`. Only `blending` (the fight framing just switched on or off) eases; otherwise the view is
## exactly the target, as it always was (no lag behind a dash). A jump (a respawn) never eases. Returns [view, still blending].
static func ease_view(current: Vector2, target: Vector2, blending: bool) -> Array:
	var gap: float = current.distance_to(target)
	if not blending or gap > SNAP_DISTANCE or gap < 1.0:
		return [target, false]
	return [current.move_toward(target, maxf(2.0, gap * 0.15)).round(), true]


# ---- light ------------------------------------------------------------------------------------------------------------------

## The song's light in its chest (a halo and a pool on the floor): faint asleep, full awake, none once it has fallen.
static func lamps(view: ExploreCore.ExploreSnapshot) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var mob: Dictionary = find(view)
	if mob.is_empty() or mob["state"] == &"dead":
		return out
	var feet: Vector2 = mob["position"]
	var asleep: bool = mob["state"] == &"idle"
	var chest: Vector2 = chest_at(mob, view.telegraphs, view.tick)
	out.append({"point": Vector4(chest.x, chest.y, 20.0 if asleep else 56.0, 0.35 if asleep else 1.1), "colour": CHEST_COLOUR, "core": CHEST_CORE})
	out.append({"point": Vector4(feet.x, feet.y + 6.0, 50.0 if asleep else 140.0, -(0.3 if asleep else 1.2)), "colour": CHEST_COLOUR, "core": CHEST_CORE})
	return out


# ---- blows landing: sound, shake, dust ----------------------------------------------------------------------------------------

## Once per snapshot tick: the blows that landed this tick. Returns [{attack, at, heavy}] for the scene to sound, shake and dust.
## A parry can clear a warning on the tick it lands, so the last tick's warnings count too.
func landed(view: ExploreCore.ExploreSnapshot) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if view.tick == _last_tick:
		return out
	if view.tick < _last_tick:
		clear()
	_last_tick = view.tick
	var boss: Dictionary = find(view)
	if boss.is_empty():
		_previous.clear()
		return out
	if boss["state"] == &"alert":  # it breaks out of the floor: shards, dust, a stomp and a shake at each burst
		var t: int = int(boss["state_ticks"])
		for i: int in APPEAR_CUES.size():
			var cue: Array = APPEAR_CUES[i]
			if t < int(cue[0]) or _appear_seen.has(i):
				continue
			_appear_seen[i] = true
			var at: Vector2 = Vector2(boss["position"]) + Vector2(float(cue[1]), 2.0)
			effects.append({"kind": cue[2], "tick": view.tick - (t - int(cue[0])), "at": at})
			if bool(cue[3]):
				out.append({"attack": &"appear", "at": at, "heavy": true, "cue": "golem_stomp"})
	elif boss["state"] == &"idle":
		_appear_seen.clear()
	var candidates: Array[Snapshots.TelegraphSnapshot] = []
	candidates.append_array(_previous)
	candidates.append_array(view.telegraphs)
	for t: Snapshots.TelegraphSnapshot in candidates:
		if t.owner_id != int(boss["id"]) or _seen_hits.has(t.id) or view.tick < t.hit_tick or view.tick > t.end_tick + 1:
			continue
		_seen_hits[t.id] = true
		out.append({"attack": t.attack, "at": t.center if t.shape in [&"circle", &"ring"] else Vector2(boss["position"]), "heavy": t.attack in HEAVY,
			"cue": String(STRIKE_CUES.get(t.attack, ""))})
		if t.attack == &"root_snare":  # its lane bursts into thorns (the second lane too)
			effects.append({"kind": &"thorns", "tick": t.hit_tick, "at": t.center, "direction": t.direction, "size": t.size})
		elif t.attack == &"boulder_toss" and t.shape == &"circle":  # the stone lands
			effects.append({"kind": &"land", "tick": t.hit_tick, "at": t.center})
		elif t.attack == &"song_flare" and t.shape == &"ring":  # a ring of the song bursts
			effects.append({"kind": &"song_ring", "tick": t.hit_tick, "at": t.center, "radius": (t.inner_size + t.size) * 0.5})
		elif t.attack == &"song_flare" and t.kind == &"gold":  # the gold blow: the song blows out of its chest (parried or not)
			effects.append({"kind": &"song_burst", "tick": t.hit_tick, "at": t.center})
		elif t.attack == &"gold_slam" or t.attack == &"gold_combo":  # the floor cracks under each real circle (parried or not)
			effects.append({"kind": &"slam", "tick": t.hit_tick, "at": t.center})
		elif t.attack == &"red_stomp":  # stone shards round the middle of its ring
			effects.append({"kind": &"stomp", "tick": t.hit_tick, "at": t.center, "radius": (t.inner_size + t.size) * 0.5})
		elif t.attack == &"red_shards":  # stone shards racing out along each lane
			effects.append({"kind": &"shard_lane", "tick": t.hit_tick, "at": t.center, "direction": t.direction, "size": t.size})
		elif t.attack == &"red_charge":  # dust where its feet pass along the lane
			effects.append({"kind": &"charge_dust", "tick": t.hit_tick, "at": t.center, "direction": t.direction, "size": t.size,
				"run": t.end_tick - t.hit_tick + 1})
		elif t.attack == &"red_sweep":  # dust kicked up across the cone as the arm swings through it (parried or not)
			effects.append({"kind": &"sweep_dust", "tick": t.hit_tick, "at": t.center, "direction": t.direction, "size": t.size, "half": t.half_angle})
		elif t.attack == &"heartroot_grab":  # the root-arm lashes (parried or not) and slides back
			effects.append({"kind": &"arm", "tick": t.hit_tick, "at": t.center + t.direction * ARM_ROOT, "direction": t.direction})
		elif t.attack == &"boulder_toss" and t.shape == &"ring":  # its ring of shock strikes: shards over the real band
			effects.append({"kind": &"shards", "tick": t.hit_tick, "at": t.center, "radius": (t.inner_size + t.size) * 0.5})
	_previous.clear()
	for t: Snapshots.TelegraphSnapshot in view.telegraphs:
		if t.owner_id == int(boss["id"]):
			_previous.append(t)
	return out
