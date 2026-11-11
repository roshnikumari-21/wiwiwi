extends AnimatableBody2D
## Plank that glides back and forth and carries the cat. Origin = middle of its top surface at the
## start point. One-way: she can jump up through it from below.
## Theme: "meadow" = grass-topped log (World 1), "town" = wooden ledge on stone brackets (World 2).

const TOWN_PLANK := preload("res://assets/art/objects/platform_moving_town.png")
const TOWN_BOARDS_CENTRE_X := 152.0   ## where the boards' middle is in the picture (make_town.py); the lantern hangs off one end

@export var move_by: Vector2 = Vector2(300, 0)   ## the far end, relative to where it's placed
@export var travel_time: float = 2.2             ## seconds for one trip
@export var end_pause: float = 0.5               ## rest at each end, so it's easy to step on/off
@export_enum("meadow", "town") var theme: String = "meadow"

func _ready() -> void:
	if theme == "town":
		var sprite: Sprite2D = $Sprite
		sprite.texture = TOWN_PLANK
		sprite.scale = Vector2.ONE
		# boards centred on the collision, their top (the walkable plank) at y = 0
		sprite.offset = Vector2(TOWN_PLANK.get_width() * 0.5 - TOWN_BOARDS_CENTRE_X, TOWN_PLANK.get_height() * 0.5)
	var start := position
	var t := create_tween().set_loops().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "position", start + move_by, travel_time)
	t.tween_interval(end_pause)
	t.tween_property(self, "position", start, travel_time)
	t.tween_interval(end_pause)
