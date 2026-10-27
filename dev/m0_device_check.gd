extends Control
## M0 test screen: shows what the phone reports (sizes, safe area, orientation, FPS) and tests touch + fades.
## Pink border = unsafe area (notch/system bars). White panel = SafeArea. Delete the dev/ folder before release.

@onready var _info: Label = %Info
@onready var _touch: Label = %Touch
var _fingers := {}

func _ready() -> void:
	%Heading.text = "%s — %s" % [tr("APP_TITLE"), tr("DEV_HEADING")]
	%FadeButton.text = tr("DEV_FADE_TEST")
	_touch.text = tr("DEV_TAP_HINT")
	%FadeButton.pressed.connect(func(): SceneTransition.change_scene(scene_file_path))
	var timer := Timer.new()
	timer.wait_time = 0.25
	timer.autostart = true
	timer.timeout.connect(_refresh)
	add_child(timer)
	_refresh()

func _refresh() -> void:
	var insets := SafeArea.get_insets(get_viewport())
	_info.text = "\n".join([
		"FPS: %d" % Engine.get_frames_per_second(),
		"Game (viewport) size: %s" % get_viewport_rect().size,
		"Window size: %s   Screen size: %s" % [DisplayServer.window_get_size(), DisplayServer.screen_get_size()],
		"Safe area (screen px): %s" % DisplayServer.get_display_safe_area(),
		"Unsafe border L/T/R/B (game px): %d / %d / %d / %d" % [insets[0], insets[1], insets[2], insets[3]],
		"Orientation: %s" % ["landscape", "portrait", "reverse landscape", "reverse portrait", "sensor landscape", "sensor portrait", "sensor"][DisplayServer.screen_get_orientation()],
		"Device: %s · %s %s" % [OS.get_model_name(), OS.get_name(), OS.get_version()],
		"GPU: %s" % RenderingServer.get_video_adapter_name(),
		"Godot %s" % Engine.get_version_info().string,
	])

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_fingers[event.index] = event.position
		else:
			_fingers.erase(event.index)
		_touch.text = "Fingers down: %d   Last touch: %s" % [_fingers.size(), event.position.round()]
