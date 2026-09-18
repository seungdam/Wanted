extends RefCounted
## Atlas columns are materials; rows are four-edge bitmasks (left, up, right, down).
enum Kind { GRASS, STONE, WATER, DIRT, SHALLOW, DEEP }
const CODES := "GPWRSD"
const SIZE := Vector2i(64, 32)
const DIRECTIONS := [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]
const BASE: Array[Color] = [Color("759956"), Color("e8c796"), Color("619eae"), Color("e8c796"), Color("82bcc3"), Color("355b78")]

static func water_depth(kind: int) -> int:
	return {Kind.SHALLOW: 1, Kind.WATER: 2, Kind.DEEP: 3}.get(kind, 0)

static func edge_mask(kind: int, neighbors: Array[int]) -> int:
	var mask := 0
	for side in range(4):
		var neighbor := neighbors[side]
		var boundary := neighbor != kind
		if water_depth(kind) > 0 and water_depth(neighbor) > 0:
			boundary = water_depth(neighbor) < water_depth(kind)
		if boundary:
			mask |= 1 << side
	return mask

static func make_variants(base: Image) -> Image:
	assert(base.get_size() == Vector2i(SIZE.x * CODES.length(), SIZE.y))
	var atlas := Image.create(base.get_width(), SIZE.y * 16, false, Image.FORMAT_RGBA8)
	for kind in range(CODES.length()):
		for mask in range(16):
			for x in range(SIZE.x):
				for y in range(SIZE.y):
					var color := base.get_pixel(kind * SIZE.x + x, y)
					if color.a == 0.0:
						continue
					# Inverse 2:1 projection keeps all edge/corner combinations on the same pixel grid.
					var u := (x + 0.5 - 32.0) * 0.5 + y + 0.5 - 16.0
					var v := -(x + 0.5 - 32.0) * 0.5 + y + 0.5 - 16.0
					var distances := [u + 16.0, v + 16.0, 16.0 - u, 16.0 - v]
					var edge := INF
					for side in range(4):
						if mask & (1 << side):
							edge = minf(edge, distances[side])
					if edge < 3.0:
						color = edge_color(kind, edge)
					atlas.set_pixel(kind * SIZE.x + x, mask * SIZE.y + y, color)
	return atlas

static func edge_color(kind: int, distance: float) -> Color:
	match kind:
		Kind.GRASS:
			return Color("587b50") if distance < 1.0 else Color("9dbb70")
		Kind.STONE, Kind.DIRT:
			return Color("b47d50") if distance < 1.0 else Color("d3ad7f")
		Kind.SHALLOW:
			return Color("d3ad7f") if distance < 1.0 else (Color("c0ddd3") if distance < 2.0 else Color("82bcc3"))
		Kind.WATER:
			return Color("82bcc3") if distance < 2.0 else Color("619eae")
		Kind.DEEP:
			return Color("619eae") if distance < 1.5 else Color("497c91")
	return BASE[kind]
