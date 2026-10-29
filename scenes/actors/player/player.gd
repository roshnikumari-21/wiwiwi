class_name Player
extends CharacterBody2D
## The kitten. Origin = between the feet. Movement numbers are @export so they can be tuned in the Inspector.

@export_group("Run")
@export var run_speed: float = 520.0
@export var acceleration: float = 6500.0
@export var deceleration: float = 8000.0
@export var air_control: float = 0.8   ## 1.0 = same grip in the air as on the ground

@export_group("Jump")
@export var jump_height: float = 300.0     ## pixels, for a full (held) jump
@export var time_to_apex: float = 0.42     ## seconds from take-off to the top
@export var fall_gravity_scale: float = 1.5  ## falling is faster than rising: feels snappier
@export var jump_cut: float = 0.45         ## releasing jump early keeps this share of the upward speed
@export var max_fall_speed: float = 1500.0
@export var coyote_time: float = 0.12      ## can still jump this long after walking off a ledge
@export var jump_buffer: float = 0.12      ## a jump pressed this long before landing still counts

@onready var sprite: AnimatedSprite2D = $Sprite

var _coyote_left := 0.0
var _buffer_left := 0.0
var _was_on_floor := true
var _fall_peak_speed := 0.0
var _squash: Tween
var _base_scale: Vector2

# Physics derived from height + time, so designers tune in "pixels" and "seconds".
var _jump_speed: float
var _rise_gravity: float

func _ready() -> void:
	_base_scale = sprite.scale
	_rise_gravity = 2.0 * jump_height / (time_to_apex * time_to_apex)
	_jump_speed = -2.0 * jump_height / time_to_apex

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_jump(delta)
	_handle_run(delta)
	move_and_slide()
	_after_move()
	_update_animation()

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var g := _rise_gravity * (fall_gravity_scale if velocity.y > 0.0 else 1.0)
	velocity.y = min(velocity.y + g * delta, max_fall_speed)

func _handle_jump(delta: float) -> void:
	_coyote_left = coyote_time if is_on_floor() else max(_coyote_left - delta, 0.0)
	_buffer_left = jump_buffer if Input.is_action_just_pressed("jump") else max(_buffer_left - delta, 0.0)

	if _buffer_left > 0.0 and _coyote_left > 0.0:
		velocity.y = _jump_speed
		_buffer_left = 0.0
		_coyote_left = 0.0
		_do_squash(Vector2(0.85, 1.15))

	# Variable height: letting go of jump while rising cuts the jump short.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut

func _handle_run(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var grip := 1.0 if is_on_floor() else air_control
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * run_speed, acceleration * grip * delta)
		sprite.flip_h = direction < 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * grip * delta)

func _after_move() -> void:
	if not is_on_floor():
		_fall_peak_speed = max(_fall_peak_speed, velocity.y)
	elif not _was_on_floor:
		if _fall_peak_speed > 500.0:
			_do_squash(Vector2(1.18, 0.82))
			sprite.play("land")
		_fall_peak_speed = 0.0
	_was_on_floor = is_on_floor()

func _update_animation() -> void:
	if not is_on_floor():
		sprite.play("jump" if velocity.y < 0.0 else "fall")
	elif sprite.animation == "land" and sprite.is_playing() and abs(velocity.x) < 60.0:
		return  # let the landing finish unless the player starts running
	elif abs(velocity.x) > 20.0:
		sprite.play("walk")
	else:
		sprite.play("idle")

func _do_squash(amount: Vector2) -> void:
	if _squash:
		_squash.kill()
	_squash = create_tween()
	_squash.tween_property(sprite, "scale", _base_scale * amount, 0.07)
	_squash.tween_property(sprite, "scale", _base_scale, 0.14)
