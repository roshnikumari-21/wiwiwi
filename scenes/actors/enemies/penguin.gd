class_name Penguin
extends Slime
## World 4 enemy: waddles slowly for a while, then crouches with a little "whoosh" (the warning) and
## flops onto its belly to ZOOM along its path to the far end, turns, and starts over.
## Contact rules are the slime's: stomp it from above (it squashes), walking into it hurts — the
## challenge is its speed while sliding.

@export var waddle_speed: float = 55.0
@export var waddle_time: float = 1.8   ## seconds of waddling between slides
@export var slide_speed: float = 480.0
@export var warn_time: float = 0.4     ## the crouch + whoosh before each slide

const TRAIL := preload("res://assets/art/enemies/penguin/peng_trail.png")

enum Mode { WADDLE, WARN, SLIDE }
var mode := Mode.WADDLE
var _timer := 0.0
var _trail: Sprite2D

func _ready() -> void:
	super()
	_timer = randf_range(0.6, waddle_time)   # penguins near each other don't all slide together
	_trail = Sprite2D.new()
	_trail.texture = TRAIL
	_trail.visible = false
	add_child(_trail)

func _physics_process(delta: float) -> void:
	if _squashed:
		return
	velocity.y += GRAVITY * delta
	var dx := global_position.x - _home_x
	match mode:
		Mode.WADDLE:
			if (dx > patrol_distance and _dir > 0.0) or (dx < -patrol_distance and _dir < 0.0) or is_on_wall():
				_dir = -_dir
			velocity.x = _dir * waddle_speed
			_timer -= delta
			if _timer <= 0.0:
				_start_warn()
		Mode.WARN:
			velocity.x = 0.0
			_timer -= delta
			if _timer <= 0.0:
				_start_slide()
		Mode.SLIDE:
			velocity.x = _dir * slide_speed
			if (dx > patrol_distance and _dir > 0.0) or (dx < -patrol_distance and _dir < 0.0) or is_on_wall():
				_dir = -_dir
				_end_slide()
	sprite.flip_h = _dir < 0.0   # the art faces right
	_trail.position = Vector2(-_dir * 75.0, -30.0)
	_trail.flip_h = _dir < 0.0
	move_and_slide()
	_check_cat()

## Turn to the far end of the path, crouch a moment, whoosh.
func _start_warn() -> void:
	mode = Mode.WARN
	_timer = warn_time
	var dx := global_position.x - _home_x
	_dir = -1.0 if dx > 0.0 else 1.0   # slide toward the farther end
	AudioManager.play_sfx("sfx_jump", 0.6)
	var t := create_tween()
	t.tween_property(sprite, "scale", Vector2(1.12, 0.86), warn_time * 0.6)
	t.tween_property(sprite, "scale", Vector2.ONE, warn_time * 0.4)

func _start_slide() -> void:
	mode = Mode.SLIDE
	sprite.play("slide")
	_trail.visible = true

func _end_slide() -> void:
	mode = Mode.WADDLE
	_timer = waddle_time
	sprite.play("move")
	_trail.visible = false

func _squash() -> void:
	_trail.visible = false
	sprite.scale = Vector2.ONE
	super()
