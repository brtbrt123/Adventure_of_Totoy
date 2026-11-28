extends RefCounted
## The drain on every mob's bar (the owner's TikTok reference, 2026-11-28; docs/PLAN_hit_feedback.md): a mob's lost health lingers
## DELAY ticks as a cream chunk, then drains DRAIN of its full health a tick (as the boss panel's ghost does). Keeps
## MobView.ghosts (mob id -> the health its bar still shows) for MobView.draw_bar. Cosmetic memory of the snapshot only.
const ExploreCore := preload("res://core/explore_core.gd")
const MobView := preload("res://presentation/explore/mob_view.gd")

const DELAY: int = 18
const DRAIN: float = 0.03

var _state: Dictionary = {}  # mob id -> {hp, delay}
var _tick: int = -1


func clear() -> void:
	_state.clear()
	MobView.ghosts.clear()
	_tick = -1


## Once a tick: each mob's lost health lingers, then drains toward its health.
func sync(view: ExploreCore.ExploreSnapshot) -> void:
	if view.tick == _tick:
		return
	var elapsed: int = maxi(1, view.tick - _tick) if _tick >= 0 else 1
	_tick = view.tick
	var seen: Dictionary = {}
	for mob: Dictionary in view.mobs:
		var id: int = int(mob["id"])
		seen[id] = true
		var hp: float = float(mob["hp"])
		if not _state.has(id) or hp > float(_state[id]["hp"]):
			_state[id] = {"hp": hp, "delay": 0}
			MobView.ghosts[id] = hp
			continue
		var s: Dictionary = _state[id]
		if hp < float(s["hp"]):
			s["delay"] = DELAY
		else:
			s["delay"] = maxi(0, int(s["delay"]) - elapsed)
			if int(s["delay"]) == 0:
				MobView.ghosts[id] = move_toward(float(MobView.ghosts.get(id, hp)), hp, elapsed * maxf(1.0, float(mob["max_hp"]) * DRAIN))
		s["hp"] = hp
	for id: int in _state.keys():
		if not seen.has(id):
			_state.erase(id)
			MobView.ghosts.erase(id)
