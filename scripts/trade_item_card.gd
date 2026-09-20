class_name TradeItemCard
extends PanelContainer

var item := "wood"

func _get_drag_data(_at_position: Vector2):
	if GuestSession.item_count(item) < 1:
		return null
	var preview := Label.new()
	preview.text = "나무"
	preview.add_theme_font_override("font", preload("res://font/Moneygraphy-Pixel.ttf"))
	preview.add_theme_font_size_override("font_size", 18)
	preview.modulate.a = 0.8
	set_drag_preview(preview)
	return {"item": item}
