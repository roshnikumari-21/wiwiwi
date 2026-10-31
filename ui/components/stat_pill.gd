class_name StatPill
extends PanelContainer
## A small wooden pill with an icon and a number, e.g. the stars / yarns / coins on the home page.

const PILL := preload("res://assets/art/ui/menu/pill_brown_normal.png")
const END_MARGIN := 50.0   ## the pill art's rounded ends (not stretched)

var _label := Label.new()

func _init(icon: Texture2D) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxTexture.new()
	box.texture = PILL
	box.texture_margin_left = END_MARGIN
	box.texture_margin_right = END_MARGIN
	box.content_margin_left = 22.0
	box.content_margin_right = 34.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 10.0
	add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var pic := TextureRect.new()
	pic.texture = icon
	pic.custom_minimum_size = Vector2(62, 62)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(pic)
	_label.add_theme_font_size_override("font_size", 44)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color(0.36, 0.25, 0.2))
	_label.add_theme_constant_override("outline_size", 12)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_label)

func set_text(text: String) -> void:
	_label.text = text

## Grow-and-settle bounce, e.g. when the number changes.
func pop() -> void:
	pivot_offset = size * 0.5
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.15, 1.15), 0.1)
	t.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
