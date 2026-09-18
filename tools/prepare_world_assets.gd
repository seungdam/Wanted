extends SceneTree
## Stage A: normalize generated artwork without editing gameplay or scenes.
const OUT := "res://assets/world/ready/"
const Terrain = preload("res://scripts/terrain_tiles.gd")
const PALETTE: Array[Color] = [
	Color("405c42"), Color("587b50"), Color("759956"), Color("9dbb70"), Color("bed18c"),
	Color("654735"), Color("875739"), Color("b47d50"), Color("d49e69"),
	Color("d3ad7f"), Color("e8c796"), Color("f3dfb5"), Color("e9b957"), Color("d99a89"),
	Color("355b78"), Color("497c91"), Color("619eae"), Color("82bcc3"), Color("c0ddd3"),
	Color("686f69"), Color("868c83"), Color("aeb1a0"), Color("d5d2bb")
]

func _initialize() -> void:
	var source := Image.load_from_file("res://assets/world/source/village-atlas-pixel-v3.png")
	assert(source != null and source.get_size() == Vector2i(1536, 1024))
	var additions := Image.load_from_file("res://assets/world/source/terrain-expansion-v4.png")
	assert(additions != null and additions.get_size() == Vector2i(1536, 1024))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var base := Image.create(384, 32, false, Image.FORMAT_RGBA8)
	for kind in range(Terrain.CODES.length()):
		for x in range(64):
			for y in range(32):
				var diamond := absf((x + 0.5 - 32) / 32.0) + absf((y + 0.5 - 16) / 16.0)
				if diamond > 1.0:
					continue
				var sheet := source if kind < 3 else additions
				var source_y := 120 + y * 272 / 32 if kind < 3 else 384 + y * 256 / 32
				var color := sheet.get_pixel((kind % 3) * 512 + 16 + x * 480 / 64, source_y)
				# Common opaque perimeter eliminates generated padding and transparent seams.
				var weight := smoothstep(0.72, 0.96, diamond)
				if color.a < 0.9:
					weight = 1.0
				color = color.lerp(Terrain.BASE[kind], weight)
				color.a = 1.0
				base.set_pixel(kind * 64 + x, y, palette_color(color))
	var atlas := Terrain.make_variants(base)
	var normal := Image.create(atlas.get_width(), atlas.get_height(), false, Image.FORMAT_RGBA8)
	for x in range(atlas.get_width()):
		for y in range(atlas.get_height()):
			var pixel := atlas.get_pixel(x, y)
			var inside := absf((x % 64 + 0.5 - 32) / 32.0) + absf((y % 32 + 0.5 - 16) / 16.0) <= 1.0
			assert((pixel.a == 1.0) == inside)
			if inside:
				assert(pixel.is_equal_approx(palette_color(pixel)))
				normal.set_pixel(x, y, Color(0.5, 0.5, 1.0, 1.0))
	assert(atlas.save_png(OUT + "terrain.png") == OK)
	assert(normal.save_png(OUT + "terrain-normal.png") == OK)
	make_prop(source, Rect2i(0, 432, 512, 576), Vector2i(64, 72), "tree")
	make_prop(source, Rect2i(528, 672, 480, 352), Vector2i(48, 33), "rocks")
	make_prop(source, Rect2i(1040, 688, 480, 312), Vector2i(40, 24), "flowers")
	print("ASSET STAGE A PASS: 6 materials x 16 edge masks, exact 64x32 diamonds, palette, binary alpha, 3 cutout props")
	quit()

func make_prop(source: Image, region: Rect2i, size: Vector2i, id: String) -> void:
	var output := source.get_region(region)
	output.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	var opaque := 0
	for x in range(size.x):
		for y in range(size.y):
			var color := output.get_pixel(x, y)
			color.a = 1.0 if color.a >= 0.95 else 0.0
			opaque += int(color.a)
			output.set_pixel(x, y, palette_color(color))
	assert(opaque > size.x * size.y / 10 and opaque < size.x * size.y * 0.9)
	assert(output.save_png(OUT + id + ".png") == OK)

func palette_color(color: Color) -> Color:
	var nearest := PALETTE[0]
	var distance := INF
	for candidate in PALETTE:
		var delta := Vector3(color.r - candidate.r, color.g - candidate.g, color.b - candidate.b)
		if delta.length_squared() < distance:
			distance = delta.length_squared()
			nearest = candidate
	nearest.a = color.a
	return nearest
