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

# Sword
const ATTACK_WINDUP_TICKS: int = 7  # was 5: gives the draw-from-sheath animation time to read
const ATTACK_ACTIVE_TICKS: int = 3
const ATTACK_RECOVERY_TICKS: int = 9
const ATTACK_RANGE: float = 26.0
const ATTACK_ARC_DOT: float = 0.2
const ATTACK_DAMAGE: int = 10
const ATTACK_MOVE_FACTOR: float = 0.3
const PARRY_RECOVERY_MOVE_FACTOR: float = 0.5
const NORMAL_HIT_POSTURE: float = 4.0
const ARMOR_DAMAGE_FACTOR: float = 0.25
const COUNTER_DAMAGE_MULT: float = 4.0

# Edge (sword mechanic): close hits and parries build it, a counter spends all of it for extra damage
const EDGE_MAX: float = 100.0
const EDGE_PER_HIT: float = 25.0
const EDGE_PER_PARRY: float = 25.0
const EDGE_COUNTER_BONUS: float = 0.5

# Mossbound Colossus
const BOSS_MAX_HP: int = 300
const BOSS_POSTURE_MAX: float = 100.0
const BOSS_RADIUS: float = 20.0
const BOSS_SPEED: float = 0.35
const BOSS_FIRST_ATTACK_DELAY_TICKS: int = 90
const BOSS_COOLDOWN_PHASE1_TICKS: int = 70
const BOSS_COOLDOWN_PHASE2_TICKS: int = 42
const BOSS_PHASE2_HP_FRACTION: float = 0.5
const BOSS_PHASE2_WINDUP_FACTOR: float = 0.85
const BOSS_POSTURE_DECAY: float = 0.03
const BOSS_BREAK_TICKS: int = 120  # the counter opening: two seconds
const BOSS_BREAK_RECOVER_TICKS: int = 20

# Boss attacks: gold slam (parry it), red sweep and red shards (dodge them)
const SLAM_WINDUP_TICKS: int = 60
const SLAM_RADIUS: float = 34.0
const SLAM_DAMAGE: int = 30
const SLAM_RECOVER_TICKS: int = 40

const SWEEP_WINDUP_TICKS: int = 54  # was 42; at the slower walk speed the player needs ~47 ticks to leave the cone from close range
const SWEEP_RADIUS: float = 80.0
const SWEEP_HALF_ANGLE_DEG: float = 50.0
const SWEEP_ACTIVE_TICKS: int = 4
const SWEEP_DAMAGE: int = 20
const SWEEP_RECOVER_TICKS: int = 36

const SHARDS_WINDUP_TICKS: int = 48
const SHARDS_LENGTH: float = 170.0
const SHARDS_WIDTH: float = 12.0
const SHARDS_SPREAD_DEG: float = 20.0
const SHARDS_ACTIVE_TICKS: int = 6
const SHARDS_DAMAGE: int = 15
const SHARDS_RECOVER_TICKS: int = 30

# Added after playtest ("add more attack patterns"). Stomp and combo are in both phases' pool; the
# combo and the charge only appear in phase 2.
# Red stomp: a ring around the boss. The inner circle (right next to the boss) is safe, the band is not,
# and the outside is safe. Get close or get far; a dash through the band also works.
const STOMP_WINDUP_TICKS: int = 60
const STOMP_INNER_RADIUS: float = 44.0
const STOMP_OUTER_RADIUS: float = 100.0
const STOMP_ACTIVE_TICKS: int = 3
const STOMP_DAMAGE: int = 25
const STOMP_RECOVER_TICKS: int = 40

# Gold combo: two gold slams (second one lands COMBO_GAP ticks after the first, a bit farther out).
const COMBO_WINDUP_TICKS: int = 54
const COMBO_GAP_TICKS: int = 26
const COMBO_RADIUS: float = 30.0
const COMBO_OFFSET: float = 46.0
const COMBO_DAMAGE: int = 25
const COMBO_RECOVER_TICKS: int = 44

# Red charge: the boss rushes along a locked line. The line is both the warning and the danger area, and
# the boss body travels along it while it is dangerous.
const CHARGE_WINDUP_TICKS: int = 50
const CHARGE_LENGTH: float = 170.0
const CHARGE_WIDTH: float = 28.0
const CHARGE_ACTIVE_TICKS: int = 8
const CHARGE_DAMAGE: int = 28
const CHARGE_RECOVER_TICKS: int = 50
