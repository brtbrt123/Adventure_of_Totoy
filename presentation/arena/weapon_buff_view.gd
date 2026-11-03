extends RefCounted
## Snapshot-only cosmetic plans; no buff rules or multipliers live here.
const Snapshots := preload("res://core/snapshots.gd")
const Tuning := preload("res://core/tuning.gd")

const Weapons := preload("res://core/weapons.gd")
## Lightning Form aura: 10 back/front pairs looping at about 67 ms per frame (README of the dual dagger art).
const LIGHTNING_AURA_FRAMES: int = 10
const LIGHTNING_AURA_TICKS: int = 4

static func all_names() -> Array[String]:
	var names: Array[String] = []
	for prefix: String in ["fx_black_aura_back", "fx_black_aura_front"]:
		for frame: int in range(1, 7):
			names.append("%s_%d" % [prefix, frame])
	for prefix: String in ["fx_lightning_aura_back", "fx_lightning_aura_front"]:
		for frame: int in range(1, LIGHTNING_AURA_FRAMES + 1):
			names.append("%s_%d" % [prefix, frame])
	return names

static func fade_level(hero: Snapshots.EntitySnapshot, duration: int) -> int:
	if not hero.weapon_buff_active or duration <= 0:
		return 0
	# Pixel coverage fades during the final fifth; every visible pixel stays opaque.
	return clampi(ceili(float(hero.weapon_buff_ticks_left) / maxf(1.0, duration * 0.2) * 4.0), 1, 4)

static func plan(snap: Snapshots.GameSnapshot) -> Dictionary:
	return plan_for(snap.player, snap.tick, snap.hud.weapon_buff_duration, snap.result == &"playing")


## The same from what a scene knows: the hero, the tick, the buff's full length and whether the fight is still on.
static func plan_for(hero: Snapshots.EntitySnapshot, tick: int, buff_duration: int, _playing: bool) -> Dictionary:
	if not hero.weapon_buff_active:
		return {}
	if hero.weapon_form == Weapons.FORM_LIGHTNING:
		# The dagger's speed arcs are painted into its frames: no detached slash for the Lightning Form.
		var bolt: int = posmod(tick / LIGHTNING_AURA_TICKS, LIGHTNING_AURA_FRAMES) + 1
		return {"back": "fx_lightning_aura_back_%d" % bolt, "front": "fx_lightning_aura_front_%d" % bolt, "level": fade_level(hero, buff_duration), "at": hero.position, "form": Weapons.FORM_LIGHTNING}
	# The Black Form look (aura, detached slash) belongs to the katana only: the dagger outside its form and the
	# scythe (Reaper's Coil has no aura; its chain and ring are drawn by the arena) show nothing here.
	if hero.weapon_id != Tuning.WEAPON_BLACK_KATANA or hero.weapon_form == Weapons.FORM_REAPER_COIL:
		return {}
	# World time keeps the aura rolling when the character pose/state changes.
	var index: int = posmod(tick / 5, 6) + 1
	# The Black Form's slash is the swing's hit area drawn in black fire (presentation/common/swing_arc.gd), not a frame here.
	return {"back": "fx_black_aura_back_%d" % index, "front": "fx_black_aura_front_%d" % index, "level": fade_level(hero, buff_duration), "at": hero.position, "form": Weapons.FORM_BLACK_KATANA_BUFF}
