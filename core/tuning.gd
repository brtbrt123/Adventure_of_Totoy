extends RefCounted
## Every gameplay number in one place. Times are ticks (60 per second), distances are pixels.
## The human tunes feel here after playtesting; nothing else in core/ hard-codes a balance number.

const TICK_DT: float = 1.0 / 60.0

# Arena: the ruins, 50x30 tiles (800x480 px). The screen stays 320x180; presentation scrolls a camera that follows the
# player. The walls stand ARENA_MARGIN px inside the edge (the ruined wall and the tree line are drawn there).
const ARENA_SIZE: Vector2 = Vector2(800.0, 480.0)
const ARENA_MARGIN: float = 28.0
const PLAYER_START: Vector2 = Vector2(312.0, 250.0)
const BOSS_START: Vector2 = Vector2(488.0, 250.0)
# Collision with the solid props (core/arena_layout.gd) is resolved in steps of at most this many pixels, so a fast
# dash or charge cannot jump over a pillar.
const OBSTACLE_SWEEP_STEP: float = 3.0

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
# Every skill follows windup -> active -> recovery and none grants invulnerability. The direction is chosen
# when the skill is pressed: the move input if the player is moving, else the aim, else the facing.
# Health damage uses the same rules as a normal hit: reduced by ARMOR_DAMAGE_FACTOR against the armored boss,
# multiplied by COUNTER_DAMAGE_MULT during a posture break. Skills do not use the Edge counter bonus (they pay
# Edge instead). The Edge cost is spent when the skill is pressed and is not refunded if it is interrupted.
const SKILL_COUNT: int = 3

# 1. Breaking Edge: after a successful parry, spend Edge for a fast forward retaliation (one melee hit).
const BREAKING_EDGE_WINDOW_TICKS: int = 50  # how long after a successful parry the skill can be used
const BREAKING_EDGE_EDGE_COST: float = 25.0  # one parry (EDGE_PER_PARRY) pays for one retaliation
const BREAKING_EDGE_WINDUP_TICKS: int = 3  # the forward step happens during the windup
const BREAKING_EDGE_STEP: float = 26.0  # pixels moved during the windup
const BREAKING_EDGE_ACTIVE_TICKS: int = 2
const BREAKING_EDGE_RECOVERY_TICKS: int = 16
const BREAKING_EDGE_RANGE: float = 30.0
const BREAKING_EDGE_ARC_DOT: float = 0.1
const BREAKING_EDGE_DAMAGE: float = 20.0
const BREAKING_EDGE_POSTURE: float = 55.0  # strong: two retaliations break the boss (posture max 100)
const BREAKING_EDGE_EDGE_GAIN: float = 0.0
const BREAKING_EDGE_COOLDOWN_TICKS: int = 0

# 2. Gale Cut: a short windup, then an aimed dash. Everything the dash corridor touches is hit once per cast.
# The corridor is the segment the player really travelled each tick (arena walls and the solid boss can
# shorten it), widened by the lane width. Distance = GALE_CUT_SPEED * GALE_CUT_ACTIVE_TICKS.
const GALE_CUT_COOLDOWN_TICKS: int = 300
const GALE_CUT_EDGE_COST: float = 35.0
const GALE_CUT_WINDUP_TICKS: int = 4
const GALE_CUT_SPEED: float = 8.0  # px per tick while dashing
const GALE_CUT_ACTIVE_TICKS: int = 15  # 15 * 8 = 120 px
const GALE_CUT_RECOVERY_TICKS: int = 12
const GALE_CUT_DISTANCE: float = 120.0  # the planned corridor length (reported in the snapshot)
const GALE_CUT_LANE_WIDTH: float = 18.0
const GALE_CUT_DAMAGE: float = 15.0
const GALE_CUT_POSTURE: float = 10.0
const GALE_CUT_EDGE_GAIN: float = 0.0

# 3. Moon Cleave: hold, then release a sword-aura projectile that travels on its own and pierces (each target
# is hit once). An interrupted hold spawns nothing; after the release the projectile no longer depends on the
# player.
const MOON_CLEAVE_COOLDOWN_TICKS: int = 90
const MOON_CLEAVE_EDGE_COST: float = 80.0
const MOON_CLEAVE_WINDUP_TICKS: int = 30  # the committed hold
const MOON_CLEAVE_WINDUP_MOVE_FACTOR: float = 0.2
const MOON_CLEAVE_ACTIVE_TICKS: int = 4  # the release pose; the projectile spawns on its first tick
const MOON_CLEAVE_RECOVERY_TICKS: int = 44
const MOON_CLEAVE_TRAVEL: float = 140.0  # distance the projectile travels from its spawn point
const MOON_CLEAVE_SPEED: float = 4.0  # px per tick
const MOON_CLEAVE_WIDTH: float = 20.0
const MOON_CLEAVE_SPAWN_OFFSET: float = 10.0  # in front of the player
const MOON_CLEAVE_DAMAGE: float = 40.0
const MOON_CLEAVE_POSTURE: float = 20.0
const MOON_CLEAVE_EDGE_GAIN: float = 0.0

# Black Katana active (right click). Values set by the human on 2026-10-19 (still to be judged by playtesting).
# While the buff is active, normal swings are faster (each phase's ticks are divided by the multiplier, see
# Player.scaled_ticks) and the player's damage is higher (normal swings and skills). Skill timings do not change.
# The multipliers are locked when a swing starts or a skill is released, so a swing never changes speed or
# damage halfway. Activating is free of animation lock (no state change) and works in any state but dead.
const WEAPON_BLACK_KATANA: StringName = &"black_katana"
const BLACK_KATANA_BUFF_DURATION_TICKS: int = 600  # 10 seconds
const BLACK_KATANA_BUFF_COOLDOWN_TICKS: int = 1800  # 30 seconds, counted from the activation
const BLACK_KATANA_BUFF_EDGE_COST: float = 50.0  # half the Edge meter, spent on activation
const BLACK_KATANA_ATTACK_SPEED_MULT: float = 1.5
const BLACK_KATANA_DAMAGE_MULT: float = 1.4
const BLACK_KATANA_MOVE_SPEED_MULT: float = 1.0  # the katana buff does not change walking speed

# Weapon swap (Q in presentation: InputFrame.weapon_swap_pressed). Cycles Black Katana -> Dual Dagger -> Chain Scythe
# -> Black Katana (the order is Weapons.IDS). A free action, only
# from idle or walk, never while a weapon buff/form runs. After a swap the next swap waits WEAPON_SWAP_LOCKOUT_TICKS.
# Every weapon keeps its own active cooldown, so swapping never resets one. The player always starts with the katana.
const WEAPON_SWAP_LOCKOUT_TICKS: int = 20

# Dual Dagger (second weapon), first guesses set on 2026-10-19, nobody has played it yet. A fast, short-reach 4-hit
# combo; hands alternate in the art only. Same buffer/grace/reset rules as the katana combo. Per swing (index 0 = hit 1).
# Swing totals 12/12/12/21 ticks against the katana's 19/18/29. Damage multiplies ATTACK_DAMAGE like the katana's table:
# hits 1-3 are 60% of a katana hit 1, hit 4 is 90%. Reach is 0.75 of the katana's.
const WEAPON_DUAL_DAGGER: StringName = &"dual_dagger"
const DAGGER_COMBO_MAX: int = 4
const DAGGER_SWING_WINDUP_TICKS: Array[int] = [4, 4, 4, 6]
const DAGGER_SWING_ACTIVE_TICKS: Array[int] = [2, 2, 2, 3]
const DAGGER_SWING_RECOVERY_TICKS: Array[int] = [6, 6, 6, 12]
const DAGGER_SWING_DAMAGE_MULT: Array[float] = [0.6, 0.6, 0.6, 0.9]
const DAGGER_SWING_RANGE_MULT: Array[float] = [0.75, 0.75, 0.75, 0.75]
const DAGGER_EDGE_PER_HIT: float = 20.0  # the katana gains EDGE_PER_HIT (25) per hit; the dagger hits more often
# Lightning strike: when the 4th dagger swing CONNECTS, a bolt from the sky also hits that boss (no telegraph, never on
# a whiff). Same rules as a normal hit: reduced by ARMOR_DAMAGE_FACTOR, x COUNTER_DAMAGE_MULT if the swing was a
# counter, posture only when it was not. It gains no Edge.
const LIGHTNING_STRIKE_DAMAGE: float = 20.0
const LIGHTNING_STRIKE_POSTURE: float = 8.0

# Lightning Form: the Dual Dagger's active (right click). Since 2026-10-19 (the human removed the 6 s form) it is ONLY
# the automatic Lightning Barrage below: a free action that costs Edge on the press, cannot be used again while it
# runs, and its cooldown counts from the activation. The "form" (weapon_form lightning_form, the buff state) lasts
# exactly as long as the barrage; there is no attack speed, walking speed or damage bonus and no blinking swings after.
const LIGHTNING_FORM_COOLDOWN_TICKS: int = 750  # 12.5 seconds (it deals little damage)
const LIGHTNING_FORM_EDGE_COST: float = 60.0
# Barrage blinks: the spot is LIGHTNING_BLINK_DISTANCE px from the boss centre in direction d (Vector2.RIGHT rotated
# by d * 45 degrees): outside the boss (>= BOSS_RADIUS + PLAYER_RADIUS = 26) and inside the dagger reach
# (<= BOSS_RADIUS + ATTACK_RANGE * 0.75 = 39.5). Each blink also gives LIGHTNING_BLINK_INVULN_TICKS of i-frames.
const LIGHTNING_BLINK_DISTANCE: float = 30.0
const LIGHTNING_BLINK_INVULN_TICKS: int = 6
const LIGHTNING_BLINK_ORDER: Array[int] = [0, 3, 6, 1, 4, 7, 2, 5]
# Lightning Barrage (first guesses set on 2026-10-19, nobody has played it): activating Lightning Form needs the boss
# alive (at any distance). One slash per entry of LIGHTNING_BLINK_ORDER (8): each blinks the player next to the boss
# from that side (nearest free side not used yet when it is blocked by a wall or prop) and hits
# LIGHTNING_BARRAGE_HIT_DELAY_TICKS later through the normal hit rules (armor, counter, posture).
# Slash k (0-based) blinks LIGHTNING_BARRAGE_START_DELAY_TICKS + k * LIGHTNING_BARRAGE_INTERVAL_TICKS ticks after the
# activation; the barrage ends LIGHTNING_BARRAGE_RECOVERY_TICKS after the last hit (1 + 42 + 2 + 10 = 55 ticks, about
# 0.9 s). The player cannot move or act and is invulnerable meanwhile. The last slash also calls the lightning strike.
const LIGHTNING_BARRAGE_START_DELAY_TICKS: int = 1
const LIGHTNING_BARRAGE_INTERVAL_TICKS: int = 6
const LIGHTNING_BARRAGE_HIT_DELAY_TICKS: int = 2  # must stay below the interval
const LIGHTNING_BARRAGE_RECOVERY_TICKS: int = 10
const LIGHTNING_BARRAGE_DAMAGE_MULT: float = 0.6  # x ATTACK_DAMAGE: a dagger swing 1-3
const LIGHTNING_BARRAGE_EDGE_PER_HIT: float = 5.0  # less than a swing (20) so the barrage does not refund its cost

# Chain Scythe (third weapon), first guesses set on 2026-10-20, nobody has played it yet. A slow, heavy, wide 3-hit
# combo: swing totals 22/21/34 ticks against the katana's 19/18/29 (the dagger's 12/12/12/21). Reach x1.3 of the
# katana's ATTACK_RANGE (34 px; the finisher 36 px), and a wider arc: SCYTHE_ARC_DOT -0.2 is a half arc of about 102
# degrees (the katana's ATTACK_ARC_DOT 0.2 is about 78), so it also hits straight to the sides. Damage multiplies
# ATTACK_DAMAGE like the other tables; posture per hit replaces NORMAL_HIT_POSTURE (4) for scythe swings.
const WEAPON_CHAIN_SCYTHE: StringName = &"chain_scythe"
const SCYTHE_COMBO_MAX: int = 3
const SCYTHE_SWING_WINDUP_TICKS: Array[int] = [8, 7, 11]
const SCYTHE_SWING_ACTIVE_TICKS: Array[int] = [4, 4, 5]
const SCYTHE_SWING_RECOVERY_TICKS: Array[int] = [10, 10, 18]
const SCYTHE_SWING_DAMAGE_MULT: Array[float] = [1.0, 1.1, 1.7]
const SCYTHE_SWING_RANGE_MULT: Array[float] = [1.3, 1.3, 1.4]
const SCYTHE_SWING_POSTURE: Array[float] = [5.0, 5.0, 9.0]
const SCYTHE_ARC_DOT: float = -0.2
const SCYTHE_EDGE_PER_HIT: float = 25.0  # like the katana

# Reaper's Coil: the Chain Scythe's active (right click), first guesses set on 2026-10-20. A free action on the press
# (needs the boss alive, at any distance; costs Edge, cooldown from the activation, no use while it runs) that runs a
# scripted skill (player state reaper_coil: no movement, no actions, invulnerable):
# HOOK: the chain flies from the player in the aim direction (else the facing), REAPER_COIL_HOOK_SPEED px per tick, up
#   to REAPER_COIL_HOOK_RANGE px (12 ticks), stopped by solid props and the arena wall.
# Boss hooked -> DRAG: the boss's attack is cancelled and it is pulled REAPER_COIL_DRAG_SPEED px per tick toward the
#   player until its centre is BOSS_RADIUS + PLAYER_RADIUS + REAPER_COIL_DRAG_GAP px away (or props block it, or
#   REAPER_COIL_DRAG_MAX_TICKS ran out). Then it is staggered for REAPER_COIL_STAGGER_TICKS (no attacks, no walking).
#   SPIN: REAPER_COIL_SPIN_TICKS ticks, hits on spin ticks FIRST_HIT and FIRST_HIT + INTERVAL (anything within
#   REAPER_COIL_SPIN_RADIUS px of the player, plus the target's radius), then REAPER_COIL_RECOVERY_TICKS.
# Missed -> PULL: the player is pulled to where the chain stopped, REAPER_COIL_PULL_SPEED px per tick, then
#   REAPER_COIL_PULL_RECOVERY_TICKS. No stagger, no spin.
const REAPER_COIL_EDGE_COST: float = 50.0
const REAPER_COIL_COOLDOWN_TICKS: int = 600  # 10 seconds (it deals little damage)
const REAPER_COIL_HOOK_RANGE: float = 150.0
const REAPER_COIL_HOOK_SPEED: float = 12.5  # 150 / 12.5 = 12 ticks to full range
const REAPER_COIL_CHAIN_WIDTH: float = 8.0  # the chain touches a circle within half of this
const REAPER_COIL_DRAG_SPEED: float = 10.0
const REAPER_COIL_DRAG_GAP: float = 8.0  # boss edge to player edge after the drag
const REAPER_COIL_DRAG_MAX_TICKS: int = 16
const REAPER_COIL_DRAG_BLOCKED_PX: float = 0.5  # a drag (or pull) tick that gains less than this is blocked: it ends
const REAPER_COIL_STAGGER_TICKS: int = 45  # the boss's stun, counted from the tick the drag ends
const BOSS_STAGGER_RECOVER_TICKS: int = 12  # the boss's recover state after the stun, then its normal cooldown
const REAPER_COIL_PULL_SPEED: float = 8.0
const REAPER_COIL_PULL_RECOVERY_TICKS: int = 8
const REAPER_COIL_SPIN_TICKS: int = 20
const REAPER_COIL_SPIN_FIRST_HIT_TICK: int = 4
const REAPER_COIL_SPIN_HIT_INTERVAL_TICKS: int = 8
const REAPER_COIL_SPIN_HITS: int = 2
const REAPER_COIL_SPIN_RADIUS: float = 36.0
const REAPER_COIL_SPIN_DAMAGE_MULT: float = 1.2  # x ATTACK_DAMAGE per spin hit
const REAPER_COIL_SPIN_POSTURE: float = 10.0
const REAPER_COIL_EDGE_PER_HIT: float = 5.0  # small, like the barrage
const REAPER_COIL_RECOVERY_TICKS: int = 10

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
# The beam leaves the boss's chest core, not its feet. This offset from the boss position (its feet) is the single
# authoritative muzzle: the shots are aimed from it, the warning and the damage capsules start at it, and it is
# locked when the attack commits. (Measured from the golem2 frames: the core sits about 30 px above the feet.)
const SHARDS_ORIGIN_OFFSET: Vector2 = Vector2(0.0, -30.0)
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
