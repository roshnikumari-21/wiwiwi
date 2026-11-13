class_name CrumbleTile
extends StaticBody2D
## World 2 hazard (roof tile), and World 4's thin ice: a short floating piece. When the cat lands on it, it cracks and shakes
## for shake_time, then breaks into 4 chunks that fall away; it comes back return_time later.
## One-way like a ledge (she can jump up through it). Origin = middle of its walkable top.

## Two looks: World 2's roof tile, and World 4's thin ice (tools/art_pipeline/make_thin_ice.py).
## Each: whole, cracked, 4 chunks, where each chunk sits in the frame, the frame row the cat walks on.
const ART := "res://assets/art/objects/"
const LOOKS := {
	"roof": {
		"whole": preload(ART + "crumble_whole.png"), "cracked": preload(ART + "crumble_cracked.png"),
		"chunks": [preload(ART + "crumble_chunk_0.png"), preload(ART + "crumble_chunk_1.png"),
			preload(ART + "crumble_chunk_2.png"), preload(ART + "crumble_chunk_3.png")],
		"chunk_at": [Vector2(3, 33), Vector2(89, 33), Vector2(175, 37), Vector2(228, 34)],   # make_town.py
		"surface": 35.0,
	},
	"ice": {
		"whole": preload(ART + "thin_ice_whole.png"), "cracked": preload(ART + "thin_ice_cracked.png"),
		"chunks": [preload(ART + "thin_ice_chunk_0.png"), preload(ART + "thin_ice_chunk_1.png"),
			preload(ART + "thin_ice_chunk_2.png"), preload(ART + "thin_ice_chunk_3.png")],
		"chunk_at": [Vector2(0, 11), Vector2(78, 11), Vector2(160, 11), Vector2(232, 11)],   # make_thin_ice.py
		"surface": 14.0,
	},
}
const WIDTH := 306.0

@export_enum("roof", "ice") var look: String = "roof"
@export var shake_time: float = 0.5    ## seconds from landing to breaking
@export var return_time: float = 3.0   ## seconds until it's back after breaking

enum State { WHOLE_TILE, SHAKING, GONE }
var state := State.WHOLE_TILE

@onready var sprite: Sprite2D = $Sprite
@onready var shape: CollisionShape2D = $Shape
@onready var feet: Area2D = $Feet

func _ready() -> void:
	sprite.texture = LOOKS[look]["whole"]
	sprite.centered = false
	sprite.position = Vector2(-WIDTH * 0.5, -LOOKS[look]["surface"])

func _physics_process(_delta: float) -> void:
	if state != State.WHOLE_TILE:
		return
	for body in feet.get_overlapping_bodies():
		if body is Player and body.is_on_floor():
			_crack()
			return

func _crack() -> void:
	state = State.SHAKING
	sprite.texture = LOOKS[look]["cracked"]
	AudioManager.play_sfx("sfx_land", 0.6)
	var x := sprite.position.x
	var t := create_tween()
	for i in 6:   # a little shiver so the player sees it's about to go
		t.tween_property(sprite, "position:x", x + (4.0 if i % 2 == 0 else -4.0), shake_time / 6.0)
	t.tween_property(sprite, "position:x", x, 0.01)
	t.tween_callback(_break)

func _break() -> void:
	state = State.GONE
	shape.set_deferred("disabled", true)
	sprite.visible = false
	AudioManager.play_sfx("sfx_stomp", 0.7)
	var chunks: Array = LOOKS[look]["chunks"]
	for i in chunks.size():
		var chunk := Sprite2D.new()
		chunk.texture = chunks[i]
		chunk.centered = false
		chunk.position = sprite.position + LOOKS[look]["chunk_at"][i]
		add_child(chunk)
		var t := create_tween().set_parallel()
		t.tween_property(chunk, "position:y", chunk.position.y + 420.0, 0.7).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD).set_delay(i * 0.05)
		t.tween_property(chunk, "rotation", randf_range(-0.5, 0.5), 0.7)
		t.tween_property(chunk, "modulate:a", 0.0, 0.3).set_delay(0.45)
		t.chain().tween_callback(chunk.queue_free)
	await get_tree().create_timer(return_time).timeout
	if is_inside_tree():
		_come_back()

## Reappears with a soft fade, but never inside the cat: it waits while she's in its spot.
func _come_back() -> void:
	while _cat_in_the_way():
		await get_tree().create_timer(0.3).timeout
		if not is_inside_tree():
			return
	sprite.texture = LOOKS[look]["whole"]
	sprite.visible = true
	sprite.modulate.a = 0.0
	create_tween().tween_property(sprite, "modulate:a", 1.0, 0.3)
	shape.set_deferred("disabled", false)
	state = State.WHOLE_TILE

func _cat_in_the_way() -> bool:
	for node in get_tree().get_nodes_in_group("player"):
		var at: Vector2 = node.global_position - global_position
		if absf(at.x) < WIDTH * 0.5 + 60.0 and at.y > -180.0 and at.y < 80.0:
			return true
	return false
