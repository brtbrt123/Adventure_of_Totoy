extends RefCounted
## Assemble quiet imported grass variants by edge similarity, once at startup.
## Shared border pixels are copied from neighbours, keeping hard opaque palette pixels.
const QUIET: Array[String] = ["grass_1", "grass_6", "grass_11", "grass_16"]

static func build(atlas: Image, entries: Dictionary, colors: Dictionary) -> Dictionary:
	var candidates: Array[Image] = []
	var regions: Array[Rect2] = []
	for key: String in QUIET:
		var entry: Dictionary = entries[key]
		var region: Rect2 = Rect2(entry["x"], entry["y"], 16, 16)
		regions.append(region)
		var original: Image = atlas.get_region(Rect2i(region))
		for flip: int in range(4):
			var image: Image = original.duplicate() as Image
			if flip % 2 == 1:
				image.flip_x()
			if flip >= 2:
				image.flip_y()
			candidates.append(image)
	var ground: Image = Image.create(320, 176, false, Image.FORMAT_RGBA8)
	var selected: Array[Rect2] = []
	for y: int in range(11):
		for x: int in range(20):
			var best: int = 0
			var best_score: float = INF
			for index: int in range(candidates.size()):
				var score: float = seam_cost(ground, candidates[index], x * 16, y * 16)
				# Deterministic tie break; no uncorrelated random tufts or flowers.
				score += float(posmod(index - x - y * 3, candidates.size())) * 0.00001
				if score < best_score:
					best_score = score
					best = index
			ground.blit_rect(candidates[best], Rect2i(0, 0, 16, 16), Vector2i(x * 16, y * 16))
			for pixel: int in range(16):
				if y > 0:
					ground.set_pixel(x * 16 + pixel, y * 16, ground.get_pixel(x * 16 + pixel, y * 16 - 1))
				if x > 0:
					ground.set_pixel(x * 16, y * 16 + pixel, ground.get_pixel(x * 16 - 1, y * 16 + pixel))
			selected.append(regions[best / 4])
	# Keep the floor in two neighbouring grass colours so actors and warnings
	# read above it. This is a presentation tint; source art remains unchanged.
	for y: int in range(ground.get_height()):
		for x: int in range(ground.get_width()):
			var pixel: Color = ground.get_pixel(x, y)
			ground.set_pixel(x, y, colors["5"] if pixel.g > 0.48 else colors["4"])
	return {"image": ground, "regions": selected}

static func seam_cost(ground: Image, candidate: Image, x: int, y: int) -> float:
	var score: float = 0.0
	for pixel: int in range(16):
		if x > 0:
			score += distance(ground.get_pixel(x - 1, y + pixel), candidate.get_pixel(0, pixel))
		if y > 0:
			score += distance(ground.get_pixel(x + pixel, y - 1), candidate.get_pixel(pixel, 0))
	return score

static func distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length_squared()
