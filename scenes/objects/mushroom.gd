extends Area2D
## Bouncy mushroom: landing on the cap launches the cat high. Hold jump while landing for a big
## bounce, otherwise a medium one. Never hurts. Origin = bottom of the stem (sits on the ground).

const SQUASH := preload("res://assets/art/objects/mushroom_squash.png")
const NORMAL := preload("res://assets/art/objects/mushroom.png")

@export var big_bounce: float = 2.2   ## jump held: x times a full jump
@export var small_bounce: float = 1.6 ## jump not held

@onready var sprite: Sprite2D = $Sprite

var _squash: Tween

func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is Player and not body.frozen and body.velocity.y > 0.0:
			_bounce(body)

func _bounce(cat: Player) -> void:
	cat.mushroom_bounce(big_bounce if Input.is_action_pressed("jump") else small_bounce)
	Fx.spawn(self, &"dust", global_position + Vector2(0, -150), 0.5)
	AudioManager.play_sfx("sfx_boing")
	if _squash:
		_squash.kill()
	sprite.texture = SQUASH
	sprite.scale = Vector2(0.55, 0.45)
	_squash = create_tween()
	_squash.tween_interval(0.1)
	_squash.tween_callback(func(): sprite.texture = NORMAL)
	_squash.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
