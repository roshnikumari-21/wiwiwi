extends Area2D
## A paw coin. Spins; when the cat touches it, it flips into a burst of sparkles and announces itself.

var _taken := false

func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	Events.coin_collected.emit()
	AudioManager.play_coin()
	Fx.spawn(self, &"coin", global_position, 0.5)
	queue_free()
