extends AnimatableBody2D
## Grass-topped plank that glides back and forth and carries the cat. Origin = middle of its top
## surface at the start point. One-way: she can jump up through it from below.

@export var move_by: Vector2 = Vector2(300, 0)   ## the far end, relative to where it's placed
@export var travel_time: float = 2.2             ## seconds for one trip
@export var end_pause: float = 0.5               ## rest at each end, so it's easy to step on/off

func _ready() -> void:
	var start := position
	var t := create_tween().set_loops().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "position", start + move_by, travel_time)
	t.tween_interval(end_pause)
	t.tween_property(self, "position", start, travel_time)
	t.tween_interval(end_pause)
