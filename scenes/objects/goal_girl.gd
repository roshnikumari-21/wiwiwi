extends Area2D
## The end of the level: the girl waits for her kitten. Origin = her front (right) shoe, which stays
## planted in every frame. She bounces with joy when the cat comes near; when the cat reaches her she
## kneels down (crouch -> reach -> arms wide), the cat walks into her arms and they hug (3-frame loop).

signal reached

const DIR := "res://assets/art/characters/girl/"
const KNEEL_DOWN: Array[Texture2D] = [
	preload(DIR + "girl_crouch.png"),
	preload(DIR + "girl_kneel_reach.png"),
	preload(DIR + "girl_kneel_open.png"),
]
const KNEEL_HOLD := 0.11                    ## seconds per kneel-down frame
const HUG_FRAMES: Array[Texture2D] = [
	preload(DIR + "girl_hug_0.png"),
	preload(DIR + "girl_hug_1.png"),
	preload(DIR + "girl_hug_2.png"),
]
const HUG_LOOP := [0, 1, 2, 1]             ## frame order of the hug loop
const HUG_HOLD := [0.5, 0.4, 0.7, 0.4]     ## seconds on each step: slow, so it reads as a squeeze, not a jiggle
const HEART := preload("res://assets/art/objects/heart_full.png")
const CANVAS_PAD := 10.0                    ## the art has 10 px of space below the shoes

@export var notice_distance: float = 650.0  ## she spots the cat this close
@export var hug_time: float = 2.0           ## seconds of hugging before the result card
@export var cat_hug_x: float = -160.0       ## where the kitten sits in the hug art (from her shoe)

@onready var girl: Sprite2D = $Girl

var _done := false
var _excited := false
var _bounce: Tween
var _breath: Tween

func _ready() -> void:
	_pose(girl.texture)
	_breath = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_breath.tween_property(girl, "scale:y", girl.scale.y * 1.012, 1.3)
	_breath.tween_property(girl, "scale:y", girl.scale.y, 1.3)

func _physics_process(_delta: float) -> void:
	if _excited or _done:
		return
	var cat := get_tree().get_first_node_in_group("player") as Node2D
	if cat and cat.global_position.distance_to(global_position) < notice_distance:
		_excited = true
		_bounce = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		_bounce.tween_property(girl, "position:y", -22.0, 0.2).set_ease(Tween.EASE_OUT)
		_bounce.tween_property(girl, "position:y", 0.0, 0.2).set_ease(Tween.EASE_IN)
		_bounce.tween_interval(0.2)

func _on_body_entered(body: Node2D) -> void:
	if _done or not body.is_in_group("player"):
		return
	_done = true
	reached.emit()

## She kneels down, the cat walks into her arms, they hug and hearts float up. Await this.
func play_reunion(cat: Player) -> void:
	cat.frozen = true   # she stops here; no more player control
	if _bounce:
		_bounce.kill()
	_breath.kill()
	girl.position.y = 0.0
	for frame in KNEEL_DOWN:
		_pose(frame)
		await get_tree().create_timer(KNEEL_HOLD).timeout
	cat.walk_to(global_position.x + cat_hug_x)
	await cat.arrived
	cat.visible = false
	_hug_loop()
	Fx.spawn(self, &"confetti", global_position + Vector2(cat_hug_x, -330), 1.3)
	for i in 3:
		_float_heart(Vector2(cat_hug_x + i * 55.0, -380.0), i * 0.3)
	await get_tree().create_timer(hug_time).timeout

func _hug_loop() -> void:
	var loop := create_tween().set_loops()
	for i in HUG_LOOP.size():
		loop.tween_callback(_pose.bind(HUG_FRAMES[HUG_LOOP[i]]))
		loop.tween_interval(HUG_HOLD[i])

## Show a frame with its bottom on the ground (each sheet's canvas has a different height).
func _pose(texture: Texture2D) -> void:
	girl.texture = texture
	girl.offset = Vector2(0.0, -(texture.get_height() * 0.5 - CANVAS_PAD))

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
