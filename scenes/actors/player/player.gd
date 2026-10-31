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

@export_group("Hurt")
@export var safe_time: float = 1.2         ## after a respawn, hazards can't hurt her for this long
@export var stomp_bounce: float = 0.7      ## bounce off a stomped enemy, as a share of a full jump

@export_group("Energy")
@export var energy_seconds: float = 35.0   ## seconds of moving on a full tank
@export var tired_speed: float = 0.65      ## share of run speed left when energy is empty (never a fail)

@export_group("Idle")
@export var breath_amount: float = 0.012   ## how much she rises when breathing (1.2 %)
@export var breath_period: float = 2.6     ## seconds per breath

@onready var sprite: AnimatedSprite2D = $Sprite

var _breath_time := 0.0
var energy := 1.0 : set = set_energy   ## 0..1; drains while moving, milk refills it
var frozen := false     ## true when the level is over: no input, gravity only
var _safe_left := 0.0   ## seconds of "can't be hurt" left
var _walk_target := NAN ## while frozen, the game can walk her to this x (e.g. into the girl's arms)

signal arrived          ## reached the walk_to() target

var _in_jump := false   ## true from take-off until touchdown: keeps the leap pose for the whole arc
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

func _process(delta: float) -> void:
	_breathe(delta)

func _physics_process(delta: float) -> void:
	_safe_left = max(_safe_left - delta, 0.0)
	_apply_gravity(delta)
	if frozen:
		_auto_walk(delta)
	else:
		_handle_jump(delta)
		_handle_run(delta)
	move_and_slide()
	_after_move()
	_use_energy(delta)
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
		_in_jump = true
		AudioManager.play_sfx("sfx_jump")
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
		velocity.x = move_toward(velocity.x, direction * run_speed * _speed_factor(), acceleration * grip * delta)
		sprite.flip_h = direction < 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * grip * delta)

func _after_move() -> void:
	if not is_on_floor():
		_fall_peak_speed = max(_fall_peak_speed, velocity.y)
	elif not _was_on_floor:
		_in_jump = false
		if _fall_peak_speed > 500.0:
			_do_squash(Vector2(1.18, 0.82))
			sprite.play("land")
			Fx.spawn(self, &"dust", global_position + Vector2(0, -30), 0.45)
			AudioManager.play_sfx("sfx_land")
		_fall_peak_speed = 0.0
	_was_on_floor = is_on_floor()

func _update_animation() -> void:
	if frozen and sprite.animation in ["cheer", "hurt"]:
		return
	if not is_on_floor():
		# A jump keeps the leap pose up and down; "fall" is only for drops without a jump.
		sprite.play("jump" if _in_jump or velocity.y < 0.0 else "fall")
	elif sprite.animation == "land" and sprite.is_playing() and abs(velocity.x) < 60.0:
		return  # let the landing finish unless the player starts running
	elif abs(velocity.x) > 20.0:
		sprite.play("walk")
	else:
		sprite.play("sleepy" if is_tired() else "idle")
	# Tired legs move slower, matching the slower speed.
	sprite.speed_scale = _speed_factor() if sprite.animation == "walk" else 1.0

# Gentle breathing while standing still, done by scaling (no extra frames, so nothing can wobble).
func _breathe(delta: float) -> void:
	var squashing := _squash != null and _squash.is_running()
	if squashing:
		return
	if sprite.animation == "idle" and is_on_floor():
		_breath_time += delta
		var s := sin(_breath_time * TAU / breath_period)
		sprite.scale = _base_scale * Vector2(1.0 - breath_amount * 0.5 * s, 1.0 + breath_amount * s)
	elif _breath_time != 0.0:
		_breath_time = 0.0
		sprite.scale = _base_scale

func _do_squash(amount: Vector2) -> void:
	if _squash:
		_squash.kill()
	_squash = create_tween()
	_squash.tween_property(sprite, "scale", _base_scale * amount, 0.07)
	_squash.tween_property(sprite, "scale", _base_scale, 0.14)

func set_energy(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	if value != energy:
		energy = value
		Events.energy_changed.emit(energy)

func is_tired() -> bool:
	return energy <= 0.0

## Drank milk: full energy again, with a happy little hop of the sprite.
func refill_energy() -> void:
	energy = 1.0
	_do_squash(Vector2(0.9, 1.12))

func _use_energy(delta: float) -> void:
	if not frozen and abs(velocity.x) > 20.0:
		energy -= delta / energy_seconds

func _speed_factor() -> float:
	return tired_speed if is_tired() else 1.0

## Put the cat back at a point (after a pit fall), with a short blink so the player sees where she is.
func respawn_at(point: Vector2) -> void:
	global_position = point
	velocity = Vector2.ZERO
	_in_jump = false
	_fall_peak_speed = 0.0
	frozen = false
	_safe_left = safe_time
	sprite.flip_h = false
	sprite.modulate.a = 1.0
	sprite.play("idle")
	var blink := create_tween().set_loops(7)
	blink.tween_property(sprite, "modulate:a", 0.3, 0.08)
	blink.tween_property(sprite, "modulate:a", 1.0, 0.08)

## Take over and walk her to an x position (cutscenes). Await `arrived`.
func walk_to(x: float) -> void:
	frozen = true
	_walk_target = x

func _auto_walk(delta: float) -> void:
	if is_nan(_walk_target):
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		return
	var dx := _walk_target - global_position.x
	if abs(dx) < 8.0:
		velocity.x = 0.0
		_walk_target = NAN
		arrived.emit()
	else:
		velocity.x = sign(dx) * run_speed * 0.5
		sprite.flip_h = dx < 0.0

## Hazards ask this before hurting her (just respawned, or already hurt).
func can_be_hurt() -> bool:
	return _safe_left <= 0.0 and not frozen

## Got hurt: a little knock-back hop and the hurt pose; the level decides what happens next.
func knock_back() -> void:
	frozen = true
	var away := 1.0 if sprite.flip_h else -1.0
	velocity = Vector2(away * 220.0, _jump_speed * 0.45)
	sprite.play("hurt")

## Landed on an enemy: bounce up (holding jump doesn't matter, it's always the same bounce).
func stomp_bounce_up() -> void:
	velocity.y = _jump_speed * stomp_bounce
	_in_jump = true
	_do_squash(Vector2(0.85, 1.15))

## Fell into water: she drifts down and fades out under the waves.
func sink() -> void:
	frozen = true
	velocity = Vector2(velocity.x * 0.2, minf(velocity.y, 200.0))
	create_tween().tween_property(sprite, "modulate:a", 0.0, 0.5)

## Landed on a bouncy mushroom: launched up. `height` is a share of a full jump (2.2 = 2.2x as high).
func mushroom_bounce(height: float) -> void:
	velocity.y = _jump_speed * sqrt(height)
	_in_jump = true
	_fall_peak_speed = 0.0
	_do_squash(Vector2(0.8, 1.2))

## Out of hearts: stop and look sad.
func give_up() -> void:
	frozen = true
	velocity = Vector2.ZERO
	sprite.play("hurt")
