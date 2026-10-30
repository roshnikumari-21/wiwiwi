extends Area2D
## Spikes: touching them costs a heart. Origin = bottom centre (sits on the ground).

func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is Player and body.can_be_hurt():
			Events.player_hurt.emit()
