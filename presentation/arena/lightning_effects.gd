extends RefCounted
## Cosmetic timing and naming for the Dual Dagger's lightning (blink, cut, chain, sparks, sky strike, scorch).
## Pure functions over ticks and positions taken from core events; no rules, no damage, no hit decisions.
## Art and anchors: art/reference/dual_dagger/README.md ("In-game import").

## Cut directions by index (0 east, clockwise, screen y down), the same order as Weapons.blink_direction.
const CUT_DIRECTIONS: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
## Ticks each frame shows (frame n = entry n-1). About 33/50/50/66 ms for the cut, 40 ms per spark.
const CUT_TICKS: Array[int] = [2, 3, 3, 4]
const SPARK_TICKS: Array[int] = [2, 2, 2, 3, 3, 3]
const BLINK_TICKS: Array[int] = [2, 2, 2, 3, 3]
## Departure plays from the star (frame 2): the hero is already gone, only the burst and the fading ring remain.
const DEPART_TICKS: Array[int] = [0, 2, 2, 3, 3]
## 1 sky flash + leader, 2 leader halfway, 3-4 full bolt, 5 burst, 6 wide ring, 7 fragments, 8 embers.
const STRIKE_TICKS: Array[int] = [1, 1, 3, 3, 3, 3, 3, 4]
const GROUND_TICKS: Array[int] = [20, 25, 25, 30]
## Blink afterimages: frames 1-3 (dash pose fading), 3 ticks each.
const AFTERIMAGE_TICKS: Array[int] = [3, 3, 3]
const CHAIN_TICKS: int = 8
const CHAIN_SEGMENT: float = 32.0
## White hit flash on the boss per Lightning Barrage slash (a normal hit flashes 6 ticks; barrage slashes come every
## LIGHTNING_BARRAGE_INTERVAL_TICKS, so a shorter flash lets the boss show between them).
const BARRAGE_HIT_FLASH_TICKS: int = 3
## Chest height above the feet, where chains and blink bursts connect.
const CHEST: Vector2 = Vector2(0, -14)
## How far above its feet the bolt cuts through the boss.
const BOSS_BODY: Vector2 = Vector2(0, -20)


static func all_names() -> Array[String]:
	var names: Array[String] = []
	for direction: String in CUT_DIRECTIONS:
		for n: int in range(1, CUT_TICKS.size() + 1):
			names.append("fx_lightning_cut_%s_%d" % [direction, n])
	for group: Array in [["fx_lightning_spark", SPARK_TICKS.size()], ["fx_lightning_blink", BLINK_TICKS.size()], ["fx_lightning_strike", STRIKE_TICKS.size()], ["fx_lightning_ground", GROUND_TICKS.size()], ["fx_lightning_afterimage", 6], ["fx_lightning_chain", 4]]:
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


## Nearest of the 8 directions to a vector (0 east, clockwise with y down).
static func direction_index(vector: Vector2) -> int:
	if vector.length() < 0.001:
		return 0
	return posmod(roundi(vector.angle() / (PI / 4.0)), 8)


## The cut travels from the side the hero blinked to, through the boss: the opposite of the blink side, or the
## direction from the arrival point to the boss when both are known.
static func cut_direction(blink_index: int, arrival: Vector2 = Vector2.ZERO, target: Vector2 = Vector2.ZERO) -> int:
	if arrival.distance_to(target) > 1.0:
		return direction_index(target - arrival)
	return posmod(blink_index + 4, 8)


static func cut_key(direction: int, frame: int) -> String:
	return "fx_lightning_cut_%s_%d" % [CUT_DIRECTIONS[posmod(direction, 8)], frame]


## Chain bolt: whole 32 px segments laid end to end from `from` to `to` (the last one is cut to length).
## Each entry: offset along the line and the length to draw.
static func chain_segments(from: Vector2, to: Vector2) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var length: float = from.distance_to(to)
	var along: float = 0.0
	while along < length - 0.5:
		segments.append({"offset": along, "length": minf(CHAIN_SEGMENT, length - along)})
		along += CHAIN_SEGMENT
	return segments


## Which chain frame shows at `age` (it flickers off now and then as it dies), 0 when hidden.
static func chain_frame(age: int, segment: int) -> int:
	if age < 0 or age >= CHAIN_TICKS:
		return 0
	if age >= 4 and (age + segment) % 3 == 0:
		return 0
	return posmod(age + segment, 4) + 1


## The sky strike is 160 px tall at scale 1 (152 px above its strike point). Draw it at 2x when the strike point
## is low on the screen so the bolt always comes from above the top edge.
static func strike_scale(screen_y: float) -> int:
	return 1 if screen_y + 4.0 < 152.0 else 2


## Full-screen flash strength for the sky strike `age` ticks in.
static func strike_flash(age: int) -> float:
	match age:
		0: return 0.6
		1: return 0.35
		2: return 0.2
		3: return 0.1
	return 0.0
