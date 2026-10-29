extends Node2D
## M1 movement test room: respawns the cat if she falls, and shows live numbers for tuning.

@onready var player: Player = $Player
@onready var readout: Label = %Readout
var _spawn: Vector2

func _ready() -> void:
	_spawn = player.global_position

func _physics_process(_delta: float) -> void:
	if player.global_position.y > 1500.0:
		player.global_position = _spawn
		player.velocity = Vector2.ZERO
		player.get_node("Camera").reset_smoothing()

func _process(_delta: float) -> void:
	readout.text = "FPS %d   speed %4d   %s   %s" % [
		Engine.get_frames_per_second(),
		roundi(abs(player.velocity.x)),
		"ground" if player.is_on_floor() else "air",
		player.sprite.animation,
	]
