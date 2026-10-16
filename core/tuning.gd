extends RefCounted
## Every gameplay number in one place. Times are ticks (60 per second), distances are pixels.
## The human tunes feel here after playtesting; nothing else in core/ hard-codes a balance number.

const TICK_DT: float = 1.0 / 60.0

# Arena (one room, 20x11 tiles)
const ARENA_SIZE: Vector2 = Vector2(320.0, 176.0)
const ARENA_MARGIN: float = 8.0
const PLAYER_START: Vector2 = Vector2(64.0, 88.0)
const BOSS_START: Vector2 = Vector2(240.0, 88.0)

# Player
const PLAYER_MAX_HP: int = 100
const PLAYER_SPEED: float = 1.0  # px per tick (60 px/s); was 1.5, playtest said the character was too fast
const PLAYER_RADIUS: float = 6.0
const PLAYER_HURT_INVULN_TICKS: int = 45

# Dash: available with every weapon
const DASH_TICKS: int = 6  # was 10: playtest said the dash was too long (distance 30 px, was 56)
const DASH_SPEED: float = 5.0
const DASH_INVULN_TICKS: int = 8  # runs on its own counter from the dash start, so it can outlast the short dash
const DASH_COOLDOWN_TICKS: int = 40

# Gold parry. A parry press opens a window of PARRY_ACTIVE_TICKS. A gold hit that lands within
# PARRY_PERFECT_TICKS of the press is a perfect parry (instant posture break); later in the window it is
# an early deflection (partial posture). A press that finds nothing leaves a recovery.
const PARRY_ACTIVE_TICKS: int = 14
const PARRY_PERFECT_TICKS: int = 6
const PARRY_WHIFF_RECOVERY_TICKS: int = 20
const PARRY_EARLY_POSTURE: float = 35.0
const RIPOSTE_STEP: float = 10.0

# Sword: a three-swing combo (attack1 -> attack2 -> attack3). Index 0 of each list is swing 1.
# The art has six frames per swing: 1-2 windup, 3-4 active, 5-6 recovery (presentation maps the states).
# All values are first guesses; nobody has played the combo yet.
const COMBO_MAX: int = 3
const SWING_WINDUP_TICKS: Array[int] = [7, 6, 9]  # swing 1 was 5, then 7 so the draw animation reads
const SWING_ACTIVE_TICKS: Array[int] = [3, 3, 4]
const SWING_RECOVERY_TICKS: Array[int] = [9, 9, 16]  # the finisher leaves a longer opening
const SWING_DAMAGE_MULT: Array[float] = [1.0, 1.2, 2.0]  # multiplies ATTACK_DAMAGE
const SWING_RANGE_MULT: Array[float] = [1.0, 1.0, 1.25]  # multiplies ATTACK_RANGE
# A press during the last COMBO_BUFFER_TICKS of a swing's recovery is remembered and starts the next swing
# the moment recovery ends. Earlier presses are ignored (no mashing ahead). If recovery ends with nothing
# buffered, a press within COMBO_GRACE_TICKS still continues the chain; after that the combo resets to 1.
# The chain also resets on damage, dash, parry and death, and after the third swing.
const COMBO_BUFFER_TICKS: int = 6
const COMBO_GRACE_TICKS: int = 8
# Swing 1 values, kept as named constants for readability and older tests.
const ATTACK_WINDUP_TICKS: int = SWING_WINDUP_TICKS[0]
const ATTACK_ACTIVE_TICKS: int = SWING_ACTIVE_TICKS[0]
const ATTACK_RECOVERY_TICKS: int = SWING_RECOVERY_TICKS[0]
const ATTACK_RANGE: float = 26.0
const ATTACK_ARC_DOT: float = 0.2
const ATTACK_DAMAGE: int = 10
const ATTACK_MOVE_FACTOR: float = 0.3
const PARRY_RECOVERY_MOVE_FACTOR: float = 0.5
const NORMAL_HIT_POSTURE: float = 4.0
const ARMOR_DAMAGE_FACTOR: float = 0.25
const COUNTER_DAMAGE_MULT: float = 4.0

# Skills (Aspect-style sword skills, bound to Z X C for testing: skill_pressed 1, 2, 3). First guesses.
# Every skill follows windup -> active -> recovery; the hit lands on the first active tick. None grants
# invulnerability. Health damage uses the same rules as a normal hit: reduced by ARMOR_DAMAGE_FACTOR
# against the armored boss, multiplied by COUNTER_DAMAGE_MULT during a posture break. Skills do not use the
# Edge counter bonus (they pay Edge instead). The Edge cost is spent when the skill starts.
const SKILL_COUNT: int = 3

# 1. Breaking Edge: after a successful parry, spend Edge to step forward with a heavy slash.
const BREAKING_EDGE_WINDOW_TICKS: int = 50  # how long after a successful parry the skill can be used
const BREAKING_EDGE_EDGE_COST: float = 25.0  # one parry (EDGE_PER_PARRY) pays for one retaliation
const BREAKING_EDGE_WINDUP_TICKS: int = 6  # the forward step happens during the windup
const BREAKING_EDGE_STEP: float = 22.0  # pixels moved during the windup
const BREAKING_EDGE_ACTIVE_TICKS: int = 3
const BREAKING_EDGE_RECOVERY_TICKS: int = 22
const BREAKING_EDGE_RANGE: float = 30.0
const BREAKING_EDGE_ARC_DOT: float = 0.1
const BREAKING_EDGE_DAMAGE: float = 20.0
const BREAKING_EDGE_POSTURE: float = 55.0  # high: two retaliations break the boss (posture max 100)
const BREAKING_EDGE_EDGE_GAIN: float = 0.0

# 2. Gale Cut: dash toward the aim and deliver a quick cut. No Edge cost, a cooldown instead.
const GALE_CUT_COOLDOWN_TICKS: int = 150
const GALE_CUT_EDGE_COST: float = 0.0
const GALE_CUT_WINDUP_TICKS: int = 6  # the dash: GALE_CUT_SPEED px per tick along the aim
const GALE_CUT_SPEED: float = 5.0
const GALE_CUT_ACTIVE_TICKS: int = 2
const GALE_CUT_RECOVERY_TICKS: int = 10
const GALE_CUT_RANGE: float = 30.0
const GALE_CUT_ARC_DOT: float = 0.2
const GALE_CUT_DAMAGE: float = 15.0
const GALE_CUT_POSTURE: float = 8.0
const GALE_CUT_EDGE_GAIN: float = 25.0  # same as a normal hit (EDGE_PER_HIT)

# 3. Moon Cleave: hold briefly, then a wide powerful slash. Biggest Edge cost and recovery.
const MOON_CLEAVE_COOLDOWN_TICKS: int = 90
const MOON_CLEAVE_EDGE_COST: float = 80.0
const MOON_CLEAVE_WINDUP_TICKS: int = 30  # the committed hold
const MOON_CLEAVE_WINDUP_MOVE_FACTOR: float = 0.2
const MOON_CLEAVE_ACTIVE_TICKS: int = 4
const MOON_CLEAVE_RECOVERY_TICKS: int = 44
const MOON_CLEAVE_RANGE: float = 38.0
const MOON_CLEAVE_ARC_DOT: float = -0.3  # a wide arc: about 107 degrees to each side of the facing
const MOON_CLEAVE_DAMAGE: float = 40.0
const MOON_CLEAVE_POSTURE: float = 20.0
const MOON_CLEAVE_EDGE_GAIN: float = 0.0

# Edge (sword mechanic): close hits and parries build it, a counter spends all of it for extra damage
const EDGE_MAX: float = 100.0
const EDGE_PER_HIT: float = 25.0
const EDGE_PER_PARRY: float = 25.0
const EDGE_COUNTER_BONUS: float = 0.5

# Mossbound Colossus
const BOSS_MAX_HP: int = 380
const BOSS_POSTURE_MAX: float = 100.0
const BOSS_RADIUS: float = 20.0
const BOSS_SPEED: float = 0.5
const BOSS_FIRST_ATTACK_DELAY_TICKS: int = 60
const BOSS_COOLDOWN_PHASE1_TICKS: int = 40
const BOSS_COOLDOWN_PHASE2_TICKS: int = 24
const BOSS_PHASE2_HP_FRACTION: float = 0.5
const BOSS_PHASE2_WINDUP_FACTOR: float = 0.85
const BOSS_POSTURE_DECAY: float = 0.03
const BOSS_BREAK_TICKS: int = 60  # one second to punish a posture break
const BOSS_BREAK_RECOVER_TICKS: int = 20

# Boss attacks: gold slam and sweep (parry them), red shards (dodge them)
const SLAM_WINDUP_TICKS: int = 60
const SLAM_RADIUS: float = 34.0
const SLAM_DAMAGE: int = 30
const SLAM_RECOVER_TICKS: int = 26

const SWEEP_WINDUP_TICKS: int = 54  # was 42; at the slower walk speed the player needs ~47 ticks to leave the cone from close range
const SWEEP_RADIUS: float = 80.0
const SWEEP_HALF_ANGLE_DEG: float = 50.0
const SWEEP_ACTIVE_TICKS: int = 4
const SWEEP_DAMAGE: int = 20
const SWEEP_RECOVER_TICKS: int = 24

const SHARDS_WINDUP_TICKS: int = 48
const SHARDS_LENGTH: float = 170.0
const SHARDS_WIDTH: float = 12.0
const SHARDS_SPREAD_DEG: float = 20.0
const SHARDS_ACTIVE_TICKS: int = 6
const SHARDS_DAMAGE: int = 15
const SHARDS_RECOVER_TICKS: int = 22

# Added after playtest ("add more attack patterns"). Stomp and combo are in both phases' pool; the
# combo and the charge only appear in phase 2.
# Red stomp: a ring around the boss. The inner circle (right next to the boss) is safe, the band is not,
# and the outside is safe. Get close or get far; a dash through the band also works.
const STOMP_WINDUP_TICKS: int = 60
const STOMP_INNER_RADIUS: float = 44.0
const STOMP_OUTER_RADIUS: float = 100.0
const STOMP_ACTIVE_TICKS: int = 3
const STOMP_DAMAGE: int = 25
const STOMP_RECOVER_TICKS: int = 28

# Gold combo: two gold slams (second one lands COMBO_GAP ticks after the first, a bit farther out).
const COMBO_WINDUP_TICKS: int = 54
const COMBO_GAP_TICKS: int = 26
const COMBO_RADIUS: float = 30.0
const COMBO_OFFSET: float = 46.0
const COMBO_DAMAGE: int = 25
const COMBO_RECOVER_TICKS: int = 30

# Red charge: the boss rushes along a locked line. The line is both the warning and the danger area, and
# the boss body travels along it while it is dangerous.
const CHARGE_WINDUP_TICKS: int = 50
const CHARGE_LENGTH: float = 170.0
const CHARGE_WIDTH: float = 28.0
const CHARGE_ACTIVE_TICKS: int = 8
const CHARGE_DAMAGE: int = 28
const CHARGE_RECOVER_TICKS: int = 34
