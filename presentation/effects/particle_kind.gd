@tool
extends Resource
## A particle burst kind (slam, roots, stomp, heal, ...): presentation/effects/particles/<kind>.tres, its layers editable in the
## Inspector (owner 2026-11-01). Where the particles start and which way they head stays per kind in creature_particles.gd (_spawn).

@export var layers: Array[Resource] = []  ## each a presentation/effects/particle_layer.gd
