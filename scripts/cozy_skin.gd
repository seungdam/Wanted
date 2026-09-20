class_name CozySkin
extends RefCounted

const DIALOGUE := preload("res://assets/ui/skins/cozyland_dialogue.png")
const UI := preload("res://assets/ui/skins/cozyland_ui.png")

static func panel(kind := "dialogue") -> StyleBoxTexture:
	var skin := StyleBoxTexture.new()
	skin.texture = DIALOGUE
	# See UI_ASSET_MAP.md: this is the only standalone dialogue cell in the sheet.
	skin.region_rect = Rect2(16, 20, 48, 76)
	skin.set_texture_margin_all(7)
	skin.set_content_margin_all(24)
	if kind != "dialogue":
		skin.set_content_margin(SIDE_TOP, 74)
	skin.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	skin.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return skin

static func button(state := "normal") -> StyleBoxTexture:
	var skin := StyleBoxTexture.new()
	skin.texture = UI
	# The paired 48px cells are the only Ring button states taken from this sheet.
	skin.region_rect = Rect2(80, 16, 48, 48) if state == "normal" else Rect2(128, 16, 48, 48)
	skin.set_texture_margin_all(7)
	skin.set_content_margin_all(10)
	skin.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	skin.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return skin

static func theme() -> Theme:
	var value := Theme.new()
	value.default_font = preload("res://font/Moneygraphy-Pixel.ttf")
	for state in ["normal", "hover", "pressed", "disabled"]:
		value.set_stylebox(state, "Button", button("normal" if state == "normal" else "hover"))
		value.set_color("font_color" if state == "normal" else "font_hover_color" if state == "hover" else "font_pressed_color" if state == "pressed" else "font_disabled_color", "Button", Color("fffbed") if state != "disabled" else Color("7d6245"))
	return value
