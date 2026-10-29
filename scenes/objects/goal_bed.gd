extends Area2D
## The cat bed at the end of the level: reaching it finishes the level.

signal reached

var _done := false

func _on_body_entered(body: Node2D) -> void:
	if _done or not body.is_in_group("player"):
		return
	_done = true
	reached.emit()
