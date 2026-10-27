extends CanvasLayer
## Fades the screen to a soft color, swaps the scene, and fades back in.

const FADE_TIME := 0.25

@onready var _cover: ColorRect = $Cover

func _ready() -> void:
	_cover.modulate.a = 0.0
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE

func change_scene(path: String) -> void:
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP  # block taps while fading
	var out := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	out.tween_property(_cover, "modulate:a", 1.0, FADE_TIME)
	await out.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame  # let the new scene appear behind the cover
	var back := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	back.tween_property(_cover, "modulate:a", 0.0, FADE_TIME)
	await back.finished
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
