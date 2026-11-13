class_name Slime
extends CharacterBody2D
## World 1 slime. Patrols left and right around where it was placed. Origin = bottom centre.
## Fair-play rules (owner playtest, 31 Oct 2026: jumping over slimes kept hurting):
##  - the cat in the air never gets hurt by a slime: if her feet are above its middle she squashes
##    it and bounces on (rising or falling), otherwise she just passes by
##  - only walking into it on the ground hurts, and that touch zone is narrower than the slime

@export var speed: float = 90.0
@export var patrol_distance: float = 220.0   ## how far it wanders each way from its start
@export var start_left: bool = false

const GRAVITY := 3000.0
const STOMP_ABOVE := 30.0    ## an airborne cat whose feet are higher than this above the base squashes it
const HURT_REACH := 70.0     ## on the ground, centres closer than this hurt (bodies are 92 + 100 wide)

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
	if patrol_distance < 1.0:
		# No path to walk: stand still, facing the cat (turning every frame looked like a shiver).
		velocity.x = 0.0
		var cat := get_tree().get_first_node_in_group("player") as Node2D
		if cat:
			sprite.flip_h = cat.global_position.x < global_position.x   # the art faces right
	else:
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
		if not cat.is_on_floor():
			if cat.global_position.y < global_position.y - STOMP_ABOVE:
				cat.stomp_bounce_up()
				_squash()
			return   # in the air but low: taking off or landing beside it, no harm
		if absf(cat.global_position.x - global_position.x) < HURT_REACH and cat.can_be_hurt():
			Events.player_hurt.emit()

func _squash() -> void:
	_squashed = true
	Events.enemy_stomped.emit()
	AudioManager.play_sfx("sfx_stomp")
	collision_layer = 0
	hitbox.set_deferred("monitoring", false)
	sprite.play("squash")
	var t := create_tween()
	t.tween_interval(0.5)
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(queue_free)
