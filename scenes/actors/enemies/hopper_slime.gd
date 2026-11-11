class_name HopperSlime
extends Slime
## World 2 enemy: a slime that hops along its patrol path in little arcs instead of crawling.
## It rests, crouches (squash), springs up (stretch) and lands; at the ends of its path it turns.
## Contact rules like the slime (see slime.gd), but kinder in the air: see _check_cat.

@export var hop_every: float = 1.1     ## seconds resting on the ground between hops
@export var hop_height: float = 170.0  ## px
@export var hop_length: float = 150.0  ## px travelled per hop

const CROUCH_TIME := 0.18

var _rest := 0.0
var _crouching := false
var _base_scale: Vector2
var _tween: Tween

func _ready() -> void:
	super()
	_base_scale = sprite.scale
	sprite.stop()
	sprite.frame = 0
	_rest = randf_range(0.2, hop_every)   # hoppers next to each other don't all hop together

func _physics_process(delta: float) -> void:
	if _squashed:
		return
	velocity.y += GRAVITY * delta
	if is_on_floor() and velocity.y >= 0.0:   # landed (on the launch frame it still counts as on the floor)
		velocity.x = 0.0
		if not _crouching:
			_rest -= delta
			if _rest <= 0.0:
				_crouch()
	move_and_slide()
	_check_cat()

func _crouch() -> void:
	_crouching = true
	var dx := global_position.x - _home_x
	if (dx > patrol_distance and _dir > 0.0) or (dx < -patrol_distance and _dir < 0.0) or is_on_wall():
		_dir = -_dir
	sprite.flip_h = _dir < 0.0   # the art faces right
	_tween = create_tween()
	_tween.tween_property(sprite, "scale", _base_scale * Vector2(1.15, 0.8), CROUCH_TIME)
	_tween.tween_callback(_hop)

## A hop: up-speed from the height (v = sqrt(2·g·h)); side speed so it lands hop_length away.
func _hop() -> void:
	var up := sqrt(2.0 * GRAVITY * hop_height)
	var air_time := 2.0 * up / GRAVITY
	velocity = Vector2(_dir * hop_length / air_time, -up)
	_crouching = false
	_rest = hop_every
	sprite.frame = 1
	_tween = create_tween()
	_tween.tween_property(sprite, "scale", _base_scale * Vector2(0.88, 1.15), air_time * 0.4)
	_tween.tween_property(sprite, "scale", _base_scale, air_time * 0.5)
	_tween.tween_callback(func(): sprite.frame = 0)

## Kinder than the slime's rule: a hopper can jump under a falling cat (into her landing spot), so
## any touch while she's falling squashes it, not only when she's clearly above it. On the ground,
## walking into it still hurts.
func _check_cat() -> void:
	for body in hitbox.get_overlapping_bodies():
		if not body is Player or body.frozen:
			continue
		var cat := body as Player
		if not cat.is_on_floor():
			if cat.velocity.y > 0.0 or cat.global_position.y < global_position.y - STOMP_ABOVE:
				cat.stomp_bounce_up()
				_squash()
			return
		if absf(cat.global_position.x - global_position.x) < HURT_REACH and cat.can_be_hurt():
			Events.player_hurt.emit()

func _squash() -> void:
	if _tween:
		_tween.kill()
	sprite.scale = _base_scale
	super()
