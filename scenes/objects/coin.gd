extends Area2D
## A paw coin. Spins; when the cat touches it, it floats up, fades and announces itself.

var _taken := false

func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	Events.coin_collected.emit()
	set_deferred("monitoring", false)
	var t := create_tween().set_parallel()
	t.tween_property(self, "position:y", position.y - 60.0, 0.25).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.chain().tween_callback(queue_free)
