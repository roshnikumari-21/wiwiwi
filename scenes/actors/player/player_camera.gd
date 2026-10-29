class_name PlayerCamera
extends Camera2D
## Follows the cat smoothly and looks a little ahead in the running direction.

@export var look_ahead: float = 240.0
@export var look_ahead_speed: float = 3.0

func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody2D
	if body == null:
		return
	var target := 0.0
	if abs(body.velocity.x) > 50.0:
		target = sign(body.velocity.x) * look_ahead
	offset.x = lerp(offset.x, target, clamp(look_ahead_speed * delta, 0.0, 1.0))
