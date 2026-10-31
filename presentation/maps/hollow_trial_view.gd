@tool
extends Node2D
## Editable visual map. No combat, spawning, interaction or collision rules run here.
const Light := preload("res://presentation/common/environment_light.gd")
const LocalShadows := preload("res://presentation/common/local_prop_shadows.gd")
const ActorShadow := preload("res://presentation/common/actor_shadow.gd")
@export var preview_lit: bool = false:
	set(value):
		preview_lit = value
		if is_node_ready():
			apply_state({"state": &"won" if value else &"idle", "sealed": preview_sealed}, [], visual_tick)
@export var preview_chest_open: bool = false:
	set(value):
		preview_chest_open = value
		if is_node_ready():
			apply_state({"state": &"won" if preview_lit else &"idle", "sealed": preview_sealed}, [], visual_tick)
@export var preview_sealed: bool = false:
	set(value):
		preview_sealed = value
		if is_node_ready():
			apply_state({"state": &"won" if preview_lit else &"idle", "sealed": value}, [], visual_tick)
@export var animate_preview: bool = true
var visual_tick: int = 0
var lamps: Dictionary = {}
var prop_records: Array[Dictionary] = []
var snapshot_driven: bool = false
var _types: Dictionary = {}
var _preview_seconds: float = 0.0
var _state_key: String = ""
var _editor_layout: String = ""
var _anchors: Dictionary = {}

func _ready() -> void:
	$Ground.use_parent_material = true
	$FloorEffects.use_parent_material = true
	$Props.use_parent_material = true
	$Overlay.use_parent_material = true
	for node: Node in $Props.get_children():
		_types[String(node.name)] = node.scene_file_path.get_file().trim_suffix(".tscn")
	apply_state({"state": &"won" if preview_lit else &"idle", "sealed": preview_sealed}, [], 0)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		var layout: String = ""
		for prop: Node2D in $Props.get_children():
			layout += var_to_str([prop.position,prop.get_meta("flip",false),prop.get_node("Sprite").offset])
			for marker: Node in prop.get_children():
				if marker.has_meta("socket"):
					layout += var_to_str([(marker as Node2D).position,marker.get_meta("socket")])
		if layout != _editor_layout:
			_rebuild_records()
			_editor_layout = layout
	if animate_preview and not snapshot_driven:
		_preview_seconds += delta
		visual_tick = floori(_preview_seconds * 60.0)
	$FloorEffects.queue_redraw()
	$Overlay.queue_redraw()

## Connect only after Claude registers this scene's types/placements in core data.
func sync_snapshot(trial: Dictionary, flags: Array[StringName], tick: int) -> void:
	snapshot_driven = true
	$AuthoringCamera.enabled = false
	apply_state(trial, flags, tick)

func apply_state(trial: Dictionary, flags: Array[StringName], tick: int) -> void:
	visual_tick = tick
	var wanted: Dictionary = {
		"trial_altar": "hollow_trial_altar_lit" if trial.get("state", &"idle") == &"won" or flags.has(&"cleared_hollow_trial") else "hollow_trial_altar_dark",
		"trial_chest": "hollow_trial_chest_open" if flags.has(&"trial_chest_opened") or (not snapshot_driven and preview_chest_open) else "hollow_trial_chest_closed",
		"entry_roots": "root_hollow_barrier_closed" if bool(trial.get("sealed", false)) else "root_hollow_barrier_open"}
	var state_key: String = var_to_str(wanted)
	if state_key == _state_key:
		return
	_state_key = state_key
	for id: String in wanted:
		if _types.get(id, "") == wanted[id]:
			continue
		var old: Node2D = $Props.get_node(id) as Node2D
		var replacement: Node2D = load("res://presentation/props/%s.tscn" % wanted[id]).instantiate() as Node2D
		replacement.name = id
		replacement.position = old.position
		for key: StringName in old.get_meta_list():
			if key in [&"flip", &"when", &"on_type"]:
				replacement.set_meta(key, old.get_meta(key))
		$Props.remove_child(old)
		old.queue_free()
		$Props.add_child(replacement)
		_types[id] = wanted[id]
	_rebuild_records()

func _rebuild_records() -> void:
	prop_records.clear()
	var points: PackedVector4Array = []
	var colours: PackedVector3Array = []
	var cores: PackedVector3Array = []
	var owners: PackedStringArray = []
	for node: Node2D in $Props.get_children():
		node.use_parent_material = true
		var sprite: Sprite2D = node.get_node("Sprite") as Sprite2D
		sprite.use_parent_material = true
		var size: Vector2 = sprite.texture.get_size()
		var anchor: Vector2 = -sprite.offset
		var instance_id: int = node.get_instance_id()
		if _anchors.has(instance_id):
			var prior: Dictionary = _anchors[instance_id]
			anchor = prior["anchor"]
			if sprite.offset != prior["offset"]:
				anchor = Vector2(size.x + sprite.offset.x if prior["flip"] else -sprite.offset.x,-sprite.offset.y)
		var flipped: bool = bool(node.get_meta("flip", false))
		sprite.flip_h = flipped
		sprite.offset = Vector2(-(size.x-anchor.x) if flipped else -anchor.x, -anchor.y)
		_anchors[instance_id] = {"anchor":anchor,"offset":sprite.offset,"flip":flipped}
		# Existing barrier resources carry hidden precomputed masks. New props use their exact alpha silhouette below.
		for name: String in ["CastShadow", "CastShadowFlipped"]:
			var shadow: CanvasItem = node.get_node_or_null(name) as CanvasItem
			if shadow != null:
				shadow.visible = false
		prop_records.append({"id":String(node.name),"node":node,"at":node.position,"texture":sprite.texture,"flip":flipped,"anchor":anchor,"size":size,"solid":node.get_meta("solid", false)})
		for marker: Node in node.get_children():
			if not marker.has_meta("socket"):
				continue
			var socket: Dictionary = marker.get_meta("socket")
			var local_at: Vector2 = (marker as Node2D).position
			var at: Vector2 = node.position + Vector2(-local_at.x if flipped else local_at.x,local_at.y)
			points.append(Vector4(at.x,at.y,float(socket["halo_radius"]),float(socket["energy"])))
			points.append(Vector4(at.x,node.position.y+3.0,float(socket["pool_radius"]),-float(socket["pool_energy"])))
			var colour: Array = socket.get("colour",[.48,.94,.86])
			var core_colour: Array = socket.get("core_colour",[.8,1.,1.])
			for i: int in 2:
				colours.append(Vector3(colour[0],colour[1],colour[2]))
				cores.append(Vector3(core_colour[0],core_colour[1],core_colour[2]))
				owners.append(String(node.name))
	assert(points.size() <= Light.MAX_LIGHTS, "Trial light budget exceeded")
	lamps = {"points":points.duplicate(),"count":points.size(),"owners":owners}
	points.resize(Light.MAX_LIGHTS)
	colours.resize(Light.MAX_LIGHTS)
	cores.resize(Light.MAX_LIGHTS)
	var lighting: ShaderMaterial = Light.make_material(&"root_hollow_layered",Vector2(512,352))
	lighting.set_shader_parameter("mixed_lights",true)
	lighting.set_shader_parameter("lamp_count",lamps["count"])
	lighting.set_shader_parameter("lamps",points)
	lighting.set_shader_parameter("lamp_colours",colours)
	lighting.set_shader_parameter("lamp_core_colours",cores)
	material = lighting
	$FloorEffects.queue_redraw()

func draw_floor(canvas: Node2D) -> void:
	for record: Dictionary in prop_records:
		var at: Vector2 = record["at"]
		var anchor: Vector2 = record["anchor"]
		var size: Vector2 = record["size"]
		var frame: Dictionary = {"w":size.x,"h":size.y,"ax":anchor.x,"ay":anchor.y}
		var moon: Transform2D = Light.actor_transform(Vector2.ZERO,frame,bool(record["flip"]))
		canvas.draw_set_transform_matrix(Transform2D(0.0,at) * moon)
		canvas.draw_texture_rect(record["texture"],Rect2(Vector2.ZERO,size),false,Color(0,0,0,Light.PROP_SHADOW_ALPHA))
		var local: Dictionary = LocalShadows.plan(at,lamps["points"],int(lamps["count"]),record["id"],lamps["owners"])
		if not local.is_empty():
			canvas.draw_set_transform_matrix(Transform2D(local["x"],local["y"],local["at"]) * moon)
			canvas.draw_texture_rect(record["texture"],Rect2(Vector2.ZERO,size),false,Color(0,0,0,Light.PROP_SHADOW_ALPHA))
		canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
		# A small contact ellipse stays at the physical feet; no collision is added.
		if bool(record["solid"]):
			ActorShadow.draw(canvas,at,minf(20.0,size.x*.22),.22)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

## Fireflies stay outside the fight-floor rectangle; simulation tick can freeze them during gameplay pause.
func draw_motes(canvas: Node2D) -> void:
	if not is_node_ready():
		return
	var regions: Array[Rect2] = [Rect2(36,86,40,172),Rect2(436,86,40,172),Rect2(112,35,288,30),Rect2(128,294,256,20)]
	for i: int in 16:
		var region: Rect2 = regions[i%4]
		var home: Vector2 = region.position + Vector2(fmod(i*73.0,region.size.x-12.0)+6.0,fmod(i*41.0,region.size.y-12.0)+6.0)
		var time: float = float(visual_tick)/60.0
		var at: Vector2 = (home + Vector2(sin(time*.43+i)*4.0,cos(time*.31+i)*3.0)).round()
		var pulse: float = .5+.5*sin(time*1.4+i*2.4)
		if pulse>.2:
			canvas.draw_rect(Rect2(at,Vector2.ONE),Color(.72*pulse,.90*pulse,.76*pulse,.99))
