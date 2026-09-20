class_name RingAction
extends Button

func configure(value: String, icon_texture: Texture2D) -> void:
	($Layout/Caption as Label).text = value
	($Layout/Icon as TextureRect).texture = icon_texture
