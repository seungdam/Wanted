class_name ResidentPortrait
extends PanelContainer

const PORTRAIT_TEXTURES := {
	"rivet": preload("res://assets/ui/portraits/portrait_rivet_256.png"),
	"pin": preload("res://assets/ui/portraits/portrait_pin_256.png"),
	"nut": preload("res://assets/ui/portraits/portrait_nut_256.png"),
	"clip": preload("res://assets/ui/portraits/portrait_clip_256.png"),
	"screw": preload("res://assets/ui/portraits/portrait_screw_256.png"),
}

@export var resident_id := "rivet":
	set(value):
		resident_id = value
		if is_node_ready():
			_apply_portrait()

var sprite: Sprite2D

func _ready() -> void:
	clip_contents = true
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("bce4e7")
	frame.border_color = Color("527a35")
	frame.set_border_width_all(4)
	frame.set_corner_radius_all(20)
	frame.shadow_color = Color(0.21, 0.16, 0.1, 0.25)
	frame.shadow_size = 3
	frame.shadow_offset = Vector2(0, 2)
	add_theme_stylebox_override("panel", frame)
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	add_child(sprite)
	resized.connect(_layout_sprite)
	_apply_portrait()

func _apply_portrait() -> void:
	if sprite == null:
		return
	sprite.texture = PORTRAIT_TEXTURES.get(resident_id, PORTRAIT_TEXTURES["rivet"])
	_layout_sprite()

func _layout_sprite() -> void:
	if sprite == null:
		return
	var frame_size := sprite.texture.get_size()
	var available := size - Vector2(12.0, 12.0)
	var scale_ratio := minf(available.x / frame_size.x, available.y / frame_size.y)
	sprite.position = size * 0.5
	sprite.scale = Vector2.ONE * scale_ratio
