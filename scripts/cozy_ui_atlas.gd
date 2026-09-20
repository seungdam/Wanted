class_name CozyUIAtlas
extends RefCounted

const SLOT_EMPTY := preload("res://assets/ui/cozy_source/slot_defualt.png")
const SLOT_HOVER := preload("res://assets/ui/cozy_source/slot_selected.png")

static func slot_style(selected: bool = false) -> StyleBoxTexture:

	var style := StyleBoxTexture.new()
	style.texture = SLOT_HOVER if selected else SLOT_EMPTY
	style.texture_margin_left = 24.0
	style.texture_margin_top = 24.0
	style.texture_margin_right = 24.0
	style.texture_margin_bottom = 24.0
	style.content_margin_left = 6.0
	style.content_margin_top = 6.0
	style.content_margin_right = 6.0
	style.content_margin_bottom = 6.0
	return style
