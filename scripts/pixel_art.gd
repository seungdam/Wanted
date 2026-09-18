extends RefCounted
## Small, code-native pixel placeholder; replace Sprite2D.texture with final art.
static func resident(apron: Color) -> Texture2D:
	var image := Image.create(32, 44, false, Image.FORMAT_RGBA8)
	var brown := Color("ab7953")
	var dark := Color("563b2f")
	var cream := Color("f2d7a1")
	# Integer pixel masks give every resident the same warm animal silhouette.
	for x in range(32):
		for y in range(44):
			var p := Vector2(x, y)
			var color := Color.TRANSPARENT
			if Rect2(9, 37, 5, 6).has_point(p) or Rect2(19, 37, 5, 6).has_point(p):
				color = dark
			if Rect2(6, 25, 21, 13).has_point(p):
				color = brown
			if Rect2(10, 26, 13, 13).has_point(p):
				color = apron.darkened(0.15) if x > 19 else apron
			if Rect2(14, 30, 6, 4).has_point(p):
				color = cream
			if p.distance_to(Vector2(7, 7)) < 5 or p.distance_to(Vector2(25, 7)) < 5:
				color = dark
			if p.distance_to(Vector2(7, 7)) < 2.5 or p.distance_to(Vector2(25, 7)) < 2.5:
				color = Color("ce9380")
			if pow((x - 16.0) / 14.0, 2) + pow((y - 17.0) / 12.0, 2) < 1:
				color = brown if x < 23 else brown.darkened(0.12)
			if pow((x - 16.0) / 12.0, 2) + pow((y - 18.0) / 7.0, 2) < 1:
				color = dark
			if Rect2(8, 14, 5, 8).has_point(p) or Rect2(20, 14, 5, 8).has_point(p):
				color = cream
			if Rect2(10, 15, 3, 6).has_point(p) or Rect2(20, 15, 3, 6).has_point(p):
				color = Color("302a22")
			if Rect2(11, 23, 11, 3).has_point(p):
				color = cream
			if Rect2(15, 21, 3, 2).has_point(p):
				color = dark
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
