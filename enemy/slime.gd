extends CharacterBody2D

@export var speed: float = 60.0
# -1 = walking left, 1 = walking right.
var direction: int = -1

@onready var ledge_ray: RayCast2D = $LedgeRay

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	velocity.x = direction * speed
	move_and_slide()

	# Turn around at walls, or when the ray in front finds no floor (a ledge).
	if is_on_wall() or (is_on_floor() and not ledge_ray.is_colliding()):
		turn_around()

func turn_around() -> void:
	direction *= -1
	ledge_ray.position.x = 18 * direction  # move the "floor feeler" to the new front
	$Sprite2D.flip_h = direction > 0       # the art faces left, so flip when going right

# Something entered the Hitbox.
func _on_hitbox_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	# The cat's feet are about 30 px below its center.
	var cat_feet: float = body.global_position.y + 30
	# Falling down AND feet above the slime's middle = a stomp from above.
	if body.velocity.y > 0 and cat_feet < global_position.y:
		body.bounce()
		squish()
	else:
		body.die()

# Slimes don't like spikes: turn around when touching one.
func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("hazards"):
		turn_around()

func squish() -> void:
	# Stop moving and stop hurting, then flatten and disappear.
	set_physics_process(false)
	$Hitbox.set_deferred("monitoring", false)
	$CollisionShape2D.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property($Sprite2D, "scale", Vector2(1.4, 0.2), 0.12)
	tween.tween_property($Sprite2D, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
