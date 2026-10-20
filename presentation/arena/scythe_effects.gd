extends RefCounted
## Cosmetic timing and naming for the Chain Scythe and its Reaper's Coil (swing arcs, chain, flying head, hook clink,
## drag streaks/dust/scuffs, stagger burst, dizzy stars, spin ring halves, miss poof). Pure functions over ticks and
## positions taken from the snapshot and core events; no rules, no damage, no hit decisions.
## Art and anchors: art/reference/chain_scythe/README.md ("In-game sprites") and art/build/chain_scythe_sprites_manifest.json.
const Snapshots := preload("res://core/snapshots.gd")
const PlayerState := preload("res://core/player.gd")
const Tuning := preload("res://core/tuning.gd")
const Weapons := preload("res://core/weapons.gd")

## Live event effects at most (the oldest is dropped first), like a cap on any burst of events.
const MAX_LIVE: int = 40
## Ticks per frame of the event sequences (frame n = entry n-1).
const HOOK_TICKS: Array[int] = [2, 2, 3, 3, 3]
const LAND_TICKS: Array[int] = [2, 3, 3, 4]
const STAGGER_TICKS: Array[int] = [2, 2, 3, 3, 3, 4]
const DUST_TICKS: Array[int] = [2, 3, 3, 4]
## Scuff decals stay on the floor a while: fresh (1) to almost gone (4).
const SCUFF_TICKS: Array[int] = [12, 14, 14, 16]
## Spin hit spark (the hook's spark/mote frames 4-5) and a short flash.
const SPARK_TICKS: Array[int] = [3, 4]
## Arc phases over the swing: lead + peak over the active ticks, then follow and fragments early in the recovery.
const ARC_FOLLOW_TICKS: Array[int] = [3, 4]
## Spin ring: phase 1 opens, 2 loops while spinning, 3 and 4 close at the end of the spin.
const RING_OPEN_TICKS: int = 2
const RING_CLOSE_TICKS: int = 3
## Dizzy stars loop at about 90 ms per frame.
const STARS_TICKS: int = 5
## Where the chain leaves the hand when the frame has no chain_origin (relative to the feet, facing right).
const DEFAULT_HAND: Vector2 = Vector2(10, -14)
## Chest of the golem above its feet (the stagger burst, hook sparks).
const BOSS_BODY: Vector2 = Vector2(0, -20)
const CHAIN_SEGMENT: float = 32.0
## Drag decals: a dust puff every DUST_EVERY ticks, a scuff every SCUFF_EVERY ticks while the boss is dragged.
const DUST_EVERY: int = 2
const SCUFF_EVERY: int = 3


static func all_names() -> Array[String]:
	var names: Array[String] = []
	for group: Array in [["fx_chain_dust", 4], ["fx_chain_hook", 5], ["fx_chain_land", 4], ["fx_chain_link", 4], ["fx_chain_pull", 4], ["fx_chain_scuff", 4], ["fx_chain_stagger", 6], ["fx_chain_stars", 4], ["fx_chain_whip", 6], ["fx_scythe_flying", 8], ["fx_scythe_spin_back", 4], ["fx_scythe_spin_front", 4], ["fx_scythe_arc_1", 4], ["fx_scythe_arc_2", 4], ["fx_scythe_arc_3", 4]]:
		for n: int in range(1, int(group[1]) + 1):
			names.append("%s_%d" % [group[0], n])
	return names


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


## The swing arc for a scythe swing in progress, "" when none shows: lead and peak spread over the active phase
## (the painted strike frames 3-4), follow and fragments in the first ticks of the recovery (frames 5-6).
static func arc_key(hero: Snapshots.EntitySnapshot) -> String:
	if hero.weapon_id != Tuning.WEAPON_CHAIN_SCYTHE or hero.combo_index < 1:
		return ""
	var swing: int = clampi(hero.combo_index, 1, Weapons.combo_max(hero.weapon_id))
	var phases: Array[int] = Weapons.swing_phases(hero.weapon_id, swing)
	if hero.state == PlayerState.STATE_ATTACK_ACTIVE:
		var active: int = maxi(1, PlayerState.scaled_ticks(phases[1], hero.attack_speed_mult))
		return "fx_scythe_arc_%d_%d" % [swing, mini(1, maxi(0, hero.state_ticks) * 2 / active) + 1]
	if hero.state == PlayerState.STATE_ATTACK_RECOVERY:
		var frame: int = sequence_frame(ARC_FOLLOW_TICKS, hero.state_ticks)
		if frame > 0:
			return "fx_scythe_arc_%d_%d" % [swing, frame + 2]
	return ""


## Spin ring phase (1-4) at a spin phase tick, 0 outside the spin.
static func ring_phase(phase_tick: int) -> int:
	if phase_tick < 0 or phase_tick >= Tuning.REAPER_COIL_SPIN_TICKS:
		return 0
	if phase_tick < RING_OPEN_TICKS:
		return 1
	var left: int = Tuning.REAPER_COIL_SPIN_TICKS - phase_tick
	if left <= RING_CLOSE_TICKS:
		return 4
	if left <= RING_CLOSE_TICKS * 2:
		return 3
	return 2


## Hero frame of Reaper's Coil for a phase and its phase tick (the coil frames have no direction in their names).
static func coil_frame(phase: StringName, phase_tick: int) -> String:
	var t: int = maxi(0, phase_tick)
	match phase:
		PlayerState.COIL_HOOK:
			# activation tick: the approved wind-up, then the throw while the chain flies
			if t < 2:
				return "totoy_scythe_coil_windup_%d" % (t + 1)
			return "totoy_scythe_coil_whip_%d" % mini(3, t - 1)
		PlayerState.COIL_DRAG, PlayerState.COIL_PULL:
			return "totoy_scythe_coil_pull_%d" % ([1, 2, 3, 2][(t / 3) % 4])
		PlayerState.COIL_SPIN:
			return "totoy_scythe_coil_spin_%d" % (mini(7, t * 8 / maxi(1, Tuning.REAPER_COIL_SPIN_TICKS)) + 1)
		PlayerState.COIL_RECOVERY:
			return "totoy_scythe_coil_recover_%d" % (1 if t < 4 else 2)
	return "totoy_scythe_coil_windup_1"


static func coil_names() -> Array[String]:
	var names: Array[String] = []
	for group: Array in [["windup", 2], ["whip", 3], ["pull", 3], ["spin", 8], ["recover", 2]]:
		for n: int in range(1, int(group[1]) + 1):
			names.append("totoy_scythe_coil_%s_%d" % [group[0], n])
	return names


## True while the chain is out (hook flying, boss held, or the hero pulled to the anchor).
static func chain_visible(hero: Snapshots.EntitySnapshot) -> bool:
	return hero.state == PlayerState.STATE_REAPER_COIL and hero.reaper_coil_phase in [PlayerState.COIL_HOOK, PlayerState.COIL_DRAG, PlayerState.COIL_PULL]


## The flying scythe frame (1-8) pointing along `direction`: frame 1 points up, each next one 45 degrees clockwise.
static func flying_frame(direction: Vector2) -> int:
	if direction.length() < 0.001:
		return 1
	return posmod(roundi((rad_to_deg(direction.angle()) + 90.0) / 45.0), 8) + 1


## Chain links laid end to end from the hand to the tip: offset along the line and the length to draw.
static func chain_segments(length: float) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var along: float = 0.0
	while along < length - 0.5:
		segments.append({"offset": along, "length": minf(CHAIN_SEGMENT, length - along)})
		along += CHAIN_SEGMENT
	return segments


## Link frame of segment `index`: the taut links 1/2 alternate (and shimmer by tick); the wavy link 3 at the tip of
## a flying chain; the spectral link 4 flashes on the hook tick.
static func link_frame(index: int, count: int, tick: int, phase: StringName, hooked_now: bool) -> int:
	if hooked_now:
		return 4
	if phase == PlayerState.COIL_HOOK and index == count - 1:
		return 3
	return posmod(index + tick, 2) + 1


## The dizzy stars loop frame for a tick.
static func stars_frame(tick: int) -> int:
	return posmod(tick / STARS_TICKS, 4) + 1


## The pull streak frame while dragged.
static func pull_frame(tick: int) -> int:
	return posmod(tick / 2, 4) + 1


## Adds an effect and drops the oldest past MAX_LIVE.
static func add(effects: Array[Dictionary], effect: Dictionary) -> void:
	effects.append(effect)
	while effects.size() > MAX_LIVE:
		effects.pop_front()
