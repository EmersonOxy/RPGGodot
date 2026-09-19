extends RefCounted
## Static pointer assets inspected in Cursors_v2. Other folders contain role-specific cursors.
const STYLES := [
	{"id": "default", "label": "Padrão", "texture": null, "hotspot": Vector2.ZERO},
	{"id": "light_1", "label": "Claro 1", "texture": preload("res://assets/Cursors_v2/Light/Arrows/Arrow1.png"), "hotspot": Vector2.ZERO},
	{"id": "light_2", "label": "Claro 2", "texture": preload("res://assets/Cursors_v2/Light/Arrows/Arrow2.png"), "hotspot": Vector2.ZERO},
	{"id": "light_3", "label": "Claro 3", "texture": preload("res://assets/Cursors_v2/Light/Arrows/Arrow3.png"), "hotspot": Vector2.ZERO},
	{"id": "light_4", "label": "Claro 4", "texture": preload("res://assets/Cursors_v2/Light/Arrows/Arrow4.png"), "hotspot": Vector2.ZERO},
	{"id": "dark_1", "label": "Escuro 1", "texture": preload("res://assets/Cursors_v2/Dark/Arrows/Arrow1.png"), "hotspot": Vector2.ZERO},
	{"id": "dark_2", "label": "Escuro 2", "texture": preload("res://assets/Cursors_v2/Dark/Arrows/Arrow2.png"), "hotspot": Vector2.ZERO},
	{"id": "dark_3", "label": "Escuro 3", "texture": preload("res://assets/Cursors_v2/Dark/Arrows/Arrow3.png"), "hotspot": Vector2.ZERO},
	{"id": "dark_4", "label": "Escuro 4", "texture": preload("res://assets/Cursors_v2/Dark/Arrows/Arrow4.png"), "hotspot": Vector2.ZERO},
]

static func index_for(style_id: String) -> int:
	for i in STYLES.size():
		if STYLES[i].id == style_id:
			return i
	return 0

static func apply(style_id: String, scale: float = 1.0) -> void:
	var style: Dictionary = STYLES[index_for(style_id)]
	if style.texture == null:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		return
	var factor: float = 0.5 * clampf(scale, 0.5, 2.0)
	var image: Image = style.texture.get_image()
	image.resize(maxi(1, roundi(image.get_width() * factor)), maxi(1, roundi(image.get_height() * factor)), Image.INTERPOLATE_NEAREST)
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(image), Input.CURSOR_ARROW, style.hotspot * factor)
