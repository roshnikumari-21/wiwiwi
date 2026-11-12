extends AnimatableBody2D
## Plank that glides back and forth and carries the cat. Origin = middle of its top surface at the
## start point. One-way: she can jump up through it from below.
## Theme: "meadow" = grass-topped log (World 1), "town" = wooden plank with a lantern (World 2),
## "forest" = log raft (World 3).

## Other worlds' planks: the picture, where the walkable part's middle is in it (lanterns, mushrooms
## hang past the ends) and how far below the picture's top the cat walks (make_town.py / make_forest.py).
const LOOKS := {
	"town": [preload("res://assets/art/objects/platform_moving_town.png"), 152.0, 0.0],
	"forest": [preload("res://assets/art/objects/platform_moving_forest.png"), 146.0, 23.0],
}

@export var move_by: Vector2 = Vector2(300, 0)   ## the far end, relative to where it's placed
@export var travel_time: float = 2.2             ## seconds for one trip
@export var end_pause: float = 0.5               ## rest at each end, so it's easy to step on/off
@export_enum("meadow", "town", "forest") var theme: String = "meadow"

func _ready() -> void:
	if theme in LOOKS:
		var look: Array = LOOKS[theme]
		var tex: Texture2D = look[0]
		var sprite: Sprite2D = $Sprite
		sprite.texture = tex
		sprite.scale = Vector2.ONE
		# the walkable part centred on the collision, its top at y = 0
		sprite.offset = Vector2(tex.get_width() * 0.5 - look[1], tex.get_height() * 0.5 - look[2])
	var start := position
	var t := create_tween().set_loops().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "position", start + move_by, travel_time)
	t.tween_interval(end_pause)
	t.tween_property(self, "position", start, travel_time)
	t.tween_interval(end_pause)
