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

# Equippable aspects (2026-10-21, human-approved design): the player owns every aspect in Aspects.ALL and equips exactly
# SKILL_COUNT of them into the slots (skill_pressed 1-3 = Z, X, C) from the character menu (InputFrame.aspect_equip).
# Cooldowns belong to the aspect, not to the slot, so re-slotting never resets or skips one. Equip rules are the
# weapon equip's (idle or walk only, never while a weapon buff/form runs) with no lockout.
# 4. Spirit Lantern (first guesses, 2026-10-21): a skill action (windup -> active -> recovery, no movement in it). On
# the first skill_active tick a lantern is placed at the player's feet. It stays SPIRIT_LANTERN_DURATION_TICKS and
# pulses every SPIRIT_LANTERN_PULSE_INTERVAL_TICKS (pulse k at placement + k * interval, the last one on its final
# tick, then it expires): the player standing within SPIRIT_LANTERN_RADIUS px (centre distance, inclusive) heals and
# gains Edge (both capped). The boss is unaffected. One lantern per player: a new one replaces the old one. The Edge
# cost is spent on the press (not refunded if the windup is interrupted, like every skill); the cooldown starts when
# the lantern is placed, so an interrupted windup costs no cooldown.
const SPIRIT_LANTERN_EDGE_COST: float = 30.0
const SPIRIT_LANTERN_COOLDOWN_TICKS: int = 900  # 15 seconds, counted from the placement
const SPIRIT_LANTERN_WINDUP_TICKS: int = 10
const SPIRIT_LANTERN_ACTIVE_TICKS: int = 1  # the placement pose; the lantern appears on this tick
const SPIRIT_LANTERN_RECOVERY_TICKS: int = 8
const SPIRIT_LANTERN_DURATION_TICKS: int = 300  # 5 seconds
const SPIRIT_LANTERN_PULSE_INTERVAL_TICKS: int = 60
const SPIRIT_LANTERN_PULSES: int = 5  # DURATION / INTERVAL
const SPIRIT_LANTERN_RADIUS: float = 44.0  # the human asked for a bigger range than a small circle
const SPIRIT_LANTERN_HEAL_PER_PULSE: int = 6
const SPIRIT_LANTERN_EDGE_PER_PULSE: float = 8.0
# 5. Phantom Cut (first guesses, 2026-10-21): a buff aspect, a free action like the weapon active (no state change; any
# state but dead, the Lightning Barrage and Reaper's Coil). For PHANTOM_CUT_DURATION_TICKS every NORMAL swing that
# connects queues a phantom echo that lands PHANTOM_CUT_DELAY_TICKS after the real hit on the boss wherever it is then
# (no range check): damage = the swing's base damage x PHANTOM_CUT_DAMAGE_MULT under the normal armor/counter rules,
# posture = the swing's posture x PHANTOM_CUT_POSTURE_MULT when not a counter. An echo never gains or spends Edge
# (a counter echo has no Edge bonus), never advances the combo and never calls a finisher (no lightning strike).
# Edge cost on the press, cooldown from the activation, cannot be refreshed while it runs. Ends on timeout or death;
# echoes already queued still land after the timeout.
const PHANTOM_CUT_EDGE_COST: float = 40.0
const PHANTOM_CUT_COOLDOWN_TICKS: int = 1200  # 20 seconds, counted from the activation
const PHANTOM_CUT_DURATION_TICKS: int = 300  # 5 seconds
const PHANTOM_CUT_DELAY_TICKS: int = 14
const PHANTOM_CUT_DAMAGE_MULT: float = 0.6
const PHANTOM_CUT_POSTURE_MULT: float = 0.6
# 6. Sprint (first guesses, 2026-10-21): a buff aspect, a free action like Phantom Cut (no state change; any state but
# dead, the Lightning Barrage and Reaper's Coil). For SPRINT_DURATION_TICKS (from the press tick through press + 179)
# every move that uses the walking speed is SPRINT_MOVE_SPEED_MULT faster: walking, the slowed movement in a swing,
# the parry recovery, the Moon Cleave hold and the Stone Ward. Dash, Gale Cut, Breaking Edge's step, the barrage and
# the coil keep their own fixed speeds. Edge cost on the press, cooldown from the activation, no refresh while it runs;
# ends on timeout (sprint_ended expired on press + 180) or death.
const SPRINT_EDGE_COST: float = 20.0
const SPRINT_COOLDOWN_TICKS: int = 720  # 12 seconds, counted from the activation
const SPRINT_DURATION_TICKS: int = 180  # 3 seconds
const SPRINT_MOVE_SPEED_MULT: float = 2.0
# 7. Echo Step (first guesses, 2026-10-21): a free action (no windup, no state change on the press; any state but dead,
# the Lightning Barrage and Reaper's Coil). The press places an echo anchor where the player stands after this tick's
# movement (kept in the arena and out of props); ECHO_STEP_DELAY_TICKS later the player is pulled back to it: an
# instant teleport that cancels whatever they were doing (back to idle; a Stone Ward releases first) and gives
# ECHO_STEP_INVULN_TICKS of invulnerability from the arrival tick. A running barrage or coil is never interrupted: the
# recall waits until it ends (at most Weapons.reaper_coil_total_ticks(), 58 ticks). A boss standing on the anchor at
# arrival: the nearest free spot next to it. One echo at a time: a press while one exists does nothing (no cost).
# Cost on the press, cooldown from the placement (the press tick). Death removes the echo.
const ECHO_STEP_EDGE_COST: float = 25.0
const ECHO_STEP_COOLDOWN_TICKS: int = 840  # 14 seconds, counted from the placement
const ECHO_STEP_DELAY_TICKS: int = 120  # 2 seconds from the placement to the recall
const ECHO_STEP_INVULN_TICKS: int = 12  # from the arrival tick, inclusive
# 8. Stone Ward (first guesses, 2026-10-21): a skill action from idle, walk or a swing's recovery. Instant raise: the
# player is in state `ward` for STONE_WARD_DURATION_TICKS (no cancel), moves at STONE_WARD_MOVE_FACTOR of the walking
# speed, facing locked, no dash, attack, parry, skill or weapon active. Every hit that would damage the player (any boss
# attack, gold ones included: no parry bonus) is blocked: no damage, no hurt state, no combo reset, no hurt
# invulnerability; its damage is stored (sum, capped at STONE_WARD_STORE_CAP). When the ward ends it releases a
# shockwave of STONE_WARD_RADIUS px around the player: the boss (its circle) inside takes (STONE_WARD_BASE_DAMAGE +
# stored x STONE_WARD_STORE_MULT) x the damage multiplier under the skill hit rules (armored x ARMOR_DAMAGE_FACTOR plus
# STONE_WARD_POSTURE + stored x STONE_WARD_POSTURE_PER_STORED posture and STONE_WARD_EDGE_GAIN Edge; a counter while
# the posture is broken x COUNTER_DAMAGE_MULT, no Edge change). The player's death ends it without a release. Cost on
# the press, cooldown from the activation.
const STONE_WARD_EDGE_COST: float = 30.0
const STONE_WARD_COOLDOWN_TICKS: int = 720  # 12 seconds, counted from the activation
const STONE_WARD_DURATION_TICKS: int = 60  # 1 second
const STONE_WARD_MOVE_FACTOR: float = 0.3
const STONE_WARD_STORE_CAP: int = 60
const STONE_WARD_BASE_DAMAGE: float = 8.0
const STONE_WARD_STORE_MULT: float = 1.0
const STONE_WARD_RADIUS: float = 64.0
const STONE_WARD_POSTURE: float = 12.0
const STONE_WARD_POSTURE_PER_STORED: float = 0.5
const STONE_WARD_EDGE_GAIN: float = 10.0

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

# Weapon swap: InputFrame.weapon_equip names the weapon to equip (presentation sends it from the character menu's
# inventory; the Q cycle was removed on 2026-10-21). A free action, only
# from idle or walk, never while a weapon buff/form runs. After a swap the next swap waits WEAPON_SWAP_LOCKOUT_TICKS.
# Every weapon keeps its own active cooldown, so swapping never resets one. The player always starts with the katana.
const WEAPON_SWAP_LOCKOUT_TICKS: int = 0  # no lockout: weapons are only equipped from the paused character menu

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

# Mobs (core/mob_field.gd): the regular enemies of the exploration scenes (chapter 1: Mossling, Thornback Boar). Every type
# has at most two attacks and obeys the gold/red rule (gold lunge = parry it, red charge = dash it). No randomness.
#   level (shown on its bar), exp (paid once, the first time the hero fells it), drop {item, chance 0-1: rolled once per mob, the same
#   result every time), hp, radius (body circle), speed (chase px/tick), aggro (the hero this close wakes the whole encounter), tether (a mob
#   that gets this far from home gives up), hold (it stops chasing this far from the hero), wait (it holds this far away while
#   two others attack)
#   attack: kind (gold or red), start_min/start_max (the hero's distance that starts it), windup (warning ticks, aim locked on the
#   first one), strike_ticks and strike_speed (the lunge/charge: px per tick), width (warning lane), damage, recover (ticks after a
#   miss), cooldown (ticks before it may start another), interrupt (a normal hit during the windup cancels it), crash (the
#   charge stops at a prop and the mob is stunned and exposed this long; 0 = no crash)
const MOBS: Dictionary = {
	&"mossling": {
		"level": 1, "exp": 10, "drop": {"item": &"herb", "chance": 0.4}, "hp": 30, "radius": 6.0, "speed": 0.65, "aggro": 84.0, "tether": 230.0, "hold": 24.0, "wait": 56.0,
		"attack": {"id": &"lunge", "kind": &"gold", "start_min": 14.0, "start_max": 50.0, "windup": 36, "strike_ticks": 10, "strike_speed": 5.2,
			"width": 18.0, "damage": 12, "recover": 36, "cooldown": 70, "interrupt": true, "crash": 0},
	},
	# The Thornback Stag, the glade's mini-boss: one mob with three attacks. SLAM is gold (parry it: the Stag is stunned and exposed), CHARGE is
	# red (dash across the lane; a charge into a prop crashes it), and ROOTS (phase two only, when it falls to PHASE2_HP of its health and
	# roars) is red too: a burst under where the hero stood. Each attack row: kind, shape (line, cone or circle), the distance band the Stag
	# starts it from, windup (the warning), strike_ticks (the dangerous window or the run), damage, recover and cooldown.
	&"stag": {
		"level": 3, "exp": 60, "drop": {"item": &"herb", "chance": 1.0}, "hp": 260, "radius": 20.0, "speed": 0.6, "aggro": 130.0, "tether": 320.0, "hold": 30.0, "wait": 90.0,
		"boss": true, "phase2_hp": 0.5, "roar_ticks": 54,
		"summon": {"type": &"glowmoth", "count": 5, "ring_min": 44.0, "ring_max": 100.0, "regen_per_second": 0.02, "lockout": 900, "first_ready": 300},
		"attacks": [
			{"id": &"stag_slam", "kind": &"gold", "shape": &"cone", "reach": 125.0, "half_angle": 0.95, "start_min": 0.0, "start_max": 125.0, "windup": 54, "strike_ticks": 6,
				"strike_speed": 0.0, "width": 0.0, "damage": 18, "recover": 48, "cooldown": 46, "interrupt": false, "crash": 0, "phase": 1},
			{"id": &"stag_charge", "kind": &"red", "shape": &"line", "start_min": 84.0, "start_max": 210.0, "windup": 56, "strike_ticks": 24, "strike_speed": 6.6,
				"width": 30.0, "damage": 24, "recover": 40, "cooldown": 56, "interrupt": false, "crash": 80, "phase": 1},
			{"id": &"stag_roots", "kind": &"red", "shape": &"circle", "reach": 34.0, "start_min": 0.0, "start_max": 230.0, "windup": 50, "strike_ticks": 5,
				"strike_speed": 0.0, "width": 0.0, "damage": 16, "recover": 40, "cooldown": 40, "interrupt": false, "crash": 0, "phase": 2,
				"sites": 8, "site_spacing": 40.0, "escape_reach": 70.0},
			{"id": &"stag_summon", "kind": &"none", "shape": &"none", "summon": true, "start_min": 0.0, "start_max": 400.0, "windup": 90, "strike_ticks": 10,
				"strike_speed": 0.0, "width": 0.0, "damage": 0, "recover": 50, "cooldown": 60, "interrupt": false, "crash": 0, "phase": 1},
		],
		"attack": {"id": &"stag_slam", "kind": &"gold", "start_min": 0.0, "start_max": 125.0, "windup": 54, "strike_ticks": 6, "strike_speed": 0.0, "width": 0.0, "damage": 18,
			"recover": 48, "cooldown": 46, "interrupt": false, "crash": 0},
	},
	&"boar": {
		"level": 2, "exp": 25, "drop": {"item": &"herb", "chance": 0.6}, "hp": 70, "radius": 9.0, "speed": 0.55, "aggro": 110.0, "tether": 260.0, "hold": 100.0, "wait": 110.0,
		"attack": {"id": &"charge", "kind": &"red", "start_min": 24.0, "start_max": 140.0, "windup": 50, "strike_ticks": 38, "strike_speed": 3.4,
			"width": 24.0, "damage": 20, "recover": 40, "cooldown": 90, "interrupt": false, "crash": 70},
	},
	# The Glowmoth: the Stag's summoned moth (core/mob_field.gd _summon). It never starts an encounter and pays no EXP, drop or flag; it is removed
	# when the Stag falls or the encounter resets. Its ORB is a real projectile: the windup warns with a red lane exactly as wide as the orb's
	# hit (2 x radius), then the orb flies along it at `speed` px/tick until it hits the hero, a prop, or travels `reach`; a dash's
	# invulnerability lets it pass through. The moth's death removes its orb.
	&"glowmoth": {
		"level": 2, "exp": 0, "drop": {"item": &"herb", "chance": 0.0}, "hp": 20, "radius": 5.0, "speed": 0.9, "aggro": 999.0, "tether": 600.0, "hold": 70.0, "wait": 90.0,
		"summoned": true,
		"attack": {"id": &"moth_orb", "kind": &"red", "shape": &"line", "stationary": true, "reach": 140.0, "start_min": 30.0, "start_max": 120.0, "windup": 40, "strike_ticks": 8,
			"strike_speed": 0.0, "width": 8.0, "damage": 6, "recover": 40, "cooldown": 100, "interrupt": true, "crash": 0,
			"projectile": {"visual": &"glowmoth_orb", "speed": 2.4, "radius": 4.0}},
	},
	# The Runebound Warden (the Hollow Trial's hard mob, docs/PLAN_hollow_trial.md). Its rune GUARDS it: hits do only `guard` x damage until a
	# parried gold attack stuns it (then it is exposed like any stunned mob). Rune Cleave is gold (parry it); an unparried Cleave chains into
	# Root Lash `chain.delay` ticks later. Root Lash is a red line that does not move the Warden (`stationary`), Spore Ring a red burst around
	# the Warden itself (`centered`): dash out of both. Only one Warden attacks at a time (`solo_attack`).
	&"warden": {
		"level": 3, "exp": 45, "drop": {"item": &"herb", "chance": 0.8}, "hp": 140, "radius": 11.0, "speed": 0.5, "aggro": 120.0, "tether": 300.0, "hold": 28.0, "wait": 90.0,
		"guard": 0.4, "solo_attack": true,
		"attacks": [
			{"id": &"warden_cleave", "kind": &"gold", "shape": &"cone", "reach": 46.0, "half_angle": 0.9, "start_min": 0.0, "start_max": 56.0, "windup": 40, "strike_ticks": 6,
				"strike_speed": 0.0, "width": 0.0, "damage": 20, "recover": 44, "cooldown": 40, "interrupt": false, "crash": 0, "chain": {"id": &"warden_lash", "delay": 12}},
			{"id": &"warden_lash", "kind": &"red", "shape": &"line", "stationary": true, "reach": 150.0, "start_min": 40.0, "start_max": 160.0, "windup": 44, "strike_ticks": 8,
				"strike_speed": 0.0, "width": 20.0, "damage": 18, "recover": 40, "cooldown": 50, "interrupt": false, "crash": 0},
			{"id": &"warden_ring", "kind": &"red", "shape": &"circle", "centered": true, "reach": 48.0, "start_min": 0.0, "start_max": 40.0, "windup": 56, "strike_ticks": 5,
				"strike_speed": 0.0, "width": 0.0, "damage": 22, "recover": 44, "cooldown": 60, "interrupt": false, "crash": 0},
		],
		"attack": {"id": &"warden_cleave", "kind": &"gold", "start_min": 0.0, "start_max": 56.0, "windup": 40, "strike_ticks": 6, "strike_speed": 0.0, "width": 0.0, "damage": 20,
			"recover": 44, "cooldown": 40, "interrupt": false, "crash": 0},
	},
}
const MOB_MAX_ATTACKERS: int = 2  # mobs of one encounter that may wind up or strike at the same time
const MOB_FIRST_COOLDOWN: int = 30  # a woken mob waits this long, plus MOB_COOLDOWN_STAGGER x its place, before its first attack
const MOB_COOLDOWN_STAGGER: int = 25
const MOB_ALERT_TICKS: int = 24  # the pause when the pack wakes
const MOB_HURT_TICKS: int = 10  # a hit that did not cancel anything staggers the mob's walk this long
const MOB_STAGGER_TICKS: int = 90  # a mob whose lunge was parried is stunned and exposed this long
const MOB_EXPOSED_MULT: float = 3.0  # damage multiplier on an exposed mob (parried or crashed)

# Lightning Form and Reaper's Coil on the road (several mobs at once). The main target is the nearest mob in front of the hero (within
# ROAD_TARGET_RANGE px and the cone whose cosine is ROAD_TARGET_CONE_DOT, the aim direction); mobs within CLUMP_RADIUS px of the hooked mob
# are dragged in with it. A cast that hits `n` mobs gives each 1 - MULTI_HIT_FALLOFF * (n - 1) of its damage (never below MULTI_HIT_MIN_MULT).
const ROAD_TARGET_RANGE: float = 220.0
const ROAD_TARGET_CONE_DOT: float = 0.5
const CLUMP_RADIUS: float = 44.0
const MULTI_HIT_FALLOFF: float = 0.2
const MULTI_HIT_MIN_MULT: float = 0.4
const MOB_DEATH_TICKS: int = 40  # a defeated mob stays in the snapshot (state dead) this long
const MOB_RETURN_SPEED_MULT: float = 1.6  # a mob walking home
const MOB_LEASH_GRACE_TICKS: int = 60  # the hero outside the encounter's leash this long: the mobs give up and walk home
const MOB_RESET_TICKS: int = 240  # ...and this long: an uncleared encounter is whole again (dead mobs return)
const MOB_SEPARATION_PUSH: float = 0.5

# Hero in exploration: death and healing items.
const HERO_DEFEAT_TICKS: int = 120  # from the hero's death to his return at the last checkpoint
const HERB_HEAL: int = 35
const INVENTORY_MAX_STACK: int = 99

# Hero level, EXP and stat points (exploration; ExploreCore; docs/PROGRESSION_PLAN.md). EXP comes from felling mobs (once per mob, the story flag
# killed_<encounter>_<n>) and from the village tasks. EXP_TO_NEXT[i] is what level i+1 needs to reach level i+2. Each level above 1 gives
# LEVEL_HP_BONUS max health on its own (a hero who ignores the menu is fine), a full heal, and STAT_POINTS_PER_LEVEL points to spend on
# three modest stats (the design keeps stat boosts small: the real power is learning the attacks). No defence stat on purpose.
const LEVEL_MAX: int = 10
const EXP_TO_NEXT: Array[int] = [30, 50, 80, 120, 170, 230, 300, 380, 470]
const LEVEL_HP_BONUS: int = 5
const STAT_POINTS_PER_LEVEL: int = 2
const STAT_IDS: Array[StringName] = [&"vitality", &"might", &"agility"]
const STAT_CAP: Dictionary = {&"vitality": 10, &"might": 10, &"agility": 10}
const VITALITY_HP_PER_POINT: int = 6  # max health
const MIGHT_DAMAGE_PER_POINT: float = 0.03  # +3 % damage on the hero's blows (mobs and the boss alike)
const AGILITY_DASH_COOLDOWN_TICKS_PER_POINT: int = 2  # shorter dash cooldown, for the first AGILITY_DASH_POINTS points
const AGILITY_DASH_POINTS: int = 6
const AGILITY_SPEED_PER_POINT: float = 0.005  # +0.5 % walking speed

# Exploration: Edge (the Aspect meter) fills this much per tick while no encounter is awake (travel), so Sprint can be used on the road.
const EXPLORE_EDGE_REGEN_PER_TICK: float = 0.25
