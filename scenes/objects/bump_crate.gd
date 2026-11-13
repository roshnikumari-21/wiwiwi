class_name BumpCrate
extends StaticBody2D
## A wooden crate (or a gift box) with a golden paw: jump into it from below and it gives what it holds, like a "?"
## block. `coins` coins pop out one per bump (they count as picked up, and in the level's coin total);
## `milk` puts a bowl of milk on top instead. When it's empty it turns into the plain crate.
## The cat can stand on it either way. Origin = bottom centre (it sits on the ground or floats).

## Looks: the wooden paw crate (World 3) or the gift box (World 4). Full and used pictures.
const LOOKS := {
	"crate": [preload("res://assets/art/objects/crate_full.png"), preload("res://assets/art/objects/crate_used.png")],
	"gift": [preload("res://assets/art/objects/gift_full.png"), preload("res://assets/art/objects/gift_used.png")],
}
const COIN := preload("res://scenes/objects/coin.tscn")   ## only its spinning sprite is borrowed
const MILK := preload("res://scenes/objects/milk_bowl.tscn")
const SIZE := Vector2(104, 104)   ## the solid part (the art is ~110 with its moss)

@export_range(0, 10) var coins: int = 1   ## coins it holds (0 with milk = just milk)
@export var milk: bool = false             ## gives a bowl of milk (after its coins, if any)
@export_enum("crate", "gift") var look: String = "crate"

var FULL: Texture2D
var USED: Texture2D

@onready var sprite: Sprite2D = $Sprite

var _left := 0
var _milk_given := false

func _ready() -> void:
	add_to_group("coin_crates")
	FULL = LOOKS[look][0]
	USED = LOOKS[look][1]
	_left = coins
	_show(FULL if (coins > 0 or milk) else USED)

## Show a picture with its bottom on the crate's bottom (the gift's full and used pictures differ in height).
func _show(tex: Texture2D) -> void:
	sprite.texture = tex
	sprite.offset = Vector2(0, -tex.get_height() * 0.5)

func is_empty() -> bool:
	return _left == 0 and (not milk or _milk_given)

## Called by the cat when her head hits it from below.
func bumped_from_below() -> void:
	_wobble()
	if is_empty():
		AudioManager.play_sfx("sfx_land", 0.7)   # a dull knock
		return
	if _left > 0:
		_left -= 1
		_pop_coin()
	elif milk and not _milk_given:
		_milk_given = true
		var bowl: Node2D = MILK.instantiate()
		bowl.position = Vector2(0, -SIZE.y)
		add_child(bowl)
		AudioManager.play_sfx("sfx_boing", 1.2)
	if is_empty():
		_show(USED)

func _wobble() -> void:
	var t := create_tween()
	t.tween_property(sprite, "position:y", -14.0, 0.07).set_ease(Tween.EASE_OUT)
	t.tween_property(sprite, "position:y", 0.0, 0.12).set_ease(Tween.EASE_IN)

## A coin jumps out of the top, spins up and is collected (the cat earned it with the bump).
func _pop_coin() -> void:
	Events.coin_collected.emit()
	AudioManager.play_coin()
	var source: Node = COIN.instantiate()
	var coin: AnimatedSprite2D = source.get_node("Sprite").duplicate()
	source.free()   # not a real coin: it isn't in the "coins" group and can't be picked up again
	coin.position = Vector2(0, -SIZE.y - 20)
	add_child(coin)
	coin.play("spin")
	var t := coin.create_tween()
	t.tween_property(coin, "position:y", coin.position.y - 130.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(func(): Fx.spawn(self, &"coin", coin.global_position, 0.5))
	t.tween_callback(coin.queue_free)
