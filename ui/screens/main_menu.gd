extends Control
## Home page: the meadow drifts by, the logo sways gently, the kitten sits on the grass, a big Play button.
## Play opens the level map.

@onready var play: TextureButton = $UI/SafeArea/Play
@onready var logo: TextureRect = $UI/SafeArea/Logo

func _ready() -> void:
	play.pressed.connect(_on_play)
	play.pivot_offset = play.size * 0.5
	var pulse := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	pulse.tween_property(play, "scale", Vector2(1.05, 1.05), 0.8)
	pulse.tween_property(play, "scale", Vector2.ONE, 0.8)
	play.grab_focus.call_deferred()
	logo.pivot_offset = Vector2(logo.custom_minimum_size.x * 0.5, logo.custom_minimum_size.y)
	var sway := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	sway.tween_property(logo, "rotation_degrees", 1.5, 1.6)
	sway.tween_property(logo, "rotation_degrees", -1.5, 1.6)

func _on_play() -> void:
	play.disabled = true   # one tap is enough
	SceneTransition.change_scene("res://ui/screens/level_map.tscn")
