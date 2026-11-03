extends RefCounted
## Cosmetic hoof trails sampled from real snapshot positions, never predicted movement or hit geometry.
const ExploreCore := preload("res://core/explore_core.gd")
var marks: Array[Dictionary] = []
var previous: Dictionary = {}
var bursts: Array[Dictionary] = []
func clear() -> void:
	marks.clear()
	previous.clear()
	bursts.clear()
func sync(view: ExploreCore.ExploreSnapshot) -> void:
	marks = marks.filter(func(e: Dictionary) -> bool: return view.tick-int(e["tick"])<22)
	bursts = bursts.filter(func(e: Dictionary) -> bool: return view.tick-int(e["tick"])<24)
	var active: Dictionary = {}
	for mob: Dictionary in view.mobs:
		if mob["type"] != &"boar":continue
		var id: int = int(mob["id"])
		var pos: Vector2 = mob["position"]
		var state: StringName = mob["state"]
		var old: Dictionary = previous.get(id,{})
		active[id] = true
		if not old.is_empty() and old["state"] != state and state in [&"strike",&"crash",&"recover"]:
			bursts.append({"at":pos,"dir":mob["facing"],"state":state,"tick":view.tick})
		if state==&"strike" and not old.is_empty() and int(view.tick)%2==0 and pos.distance_to(old["at"])>0.5:
			marks.append({"at":pos-Vector2(mob["facing"])*15,"dir":mob["facing"],"tick":view.tick})
		previous[id] = {"at":pos,"state":state}
	for id: int in previous.keys():
		if not active.has(id):previous.erase(id)
	if marks.size()>32:marks=marks.slice(marks.size()-32)
func plans(view: ExploreCore.ExploreSnapshot) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mark: Dictionary in marks:
		var age: int = view.tick-int(mark["tick"])
		var drift: Vector2 = -Vector2(mark["dir"])*age*0.25
		out.append({"family":"dust","at":Vector2(mark["at"])+drift,"age":age,"scale":2 if age<8 else 1})
	for mob: Dictionary in view.mobs:
		if mob["type"]!=&"boar":continue
		var state: StringName = mob["state"]
		var at: Vector2 = mob["position"]
		var facing: Vector2 = Vector2(mob["facing"]).normalized()
		var phase: int = int(mob["state_ticks"])
		if state==&"windup":
			# Alternating rear-hoof scrapes accompany the locked warning; don't extend the lane.
			var side: Vector2 = Vector2(-facing.y,facing.x)*(5 if (phase/7)%2==0 else -5)
			out.append({"family":"dust","at":at-facing*10+side,"age":posmod(phase,14),"scale":2})
		elif state==&"recover" and phase<20:
			out.append({"family":"dust","at":at-facing*13,"age":phase,"scale":2})
	for burst: Dictionary in bursts:
		var age: int = view.tick-int(burst["tick"])
		var at: Vector2 = burst["at"]
		var dir: Vector2 = burst["dir"]
		if burst["state"]==&"crash":
			for side: int in [-1,0,1]:
				out.append({"family":"dust","at":at+Vector2(-dir.y,dir.x)*side*(7+age/2),"age":age,"scale":2})
			if age<6:out.append({"family":"hit","at":at+dir*14-Vector2(0,7),"age":age,"scale":2})
		elif burst["state"]==&"strike" and age<16:
			out.append({"family":"dust","at":at-dir*16,"age":age,"scale":2})
	return out
