extends "res://presentation/arena/hud.gd"
## Objective/ring art reads snapshots; chest history affects drawing only.
const ExploreCore := preload("res://core/explore_core.gd")
var view: ExploreCore.ExploreSnapshot
var chest_tick: int = -1000
func clear() -> void:chest_tick=-1000
func sync(value: ExploreCore.ExploreSnapshot, palette: Dictionary, data: Dictionary, atlas: Texture2D) -> void:
	view=value
	colors=palette
	ui_frames=data
	portrait_atlas=atlas
	z_index=7
	queue_redraw()
func _draw() -> void:
	if view==null or colors.is_empty():return
	if not view.objective.is_empty() and not String(view.objective.get("target","")).is_empty():
		var at: Vector2=view.objective.get("position",Vector2.ZERO)
		var height: float=60.0 if view.objective.get("target",&"")==&"training_dummy" else 52.0
		for npc: Dictionary in view.npcs:
			if npc["id"]==view.objective["target"]:height=52.0
		var visible_world: Rect2=get_canvas_transform().affine_inverse()*get_viewport_rect()
		if at.y-height<visible_world.position.y+24:return
		ui("progress_objective_%d" % (posmod(view.tick/12,4)+1),Rect2((at-Vector2(8,height)).round(),Vector2(16,16)))
