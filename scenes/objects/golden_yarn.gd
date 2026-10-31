extends Area2D
## The level's hidden Golden Yarn (the ★★★ star). Bobs gently; announces itself when found.

var _taken := false

func _ready() -> void:
	var bob := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	bob.tween_property($Sprite, "position:y", -10.0, 0.9)
	bob.tween_property($Sprite, "position:y", 0.0, 0.9)

func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	Events.yarn_collected.emit()
	AudioManager.play_sfx("sfx_yarn")
	set_deferred("monitoring", false)
	var t := create_tween().set_parallel()
	t.tween_property(self, "scale", Vector2(1.6, 1.6), 0.35).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "modulate:a", 0.0, 0.35)
	t.chain().tween_callback(queue_free)
