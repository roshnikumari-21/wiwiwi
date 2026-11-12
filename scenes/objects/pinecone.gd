class_name Pinecone
extends Node2D
## World 3 hazard: a pinecone hangs high above the path. When the cat comes near, it shakes and its
## shadow grows on the ground for `warn_time` (the fair warning), then it drops. Touching it while it
## falls hurts; when it lands it bounces, rolls a little and fades (harmless). If `every` > 0 a new
## one grows back and drops again on that rhythm while the cat is near.
## Origin = the spot on the ground where it lands (place it on the ground); it hangs `height` above.

const HANGING := preload("res://assets/art/objects/cone_hanging.png")
const FALLING := preload("res://assets/art/objects/cone_falling.png")
const LANDED := preload("res://assets/art/objects/cone_landed.png")
const GRAVITY := 2600.0
const HURT_RADIUS := 34.0     ## around the falling cone's middle
const WAKE_DISTANCE := 700.0  ## starts its rhythm when the cat is this close (on screen)

@export var height: float = 430.0    ## px above the ground where it hangs (above a jump, still on screen)
@export var warn_time: float = 1.0   ## shaking + growing shadow before it drops
@export var every: float = 0.0       ## seconds between drops (0 = drops once)
@export var first_delay: float = 0.0 ## extra wait before the first drop (to put cones out of step)

enum State { WAITING, WARNING, FALLING, DONE }
var state := State.WAITING

var _cone: Sprite2D
var _shadow: Node2D
var _speed := 0.0
var _timer := 0.0

func _ready() -> void:
	_shadow = Node2D.new()
	_shadow.draw.connect(_draw_shadow)
	add_child(_shadow)
	_grow_new()

func _grow_new() -> void:
	_cone = Sprite2D.new()
	_cone.texture = HANGING
	_cone.position = Vector2(0, -height)
	add_child(_cone)
	state = State.WAITING
	_timer = first_delay if every == 0.0 or _timer == 0.0 else every
	_shadow.scale = Vector2.ZERO
	_shadow.queue_redraw()

func _physics_process(delta: float) -> void:
	match state:
		State.WAITING:
			if _cat_near():
				_timer -= delta
				if _timer <= 0.0:
					_warn()
		State.FALLING:
			_speed += GRAVITY * delta
			_cone.position.y += _speed * delta
			_cone.rotation += 3.0 * delta
			_hurt_check()
			if _cone.position.y >= -LANDED.get_height() * 0.5:
				_land()

func _cat_near() -> bool:
	for cat in get_tree().get_nodes_in_group("player"):
		if absf(cat.global_position.x - global_position.x) < WAKE_DISTANCE:
			return true
	return false

## The warning: it shivers on its branch while the shadow below grows from a dot to full size.
func _warn() -> void:
	state = State.WARNING
	var t := create_tween().set_parallel()
	t.tween_property(_shadow, "scale", Vector2.ONE, warn_time).set_ease(Tween.EASE_OUT)
	var shake := create_tween()
	for i in 8:
		shake.tween_property(_cone, "rotation", 0.16 if i % 2 == 0 else -0.16, warn_time / 8.0)
	shake.tween_callback(_drop)

func _drop() -> void:
	state = State.FALLING
	_speed = 0.0
	_cone.texture = FALLING
	_cone.rotation = 0.0
	_cone.position.y += 30.0   # the falling picture has no twig: start where the cone was
	AudioManager.play_sfx("sfx_jump", 0.7)

func _hurt_check() -> void:
	var at := _cone.global_position
	for cat in get_tree().get_nodes_in_group("player"):
		var body: Vector2 = cat.global_position + Vector2(0, -60)   # the cat's middle
		if absf(body.x - at.x) < HURT_RADIUS + 45.0 and absf(body.y - at.y) < HURT_RADIUS + 60.0 and cat.can_be_hurt():
			Events.player_hurt.emit()

## Thud, a hop and a short roll, then it fades; the shadow goes with it.
func _land() -> void:
	state = State.DONE
	AudioManager.play_sfx("sfx_land", 0.8)
	Fx.spawn(self, &"dust", global_position, 0.6)
	var cone := _cone
	cone.texture = LANDED
	cone.rotation = 0.0
	cone.position.y = -LANDED.get_height() * 0.5
	var roll := 1.0 if randf() < 0.5 else -1.0
	var t := cone.create_tween().set_parallel()
	t.tween_property(cone, "position:x", roll * 70.0, 0.7).set_ease(Tween.EASE_OUT)
	t.tween_property(cone, "rotation", roll * 1.2, 0.7)
	t.tween_property(cone, "modulate:a", 0.0, 0.4).set_delay(0.6)
	t.chain().tween_callback(cone.queue_free)
	var fade := create_tween()
	fade.tween_property(_shadow, "scale", Vector2.ZERO, 0.3)
	if every > 0.0:
		_timer = every
		await get_tree().create_timer(0.5).timeout
		if is_inside_tree():
			_grow_new()

func _draw_shadow() -> void:
	# A soft dark oval on the ground (two layers so its edge is softer).
	_shadow.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
	_shadow.draw_circle(Vector2.ZERO, 58.0, Color(0.08, 0.05, 0.02, 0.25))
	_shadow.draw_circle(Vector2.ZERO, 40.0, Color(0.08, 0.05, 0.02, 0.45))
