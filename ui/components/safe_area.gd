class_name SafeArea
extends MarginContainer
## Fills the screen but keeps its children away from notches, rounded corners and system bars.
## Phones report the "safe" rectangle; on PC there is none, so debug_cutout can fake one for testing.

## Extra breathing room on every side (in 1080p base pixels).
@export var padding: int = 24
## PC only: pretend there is a notch this many base pixels wide on the left edge.
@export var debug_cutout: int = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_update_margins)
	_update_margins()

## Returns the unsafe border on each side, in base (viewport) pixels: left, top, right, bottom.
static func get_insets(viewport: Viewport) -> Array[float]:
	if not OS.has_feature("mobile"):
		return [0.0, 0.0, 0.0, 0.0]
	var safe := DisplayServer.get_display_safe_area()
	var window := Vector2(DisplayServer.window_get_size())
	# The game is drawn at 1920x1080-ish and scaled to the screen; convert screen pixels to game pixels.
	var to_game := viewport.get_visible_rect().size / window
	return [
		safe.position.x * to_game.x,
		safe.position.y * to_game.y,
		(window.x - safe.end.x) * to_game.x,
		(window.y - safe.end.y) * to_game.y,
	]

func _update_margins() -> void:
	var insets := get_insets(get_viewport())
	insets[0] = max(insets[0], debug_cutout)
	add_theme_constant_override("margin_left", int(insets[0]) + padding)
	add_theme_constant_override("margin_top", int(insets[1]) + padding)
	add_theme_constant_override("margin_right", int(insets[2]) + padding)
	add_theme_constant_override("margin_bottom", int(insets[3]) + padding)
