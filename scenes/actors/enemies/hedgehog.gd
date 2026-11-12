class_name Hedgehog
extends Slime
## World 3 enemy: walks back and forth like a slime, but its back is covered in spines, so it can't be
## stomped: landing on it hurts. Jump over it instead (its touch zone is small and low, so a normal
## jump clears it), or go around. When it hurts the cat it puffs up for a moment with a "!".

const HURT_SIZE := Vector2(84.0, 64.0)   ## touch zone (the art is ~124 x 104, spines included)
const ALERT := preload("res://assets/art/enemies/hedgehog/hog_alert.png")

var _cross_left := 0.0

func _physics_process(delta: float) -> void:
	_cross_left = maxf(_cross_left - delta, 0.0)
	if _cross_left > 0.0:   # puffed up: stands still
		velocity.x = 0.0
		velocity.y += GRAVITY * delta
		move_and_slide()
		return
	super(delta)

## Any touch hurts, from the side or from above: there's no stomping a hedgehog.
func _check_cat() -> void:
	for body in hitbox.get_overlapping_bodies():
		if not body is Player or body.frozen or not body.can_be_hurt():
			continue
		var at: Vector2 = body.global_position - global_position
		if absf(at.x) < HURT_SIZE.x * 0.5 + 30.0 and at.y > -HURT_SIZE.y - 10.0:
			Events.player_hurt.emit()
			_puff_up()
			return

func _puff_up() -> void:
	_cross_left = 1.0
	sprite.play("angry")
	var alert := Sprite2D.new()
	alert.texture = ALERT
	alert.position = Vector2(55.0 * (-1.0 if sprite.flip_h else 1.0), -95.0)
	add_child(alert)
	var t := alert.create_tween()
	t.tween_property(alert, "position:y", -115.0, 0.3).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.4)
	t.tween_property(alert, "modulate:a", 0.0, 0.3)
	t.tween_callback(alert.queue_free)
	await get_tree().create_timer(1.0).timeout
	if is_inside_tree():
		sprite.play("move")
