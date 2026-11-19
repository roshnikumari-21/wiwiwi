class_name Mole
extends Slime
## World 5 enemy, the sand mole. It tunnels along its path under the sand — all you see is a little
## mound of sand moving (harmless) — then stops and the mound TREMBLES (the warning), and the mole
## POPS UP and looks around for a moment before diving back down and tunnelling on.
##  - popping up right under her hurts (she was standing on the trembling mound)
##  - while it's up it's a slime: stomp it from above (it squashes), walking into it hurts
##  - tunnelling or trembling it's just sand: she can walk or stand over it safely
## Origin = bottom centre (on the sand).

@export var tunnel_speed: float = 70.0
@export var tunnel_time: float = 2.2   ## seconds of tunnelling between pops
@export var warn_time: float = 0.6     ## the mound trembles this long before it pops up
@export var up_time: float = 1.6       ## seconds up, looking around (stompable)

const POP_TIME := 0.2        ## the "bursting out" picture before it looks around
const POP_REACH := 55.0      ## popping up hurts her if she stands this close above it

enum Mode { TUNNEL, WARN, UP }
const SINK := 12.0   ## px the mole art sits down into the sand

var mode := Mode.TUNNEL
var _timer := 0.0
var _shake: Tween

func _ready() -> void:
	super()
	_timer = randf_range(0.8, tunnel_time)   # moles near each other don't all pop together
	sprite.play("mound")
	# the mound's bottom a little INTO the sand strip (owners, 19 Nov 2026: right on the walkable edge it
	# looked like it floated above the sand)
	sprite.offset.y = -sprite.sprite_frames.get_frame_texture("mound", 0).get_height() * 0.5 + SINK

func _physics_process(delta: float) -> void:
	if _squashed:
		return
	velocity.y += GRAVITY * delta
	var dx := global_position.x - _home_x
	_timer -= delta
	match mode:
		Mode.TUNNEL:
			if (dx > patrol_distance and _dir > 0.0) or (dx < -patrol_distance and _dir < 0.0) or is_on_wall():
				_dir = -_dir
			velocity.x = _dir * tunnel_speed if patrol_distance >= 1.0 else 0.0
			if _timer <= 0.0:
				_start_warn()
		Mode.WARN:
			velocity.x = 0.0
			if _timer <= 0.0:
				_pop_up()
		Mode.UP:
			velocity.x = 0.0
			if _timer <= up_time - POP_TIME and sprite.animation == "pop":
				sprite.play("look")
			if _timer <= 0.0:
				_dive()
	sprite.flip_h = _dir < 0.0   # the art faces right
	move_and_slide()
	if mode == Mode.UP:
		_check_cat()   # only up out of the sand does it touch her (a slime's rules)

## The mound stops and trembles: a mole is about to pop up here.
func _start_warn() -> void:
	mode = Mode.WARN
	_timer = warn_time
	_shake = create_tween().set_loops(int(warn_time / 0.08))
	_shake.tween_property(sprite, "position:x", 3.0, 0.04)
	_shake.tween_property(sprite, "position:x", -3.0, 0.04)

func _pop_up() -> void:
	if _shake:
		_shake.kill()
	sprite.position.x = 0.0
	mode = Mode.UP
	_timer = up_time
	sprite.play("pop")
	AudioManager.play_sfx_at("sfx_jump", global_position, 1.3)
	_do_hop()
	# standing right on the trembling mound: the mole bumps her from below
	for cat in get_tree().get_nodes_in_group("player"):
		if cat.is_on_floor() and absf(cat.global_position.x - global_position.x) < POP_REACH \
				and absf(cat.global_position.y - global_position.y) < 30.0 and cat.can_be_hurt():
			Events.player_hurt.emit()

func _dive() -> void:
	mode = Mode.TUNNEL
	_timer = tunnel_time
	sprite.play("mound")
	_do_hop()

## A little squash-and-stretch when it pops up or dives.
func _do_hop() -> void:
	var t := create_tween()
	t.tween_property(sprite, "scale", Vector2(0.9, 1.12), 0.08)
	t.tween_property(sprite, "scale", Vector2.ONE, 0.12)

func _squash() -> void:
	if _shake:
		_shake.kill()
	sprite.scale = Vector2.ONE
	sprite.position.x = 0.0
	super()
