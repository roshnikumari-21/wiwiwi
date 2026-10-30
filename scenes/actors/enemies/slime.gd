class_name Slime
extends CharacterBody2D
## World 1 slime. Patrols left and right around where it was placed. Landing on top squashes it
## (the cat bounces); touching it from the side costs a heart. Origin = bottom centre.

@export var speed: float = 90.0
@export var patrol_distance: float = 220.0   ## how far it wanders each way from its start
@export var start_left: bool = false

const GRAVITY := 3000.0
const STOMP_HEIGHT := 40.0   ## the cat's feet must be at least this far above the slime's base

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hitbox: Area2D = $Hitbox

var _home_x: float
var _dir := 1.0
var _squashed := false

func _ready() -> void:
	_home_x = global_position.x
	_dir = -1.0 if start_left else 1.0

func _physics_process(delta: float) -> void:
	if _squashed:
		return
	velocity.y += GRAVITY * delta
	var dx := global_position.x - _home_x
	if (dx > patrol_distance and _dir > 0.0) or (dx < -patrol_distance and _dir < 0.0) or is_on_wall():
		_dir = -_dir
	velocity.x = _dir * speed
	sprite.flip_h = _dir < 0.0   # the art faces right
	move_and_slide()
	_check_cat()

func _check_cat() -> void:
	for body in hitbox.get_overlapping_bodies():
		if not body is Player or body.frozen:   # ignore her while she's in the hurt pose
			continue
		var cat := body as Player
		if cat.velocity.y > 0.0 and cat.global_position.y < global_position.y - STOMP_HEIGHT:
			cat.stomp_bounce_up()
			_squash()
		elif cat.can_be_hurt():
			Events.player_hurt.emit()

func _squash() -> void:
	_squashed = true
	Events.enemy_stomped.emit()
	collision_layer = 0
	hitbox.set_deferred("monitoring", false)
	sprite.play("squash")
	var t := create_tween()
	t.tween_interval(0.5)
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(queue_free)
