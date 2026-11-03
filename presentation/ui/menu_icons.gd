extends RefCounted
## Icons for the TAB menu's scenes: a sprite-sheet frame (art/build/sprites.png) as an AtlasTexture, optionally only a part of
## it (`crop`, in the frame's pixels: the inner 32x32 of a weapon medallion). Made once per frame and part, then reused.

static var _cache: Dictionary = {}


static func icon(atlas: Texture2D, frames: Dictionary, frame: String, crop: Rect2 = Rect2()) -> Texture2D:
	if atlas == null or frame.is_empty() or not frames.has(frame):
		return null
	var key: String = "%s|%s|%d" % [frame, str(crop), atlas.get_instance_id()]
	if not _cache.has(key):
		var f: Dictionary = frames[frame]
		var region: Rect2 = Rect2(float(f["x"]), float(f["y"]), float(f["w"]), float(f["h"]))
		if crop.size != Vector2.ZERO:
			region = Rect2(region.position + crop.position, crop.size)
		var texture: AtlasTexture = AtlasTexture.new()
		texture.atlas = atlas
		texture.region = region
		_cache[key] = texture
	return _cache[key]
