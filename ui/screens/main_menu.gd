extends Control
## Home page: the meadow drifts by, the kitten sits on the grass, a big Play button.
## Play opens the level map.

@onready var play: TextureButton = $UI/SafeArea/Play

func _ready() -> void:
	play.pressed.connect(_on_play)
	play.pivot_offset = play.size * 0.5
	var pulse := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	pulse.tween_property(play, "scale", Vector2(1.05, 1.05), 0.8)
	pulse.tween_property(play, "scale", Vector2.ONE, 0.8)
	play.grab_focus.call_deferred()

func _on_play() -> void:
	play.disabled = true   # one tap is enough
	SceneTransition.change_scene("res://ui/screens/level_map.tscn")
