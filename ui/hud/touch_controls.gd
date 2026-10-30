extends Control
## On-screen ◀ ▶ and paw-jump buttons. They press the same input actions as the keyboard.

@export var show_on_desktop: bool = false  ## tick to test with the mouse on PC
@export_range(0.3, 1.0) var opacity: float = 0.85
@export_range(0.6, 1.4) var size_scale: float = 1.0  ## set from the player's "controls_size" setting

const BUTTON_SCALE := 0.55  ## art is ~390 px; 0.55 ≈ 215 px at 1080p

func _ready() -> void:
	visible = show_on_desktop or OS.has_feature("mobile")
	modulate.a = opacity
	size_scale = float(SaveManager.get_setting("controls_size"))
	for button in find_children("*", "TouchScreenButton", true, false):
		button.scale = Vector2.ONE * BUTTON_SCALE * size_scale
