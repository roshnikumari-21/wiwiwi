class_name Level
extends Node2D
## Base script for every level. Puts the cat at the spawn point, fits the camera to the level's ground,
## and catches falls. Each real level inherits level_base.tscn and only adds terrain and objects.

@export var level_id: String = ""            ## must match an id in the level catalog
@export var extra_sky: float = 700.0         ## how far the camera may look above the highest ground
@export var fall_margin: float = 400.0       ## falling this far below the lowest ground = fell in a pit

@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera
@onready var spawn: Marker2D = $PlayerSpawn
@onready var terrain: Node2D = $Terrain

var bounds: Rect2
var _fall_line: float

func _ready() -> void:
	GameState.current_level_id = level_id
	bounds = _terrain_bounds()
	camera.limit_left = int(bounds.position.x)
	camera.limit_right = int(bounds.end.x)
	camera.limit_top = int(bounds.position.y - extra_sky)
	camera.limit_bottom = int(bounds.end.y)
	_fall_line = bounds.end.y + fall_margin
	respawn()

func _physics_process(_delta: float) -> void:
	if player.global_position.y > _fall_line:
		respawn()  # M1 placeholder; hearts and checkpoints replace this in the next step

func respawn() -> void:
	player.global_position = spawn.global_position
	player.velocity = Vector2.ZERO
	camera.reset_smoothing()

## The rectangle covering all ground pieces, so the camera never shows past the level's edges.
func _terrain_bounds() -> Rect2:
	var rect := Rect2()
	var first := true
	for piece in terrain.get_children():
		if piece is GreyboxBlock:
			var r := Rect2(piece.global_position, piece.size)
			rect = r if first else rect.merge(r)
			first = false
	return rect
