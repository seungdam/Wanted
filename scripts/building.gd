extends Node2D
## Single-cell footprint. Sprite origin sits at the footprint center, at ground level.
@export var texture: Texture2D
@export var normal_texture: Texture2D
@export var sprite_offset := Vector2(0, -30)
@export var tint := Color("c5a578")
@export var height: float = 44.0

func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	if texture == null:
		sprite.texture = make_placeholder()
		sprite.position = Vector2(0, -(height + 28) / 2.0)
	else:
		var canvas := CanvasTexture.new()
		canvas.diffuse_texture = texture
		canvas.normal_texture = normal_texture
		sprite.texture = canvas if normal_texture != null else texture
		sprite.position = sprite_offset
	add_child(sprite)

func make_placeholder() -> CanvasTexture:
	# Rasterize native polygons once; each face has a real tangent-space normal.
	var image := Image.create(64, int(height) + 28, false, Image.FORMAT_RGBA8)
	var normals := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	normals.fill(Color(0.5, 0.5, 1.0))
	var top := Vector2(0, -height)
	var left := Vector2(-28, -14)
	var right := Vector2(28, -14)
	var back := Vector2(0, -28)
	var faces := [PackedVector2Array([left, Vector2.ZERO, top, left + top]), PackedVector2Array([Vector2.ZERO, right, right + top, top]), PackedVector2Array([top, right + top, back + top, left + top])]
	var face_normals := [Vector3(-0.8, -0.4, 0.45).normalized(), Vector3(0.8, -0.4, 0.45).normalized(), Vector3(0, 0.6, 0.8)]
	for x in range(image.get_width()):
		for y in range(image.get_height()):
			var point := Vector2(x + 0.5 - 32, y + 0.5 - height - 28)
			for face in range(3):
				if Geometry2D.is_point_in_polygon(point, faces[face]):
					var color := tint
					if Rect2(6, -height + 8, 9, 13).has_point(point):
						color = Color("435966")
					if Rect2(-12, -20, 9, 16).has_point(point):
						color = Color("665143")
					image.set_pixel(x, y, color)
					var normal: Vector3 = face_normals[face]
					normals.set_pixel(x, y, Color(normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, normal.z * 0.5 + 0.5))
	var canvas := CanvasTexture.new()
	canvas.diffuse_texture = ImageTexture.create_from_image(image)
	canvas.normal_texture = ImageTexture.create_from_image(normals)
	return canvas
