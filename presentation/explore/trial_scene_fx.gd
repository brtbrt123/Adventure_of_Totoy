extends RefCounted
## Trial facts to cosmetics. Never schedules or spawns a mob, changes a flag, or awards anything.
const GameEvent := preload("res://core/game_event.gd")
var scene_id: StringName = &""
var last_tick: int = -1
var warnings: Array[Dictionary] = []
var arrivals: Array[Dictionary] = []
var pulses: Array[Dictionary] = []

func clear() -> void:
	scene_id = &""
	last_tick = -1
	warnings.clear()
	arrivals.clear()
	pulses.clear()

func sync(scene: StringName, tick: int) -> void:
	if scene != scene_id or tick < last_tick:
		clear()
	scene_id = scene
	last_tick = tick
	warnings = warnings.filter(func(w: Dictionary) -> bool: return tick < int(w["arrive"]))
	arrivals = arrivals.filter(func(w: Dictionary) -> bool: return tick-int(w["tick"])<24)
	pulses = pulses.filter(func(w: Dictionary) -> bool: return tick-int(w["tick"])<30)

func handle_event(event: GameEvent) -> void:
	match event.type:
		&"trial_spawn_warned":
			for at: Vector2 in event.data["positions"]:
				warnings.append({"at":at,"tick":event.tick,"arrive":int(event.data["arrive_tick"])})
		&"mob_alerted":
			if event.data.get("encounter_id", &"") == &"hollow_trial":  # only the trial's own arrivals
				arrivals.append({"at":event.data["position"],"tick":event.tick})
		&"trial_started", &"trial_wave_cleared", &"trial_won":
			pulses.append({"tick":event.tick})
		&"trial_failed":
			warnings.clear()
			arrivals.clear()
			pulses.clear()

static func cleared_segments(trial: Dictionary) -> int:
	if trial.get("state", &"") == &"won":
		return int(trial.get("waves",3))
	return maxi(0,int(trial.get("wave",0))-(0 if trial.get("state",&"")==&"between" else 1))

func draw_ground(canvas: Node2D, tick: int, colours: Dictionary, altar: Vector2 = Vector2(256, 180)) -> void:
	for w: Dictionary in warnings:
		var at: Vector2 = w["at"]
		var progress: float = clampf(float(tick-int(w["tick"]))/maxi(1,int(w["arrive"])-int(w["tick"])),0.0,1.0)
		canvas.draw_arc(at.round(),9.0,0,TAU,24,colours["8"],3.0,false)
		canvas.draw_arc(at.round(),9.0,-PI*.5,-PI*.5+TAU*progress,24,colours["o"],1.0,false)
		canvas.draw_polyline(PackedVector2Array([at+Vector2(0,-5),at+Vector2(4,0),at+Vector2(0,5),at+Vector2(-4,0),at+Vector2(0,-5)]),colours["u"],1.0,false)
		for i: int in 3:
			var mote: Vector2 = at+Vector2((i-1)*4,-4-posmod(tick/3+i*4,15))
			canvas.draw_rect(Rect2(mote.round(),Vector2.ONE),colours["p"])
	for arrival: Dictionary in arrivals:
		var age: int = tick-int(arrival["tick"])
		canvas.draw_arc(arrival["at"],4+age*.6,0,TAU,24,colours["o"] if age<8 else colours["t"],1.0,false)
	for pulse: Dictionary in pulses:
		var age: int = tick-int(pulse["tick"])
		canvas.draw_arc(altar,8+age*2.5,0,TAU,48,colours["u"] if age<12 else colours["t"],1.0,false)

static func draw_altar_progress(canvas: Node2D, trial: Dictionary, colours: Dictionary, altar: Vector2 = Vector2(256, 180)) -> void:
	var cleared: int = cleared_segments(trial)
	for i: int in 3:
		canvas.draw_rect(Rect2(altar + Vector2(-11 + i * 10, -10), Vector2(6, 2)),colours["o"] if i<cleared else colours["e"])
