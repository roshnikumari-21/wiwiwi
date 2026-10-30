@tool
class_name PillButton
extends Button
## Rounded glossy button from the UI kit (green / yellow / red / brown), with an optional icon.
## The pill art stretches only in its straight middle, so any width keeps round ends.

@export_enum("green", "yellow", "red", "brown") var colour: String = "green":
	set(value):
		colour = value
		_restyle()
@export_enum("none", "play", "replay", "home", "next", "settings", "pause") var symbol: String = "none":
	set(value):
		symbol = value
		_restyle()

const END_MARGIN := 50.0   ## px of each rounded end in the pill art (not stretched)

func _ready() -> void:
	_restyle()

func _restyle() -> void:
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())   # no focus ring; the art is enough
	for state in ["normal", "hover", "pressed", "disabled"]:
		var art: String = "normal" if state == "hover" else state
		var box := StyleBoxTexture.new()
		box.texture = load("res://assets/art/ui/menu/pill_%s_%s.png" % [colour, art])
		box.texture_margin_left = END_MARGIN
		box.texture_margin_right = END_MARGIN
		box.content_margin_left = 40
		box.content_margin_right = 40
		box.content_margin_top = 8
		box.content_margin_bottom = 14
		add_theme_stylebox_override(state, box)
	icon = load("res://assets/art/ui/menu/icon_%s.png" % symbol) if symbol != "none" else null
	expand_icon = true
	add_theme_constant_override("icon_max_width", 64)
	add_theme_constant_override("h_separation", 18)
	add_theme_font_size_override("font_size", 50)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		add_theme_color_override(c, Color.WHITE)
	add_theme_color_override("font_outline_color", Color(0.36, 0.2, 0.1))
	add_theme_constant_override("outline_size", 14)
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(0, 118)
