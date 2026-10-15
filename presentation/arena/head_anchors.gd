extends RefCounted
## Frame-local head points, measured once from the opaque upper central silhouette.
## Ignore narrow side runs (raised fists); the broad crown is the first head row.
static func measure(image: Image, frame: Dictionary) -> Vector2:
	var width: int = int(frame["w"])
	var height: int = int(frame["h"])
	var left: int = floori(width * 0.29)
	var right: int = ceili(width * 0.81)
	var minimum: int = maxi(3, floori(width * 0.18))
	for y: int in range(height):
		var start: int = -1
		var best_start: int = -1
		var best_length: int = 0
		for x: int in range(left, right + 1):
			var opaque: bool = x < right and image.get_pixel(int(frame["x"]) + x, int(frame["y"]) + y).a > 0.0
			if opaque and start < 0:
				start = x
			if not opaque and start >= 0:
				if x - start > best_length:
					best_start = start
					best_length = x - start
				start = -1
		if best_length >= minimum:
			return Vector2(best_start + (best_length - 1) * 0.5, y)
	return Vector2((width - 1) * 0.5, height * 0.25)

static func world(at: Vector2, frame: Dictionary, head: Vector2, mirrored: bool) -> Vector2:
	var width: float = float(frame["w"])
	var height: float = float(frame["h"])
	var pixel: Vector2 = head
	if mirrored:
		pixel.x = width - 1.0 - pixel.x
	return at.round() - Vector2(width * 0.5, height - 4.0) + pixel
