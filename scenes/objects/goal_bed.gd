extends Area2D
## The end of the level: the girl waits beside the cat bed. Origin = the girl's feet.
## She opens her arms and bounces when the cat comes near; reaching her plays the hug.

signal reached

const ARMS_OPEN := preload("res://assets/art/characters/girl/girl_arms_open.png")
const HUG := preload("res://assets/art/characters/girl/girl_hug.png")
const HEART := preload("res://assets/art/objects/heart_full.png")

@export var notice_distance: float = 650.0   ## she spots the cat this close
@export var hug_time: float = 1.8            ## seconds of hugging before the result card
@export var hug_scale: float = 1.35          ## the kitten in the hug art is drawn smaller; this matches her size

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
	if _excited:
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

## Cat walks into her arms, she kneels and hugs, hearts float up. Await this.
func play_reunion(cat: Player) -> void:
	cat.walk_to(global_position.x - 40.0)
	await cat.arrived
	if _bounce:
		_bounce.kill()
	_breath.kill()
	cat.visible = false
	girl.position.y = 0.0
	girl.texture = HUG
	var base := _base_scale * hug_scale
	girl.scale = base
	var pop := create_tween()
	pop.tween_property(girl, "scale", base * Vector2(1.06, 0.94), 0.08)
	pop.tween_property(girl, "scale", base, 0.25).set_trans(Tween.TRANS_BACK)
	for i in 3:
		_float_heart(Vector2(-60.0 + i * 50.0, -330.0), i * 0.25)
	await get_tree().create_timer(hug_time).timeout

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
