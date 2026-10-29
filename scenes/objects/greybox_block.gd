@tool
class_name GreyboxBlock
extends StaticBody2D
## Placeholder ground for M1 level layouts. Set Size in the Inspector; the shape and colour follow.
## Origin = top-left corner, so blocks snap neatly to a grid.

@export var size: Vector2 = Vector2(512, 128):
	set(value):
		size = value
		_rebuild()
@export var one_way: bool = false:   ## you can jump up through it and land on top
	set(value):
		one_way = value
		_rebuild()

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	var shape_node: CollisionShape2D = get_node_or_null("Shape")
	var look: ColorRect = get_node_or_null("Look")
	if shape_node == null or look == null:
		return
	var rect := RectangleShape2D.new()
	rect.size = size
	shape_node.shape = rect
	shape_node.position = size / 2.0
	shape_node.one_way_collision = one_way
	look.size = size
	look.color = Color(0.62, 0.72, 0.55) if not one_way else Color(0.78, 0.68, 0.52)
