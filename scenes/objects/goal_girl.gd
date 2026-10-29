extends Area2D
## The end of the level: the girl waits for her kitten. Origin = the girl's feet.
## She opens her arms and bounces when the cat comes near; reaching her, she kneels,
## the cat walks into her arms and they hug (3-frame loop) while hearts float up.

signal reached

const ARMS_OPEN := preload("res://assets/art/characters/girl/girl_arms_open.png")
const KNEEL_OPEN := preload("res://assets/art/characters/girl/girl_kneel_open.png")
const HUG_FRAMES: Array[Texture2D] = [
	preload("res://assets/art/characters/girl/girl_hug_0.png"),
	preload("res://assets/art/characters/girl/girl_hug_1.png"),
	preload("res://assets/art/characters/girl/girl_hug_2.png"),
]
const HUG_LOOP := [0, 1, 2, 1]          ## frame order of the hug loop
const HUG_HOLD := [0.55, 0.45, 0.7, 0.45]  ## seconds on each step: slow, so it reads as a squeeze, not a jiggle
const HEART := preload("res://assets/art/objects/heart_full.png")

# Each pose's canvas size differs, so each needs its own offset to keep the feet on the ground.
const KNEEL_OFFSET := Vector2(0, -247)
const HUG_OFFSET := Vector2(0, -252)    # hug canvas has 20 px of padding below the knees

@export var notice_distance: float = 650.0   ## she spots the cat this close
@export var hug_time: float = 2.0            ## seconds of hugging before the result card
@export var kneel_scale: float = 1.2         ## kneeling/hug art is drawn bigger; this keeps the kitten in her arms close to game size

@onready var girl: Sprite2D = $Girl

var _done := false
var _excited := false
var _bounce: Tween
var _breath: Tween
var _base_scale: Vector2

func _ready() -> void:
	_base_scale = girl.scale
	_breath = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_breath.tween_property(girl, "scale:y", girl.scale.y * 1.012, 1.3)
	_breath.tween_property(girl, "scale:y", girl.scale.y, 1.3)

func _physics_process(_delta: float) -> void:
	if _excited or _done:
		return
	var cat := get_tree().get_first_node_in_group("player") as Node2D
	if cat and cat.global_position.distance_to(global_position) < notice_distance:
		_excited = true
		girl.texture = ARMS_OPEN
		_bounce = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		_bounce.tween_property(girl, "position:y", -22.0, 0.2).set_ease(Tween.EASE_OUT)
		_bounce.tween_property(girl, "position:y", 0.0, 0.2).set_ease(Tween.EASE_IN)
		_bounce.tween_interval(0.15)

func _on_body_entered(body: Node2D) -> void:
	if _done or not body.is_in_group("player"):
		return
	_done = true
	reached.emit()

## She kneels, the cat walks into her arms, they hug and hearts float up. Await this.
func play_reunion(cat: Player) -> void:
	if _bounce:
		_bounce.kill()
	_breath.kill()
	girl.position.y = 0.0
	girl.scale = _base_scale * kneel_scale
	_pose(KNEEL_OPEN, KNEEL_OFFSET)
	cat.walk_to(global_position.x - 70.0)
	await cat.arrived
	cat.visible = false
	var base := girl.scale
	var pop := create_tween()
	pop.tween_property(girl, "scale", base * Vector2(1.05, 0.95), 0.08)
	pop.tween_property(girl, "scale", base, 0.25).set_trans(Tween.TRANS_BACK)
	_hug_loop()
	for i in 3:
		_float_heart(Vector2(-70.0 + i * 55.0, -360.0), i * 0.3)
	await get_tree().create_timer(hug_time).timeout

func _hug_loop() -> void:
	var loop := create_tween().set_loops()
	for i in HUG_LOOP.size():
		loop.tween_callback(_pose.bind(HUG_FRAMES[HUG_LOOP[i]], HUG_OFFSET))
		loop.tween_interval(HUG_HOLD[i])

func _pose(texture: Texture2D, offset: Vector2) -> void:
	girl.texture = texture
	girl.offset = offset

func _float_heart(from: Vector2, delay: float) -> void:
	var heart := Sprite2D.new()
	heart.texture = HEART
	heart.scale = Vector2(0.14, 0.14)
	heart.position = from
	heart.modulate.a = 0.0
	add_child(heart)
	var t := create_tween().set_parallel()
	t.tween_property(heart, "modulate:a", 1.0, 0.2).set_delay(delay)
	t.tween_property(heart, "position:y", from.y - 140.0, 1.2).set_delay(delay).set_ease(Tween.EASE_OUT)
	t.tween_property(heart, "modulate:a", 0.0, 0.4).set_delay(delay + 0.8)
	t.chain().tween_callback(heart.queue_free)
