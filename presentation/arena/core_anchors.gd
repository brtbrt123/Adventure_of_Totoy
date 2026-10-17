extends RefCounted
## Locate the largest bright connected patch in the torso, excluding hands/loose sparks.
## Returns a frame-local point; declared sprite anchors handle world placement.
static func measure(image: Image, frame: Dictionary, bright: Color) -> Vector2:
	var width: int = frame["w"]
	var height: int = frame["h"]
	var candidates: Dictionary = {}
	for y: int in range(floori(height * 0.12), ceili(height * 0.65)):
		for x: int in range(floori(width * 0.25), ceili(width * 0.75)):
			if image.get_pixel(frame["x"] + x, frame["y"] + y) == bright:
				candidates[Vector2i(x, y)] = true
	var best: Array[Vector2i] = []
	while not candidates.is_empty():
		var seed: Vector2i = candidates.keys()[0]
		var cluster: Array[Vector2i] = [seed]
		candidates.erase(seed)
		var cursor: int = 0
		while cursor < cluster.size():
			var pixel: Vector2i = cluster[cursor]
			cursor += 1
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next: Vector2i = pixel + step
				if candidates.has(next):
					candidates.erase(next)
					cluster.append(next)
		if cluster.size() > best.size():
			best = cluster
	if best.is_empty():
		return Vector2(float(frame.get("ax", width * 0.5)), roundf(height * 0.4))
	var total: Vector2 = Vector2.ZERO
	for pixel: Vector2i in best:
		total += Vector2(pixel)
	return (total / best.size()).round()
