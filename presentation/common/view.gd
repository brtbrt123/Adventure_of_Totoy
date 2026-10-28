extends RefCounted
## The game's base view, in game pixels (decision 0005: 384x216, 20% more world than the old 320x180; integer scaling
## only, so a 1152x648 window is exactly 3x and 1536x864 is 4x). Every screen-space layout reads it from here.
const W: int = 384
const H: int = 216
const SIZE: Vector2 = Vector2(384.0, 216.0)
const CENTER: Vector2 = Vector2(192.0, 108.0)
