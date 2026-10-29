extends Area2D
## Paw flag. The first touch raises the red flag and makes this the respawn point.

const FLAG_ON := preload("res://assets/art/objects/flag_on.png")

var _active := false

func _on_body_entered(body: Node2D) -> void:
	if _active or not body.is_in_group("player"):
		return
	_active = true
	$Sprite.texture = FLAG_ON
	var base: Vector2 = $Sprite.scale
	var pop := create_tween()
	pop.tween_property($Sprite, "scale", base * 1.2, 0.1)
	pop.tween_property($Sprite, "scale", base, 0.2).set_trans(Tween.TRANS_BACK)
	Events.checkpoint_reached.emit(global_position)
