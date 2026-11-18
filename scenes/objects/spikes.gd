@tool
extends Area2D
## Spike trap resting on the ground: touching it costs a heart. Origin = bottom centre (on the grass).
## Short = 3 spikes (easy hop), Long = 5 spikes (needs a proper jump).

## Looks: the meadow's white spikes, or World 5's cactus spikes (same size: just as hard to jump).
const LOOKS := {
	"spikes": [preload("res://assets/art/objects/spikes_short.png"), preload("res://assets/art/objects/spikes_long.png")],
	"cactus": [preload("res://assets/art/objects/spikes_cactus_short.png"), preload("res://assets/art/objects/spikes_cactus_long.png")],
}
const SCALE := 0.26
const SINK := 6.0            # sits this many px into the grass so it looks planted
const HURT_SHARE := Vector2(0.86, 0.75)   # hurt box: share of the art's width and height

@export var long: bool = false:
	set(value):
		long = value
		_rebuild()
@export_enum("spikes", "cactus") var look: String = "spikes":
	set(value):
		look = value
		_rebuild()

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	var sprite: Sprite2D = get_node_or_null("Sprite")
	var shape: CollisionShape2D = get_node_or_null("Shape")
	if sprite == null or shape == null:
		return
	sprite.texture = LOOKS[look][1 if long else 0]
	sprite.scale = Vector2.ONE * SCALE
	sprite.offset = Vector2(0, -sprite.texture.get_height() * 0.5 + SINK / SCALE)
	var size := sprite.texture.get_size() * SCALE
	var rect := RectangleShape2D.new()
	rect.size = size * HURT_SHARE
	shape.shape = rect
	shape.position = Vector2(0, -rect.size.y * 0.5)

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for body in get_overlapping_bodies():
		if body is Player and body.can_be_hurt():
			Events.player_hurt.emit()
