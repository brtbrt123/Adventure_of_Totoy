@tool
extends Resource
## The sizes, durations and counts of the creature effects drawn by code (shapes, not frames), editable in the Inspector
## (owner 2026-11-01: "make the rest editable"): open presentation/effects/fx_settings.tres. Read once when the game starts
## (presentation/explore/warden_effects.gd, creature_effects.gd); these values are the defaults when the file is missing.
## Distances are game pixels, times ticks (60 a second).

const PATH: String = "res://presentation/effects/fx_settings.tres"

@export_group("Runebound Warden")
@export_range(0.0, 120.0, 1.0) var warden_shadow_radius: float = 40.0  ## the stance shadow (an ellipse about 0.65 x this wide)
@export_range(0.0, 1.0, 0.01) var warden_foot_shadow_alpha: float = 0.38  ## the darker shadow right under each foot
@export_range(-30.0, 30.0, 1.0) var warden_footfall_lead: float = 10.0  ## where the leading foot lands (px ahead of the feet)
@export_range(-30.0, 30.0, 1.0) var warden_footfall_trail: float = -2.0  ## where the trailing foot lands
@export_range(0, 600) var warden_print_ticks: int = 90  ## how long a footprint stays
@export_range(0, 600) var warden_scar_ticks: int = 70  ## how long the torn ground after a strike stays
@export_range(1, 12) var warden_lash_clumps: int = 5  ## root clumps along the Lash's line

@export_group("Thornback Stag")
@export_range(1, 120) var slam_ticks: int = 26  ## how long the slam's ground effects last after the hit
@export_range(1, 60) var slam_front_ticks: int = 8  ## how long the shock front takes to reach the real edge
@export_range(0, 16) var slam_cracks: int = 5  ## cracks from the hoof to the front
@export_range(1, 120) var slam_rim_until: int = 20  ## the hit edge stays marked until this tick after the hit
@export_range(1, 600) var heal_pulse_every: int = 60  ## the heal pulse shows at most this often while the moths heal it
@export_range(1, 120) var mist_every: int = 20  ## a mote of healing mist this often while it regenerates

@export_group("All creatures")
@export_range(8, 400) var max_bursts: int = 96  ## particle bursts alive at once (the oldest go first)


static var _current: Resource = null


## The settings in use: the owner's file, or these defaults.
static func current() -> Resource:
	if _current == null:
		_current = load(PATH) if ResourceLoader.exists(PATH) else load("res://presentation/effects/fx_settings.gd").new()
	return _current
