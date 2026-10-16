extends RefCounted
## Quilt the original 16px grass art with overlapping, irregular pixel seams.
## Every pixel comes unchanged from the imported tiles: no flattening or blur.
const PATCH: int = 16
const OVERLAP: int = 6
const STEP: int = PATCH - OVERLAP

static func build(atlas: Image, entries: Dictionary) -> Image:
	var patches: Array[Image] = []
	for n: int in range(1, 17):
		var entry: Dictionary = entries["grass_%d" % n]
		var patch: Image = atlas.get_region(Rect2i(entry["x"], entry["y"], PATCH, PATCH))
		patches.append(patch)
		var reflected: Image = patch.duplicate() as Image
		reflected.flip_x()
		patches.append(reflected)
	var ground: Image = Image.create(320, 176, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1908
	for y: int in range(0, ground.get_height(), STEP):
		for x: int in range(0, ground.get_width(), STEP):
			var at: Vector2i = Vector2i(x, y)
			var options: Array[int] = []
			var scores: Array[float] = []
			var minimum: float = INF
			for trial: int in range(12):
				var index: int = rng.randi_range(0, patches.size() - 1)
				var score: float = overlap_cost(ground, patches[index], at)
				options.append(index)
				scores.append(score)
				minimum = minf(minimum, score)
			# Random choice among similar matches avoids a repeating best-tile motif.
			var shortlist: Array[int] = []
			for trial: int in range(options.size()):
				if scores[trial] <= minimum * 1.25 + 0.03:
					shortlist.append(options[trial])
			var patch: Image = patches[shortlist[rng.randi_range(0, shortlist.size() - 1)]]
			var left: Array[int] = []
			var top: Array[int] = []
			if x > 0:
				left = cut(ground, patch, at, false)
			if y > 0:
				top = cut(ground, patch, at, true)
			for py: int in range(mini(PATCH, ground.get_height() - y)):
				for px: int in range(mini(PATCH, ground.get_width() - x)):
					if (not left.is_empty() and px < left[py]) or (not top.is_empty() and py < top[px]):
						continue
					ground.set_pixel(x + px, y + py, patch.get_pixel(px, py))
	return ground

static func error_at(ground: Image, patch: Image, at: Vector2i, x: int, y: int) -> float:
	if at.x + x >= ground.get_width() or at.y + y >= ground.get_height():
		return 0.0
	var a: Color = ground.get_pixel(at.x + x, at.y + y)
	if a.a == 0.0:
		return 0.0
	var b: Color = patch.get_pixel(x, y)
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length_squared()

static func overlap_cost(ground: Image, patch: Image, at: Vector2i) -> float:
	var score: float = 0.0
	for y: int in range(PATCH):
		for x: int in range(PATCH):
			if (at.x > 0 and x < OVERLAP) or (at.y > 0 and y < OVERLAP):
				score += error_at(ground, patch, at, x, y)
	return score

## Minimum-error connected cut through each overlap; boundary meanders with
## the painted texture rather than following a straight tile border.
static func cut(ground: Image, patch: Image, at: Vector2i, transpose: bool) -> Array[int]:
	var costs: Array[float] = []
	var previous: Array[int] = []
	costs.resize(PATCH * OVERLAP)
	previous.resize(PATCH * OVERLAP)
	for row: int in range(PATCH):
		for col: int in range(OVERLAP):
			var index: int = row * OVERLAP + col
			var best: float = INF
			var parent: int = col
			if row > 0:
				for candidate: int in range(maxi(0, col - 1), mini(OVERLAP, col + 2)):
					if costs[(row - 1) * OVERLAP + candidate] < best:
						best = costs[(row - 1) * OVERLAP + candidate]
						parent = candidate
			costs[index] = error_at(ground, patch, at, row if transpose else col, col if transpose else row) + (best if row > 0 else 0.0)
			previous[index] = parent
	var end: int = 0
	for col: int in range(1, OVERLAP):
		if costs[(PATCH - 1) * OVERLAP + col] < costs[(PATCH - 1) * OVERLAP + end]:
			end = col
	var seam: Array[int] = []
	seam.resize(PATCH)
	for row: int in range(PATCH - 1, -1, -1):
		seam[row] = end
		end = previous[row * OVERLAP + end]
	return seam
