@tool
extends Resource
## How an explore scene looks on screen (owner 2026-11-01: "add shaders so the scene looks good"): a colour grade, a vignette, a glow on
## bright things, drifting ground mist and wind in the plants. One per scene, presentation/effects/looks/<scene id>.tres
## (village_layered, forest_layered, glade_layered, woodland_layered, root_hollow_layered, hollow_trial_layered), every value editable in
## the Inspector; a scene without a file uses these defaults. Read when the scene is entered (presentation/explore/explore_scene.gd);
## the shaders are presentation/effects/scene_post.gdshader (grade, vignette, glow) and presentation/common/overhead_light.gdshader
## (the mist pass). Nothing here touches the game state. Distances are game pixels.

const DIR: String = "res://presentation/effects/looks/"

@export_group("Colour grade")
@export var grade_enabled: bool = true
@export_range(0.5, 1.5, 0.01) var exposure: float = 1.04  ## overall brightness
@export_range(0.5, 1.5, 0.01) var contrast: float = 1.08  ## darker darks and brighter lights
@export_range(0.0, 2.0, 0.01) var saturation: float = 1.06  ## colour strength
@export var shadow_tint: Color = Color(0.9, 0.95, 1.1)  ## multiplies the dark tones (cool night)
@export var highlight_tint: Color = Color(1.06, 1.0, 0.92)  ## multiplies the light tones (warm lamp light)

@export_group("Vignette")
@export var vignette_enabled: bool = true
@export_range(0.0, 1.0, 0.01) var vignette_strength: float = 0.42  ## how dark the screen edges get
@export_range(0.3, 1.5, 0.01) var vignette_radius: float = 0.95  ## where it is fully dark (1.0 = the corners, 0.7 = the middle of the edges)
@export_range(0.05, 1.0, 0.01) var vignette_softness: float = 0.6  ## how far in it starts fading in
@export var vignette_colour: Color = Color(0.03, 0.03, 0.07)

@export_group("Glow")
@export var glow_enabled: bool = true
@export_range(0.0, 2.0, 0.01) var glow_strength: float = 0.55  ## how much light bright things spill
@export_range(0.3, 1.0, 0.01) var glow_threshold: float = 0.62  ## how bright a pixel must be to glow
@export_range(1.0, 16.0, 0.5) var glow_radius: float = 5.0  ## how far the glow reaches (game px)
@export var glow_tint: Color = Color(1.0, 1.0, 1.0)

@export_group("Ground mist")
@export var mist_enabled: bool = true
@export_range(0.0, 1.0, 0.01) var mist_density: float = 0.13  ## how thick it is on the open floor
@export_range(1.0, 5.0, 0.1) var mist_edge_boost: float = 2.0  ## how much thicker it is at the forest edge
@export_range(8.0, 120.0, 1.0) var mist_edge_width: float = 56.0  ## how far in from the edge it thickens (px)
@export_range(8.0, 200.0, 1.0) var mist_scale: float = 54.0  ## the size of its clouds (px)
@export_range(0.0, 30.0, 0.5) var mist_speed: float = 6.0  ## how fast it drifts (px a second)
@export var mist_colour: Color = Color(0.44, 0.48, 0.52)  ## kept dim and near grey: a bright or blue mist would wash the floor out

@export_group("Wind in the plants")
@export var wind_enabled: bool = true
@export_range(0.0, 6.0, 0.5) var wind_sway: float = 1.0  ## how far the tops of bushes, ferns and trees lean (whole px)
@export_range(0.0, 4.0, 0.05) var wind_speed: float = 0.9  ## sways a second
@export_range(0.0, 1.0, 0.05) var wind_gusts: float = 0.5  ## how much the strength rises and falls


## The scene's look: its file, or these defaults.
static func for_scene(scene_id: StringName) -> Resource:
	var path: String = DIR + String(scene_id) + ".tres"
	return load(path) if ResourceLoader.exists(path) else load("res://presentation/effects/scene_look.gd").new()
