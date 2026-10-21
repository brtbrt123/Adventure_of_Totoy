extends RefCounted
## Snapshot-only cosmetic plans; no buff rules or multipliers live here.
const Snapshots := preload("res://core/snapshots.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const Tuning := preload("res://core/tuning.gd")

const Weapons := preload("res://core/weapons.gd")
## Lightning Form aura: 10 back/front pairs looping at about 67 ms per frame (README of the dual dagger art).
const LIGHTNING_AURA_FRAMES: int = 10
const LIGHTNING_AURA_TICKS: int = 4

static func all_names() -> Array[String]:
	var names: Array[String] = []
	for prefix: String in ["fx_black_aura_back", "fx_black_aura_front", "fx_black_slash"]:
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
	var hero: Snapshots.EntitySnapshot = snap.player
	if not hero.weapon_buff_active:
		return {}
	if hero.weapon_form == Weapons.FORM_LIGHTNING:
		# The dagger's speed arcs are painted into its frames: no detached slash for the Lightning Form.
		var bolt: int = posmod(snap.tick / LIGHTNING_AURA_TICKS, LIGHTNING_AURA_FRAMES) + 1
		return {"back": "fx_lightning_aura_back_%d" % bolt, "front": "fx_lightning_aura_front_%d" % bolt, "level": fade_level(hero, snap.hud.weapon_buff_duration), "at": hero.position, "slash": "", "form": Weapons.FORM_LIGHTNING}
	# The Black Form look (aura, detached slash) belongs to the katana only: the dagger outside its form and the
	# scythe (Reaper's Coil has no aura; its chain and ring are drawn by the arena) show nothing here.
	if hero.weapon_id != Tuning.WEAPON_BLACK_KATANA or hero.weapon_form == Weapons.FORM_REAPER_COIL:
		return {}
	# World time keeps the aura rolling when the character pose/state changes.
	var index: int = posmod(snap.tick / 5, 6) + 1
	var data: Dictionary = {"back": "fx_black_aura_back_%d" % index, "front": "fx_black_aura_front_%d" % index, "level": fade_level(hero, snap.hud.weapon_buff_duration), "at": hero.position, "slash": "", "form": Weapons.FORM_BLACK_KATANA_BUFF}
	# No detached slash during anticipation or a long recovery hold.
	# The imported hero paints a side-view sword; arena attaches the trail to that pose.
	if snap.result != &"playing":
		return data
	if hero.state in [&"attack_active", &"attack_recovery"]:
		var durations: Array[int] = ArenaAnimation.swing_durations(hero)
		var active: bool = hero.state == &"attack_active"
		var duration: int = durations[1] if active else mini(6, durations[2])
		if active or hero.state_ticks < duration:
			data["slash"] = "fx_black_slash_%d" % ((2 if active else 4) + mini(1, maxi(0, hero.state_ticks) * 2 / maxi(1, duration)) + 1)
	elif hero.state in [&"skill_active", &"skill_recovery"]:
		var durations: Array[int] = ArenaAnimation.skill_durations(hero.skill_id)
		var active: bool = hero.state == &"skill_active"
		var duration: int = durations[1] if active else mini(6, durations[2])
		if active or hero.state_ticks < duration:
			data["slash"] = "fx_black_slash_%d" % ((2 if active else 4) + mini(1, maxi(0, hero.state_ticks) * 2 / maxi(1, duration)) + 1)
	return data
