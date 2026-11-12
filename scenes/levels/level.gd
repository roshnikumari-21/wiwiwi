class_name Level
extends Node2D
## Base script for every level. Puts the cat at the spawn point, fits the camera to the level's ground,
## and runs the level rules: hearts, checkpoints, the goal and stars.
## Each real level inherits level_base.tscn and only adds terrain and objects.

@export var level_id: String = ""            ## must match an id in the level catalog
@export var extra_sky: float = 700.0         ## how far the camera may look above the highest ground
@export var fall_margin: float = 400.0       ## falling this far below the lowest ground = fell in a pit
@export_range(0.0, 1.0) var start_energy: float = 1.0  ## the cat's energy at the start (lower = milk matters sooner)
## The world's look and music. The ground blocks carry the same theme (they're built in the editor).
@export_enum("meadow", "town", "forest") var theme: String = "meadow"

const THEMES := {
	"meadow": {"music": "mus_world1", "background": null},   # level_base.tscn already has the meadow
	"town": {"music": "mus_world2", "background": preload("res://scenes/levels/backgrounds/town_background.tscn")},
	"forest": {"music": "mus_world3", "background": preload("res://scenes/levels/backgrounds/forest_background.tscn")},
}

@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera
@onready var spawn: Marker2D = $PlayerSpawn
@onready var terrain: Node2D = $Terrain
@onready var hud: Hud = $Hud/SafeArea/Hud
@onready var touch_controls: Control = $Hud/SafeArea/TouchControls

var bounds: Rect2
var _fall_line: float
var _respawn_point: Vector2
var _over := false   ## true once the level is won or lost
const HURT_PAUSE := 0.7  ## seconds of the hurt pose before she reappears at the flag
const SINK_PAUSE := 0.8  ## seconds of sinking after a splash before she reappears at the flag

func _ready() -> void:
	bounds = _terrain_bounds()
	camera.limit_left = int(bounds.position.x)
	camera.limit_right = int(bounds.end.x)
	camera.limit_top = int(bounds.position.y - extra_sky)
	camera.limit_bottom = int(bounds.end.y)
	_fall_line = bounds.end.y + fall_margin

	Events.checkpoint_reached.connect(func(point: Vector2): _respawn_point = point)
	Events.player_hurt.connect(_on_hurt)
	Events.player_fell_in_water.connect(_on_fell_in_water)
	for goal in get_tree().get_nodes_in_group("goal"):
		goal.reached.connect(_on_goal_reached.bind(goal))
	hud.restart_pressed.connect(restart)
	hud.next_pressed.connect(_go_next)
	hud.map_pressed.connect(func(): SceneTransition.change_scene("res://ui/screens/level_map.tscn"))
	hud.home_pressed.connect(func(): SceneTransition.change_scene("res://ui/screens/main_menu.tscn"))

	var look: Dictionary = THEMES[theme]
	if look.background:
		var old := $Background
		remove_child(old)
		old.queue_free()
		var background: Node = look.background.instantiate()
		background.name = "Background"
		add_child(background)
	AudioManager.play_music(look.music)
	GameState.begin_attempt(level_id, get_tree().get_nodes_in_group("coins").size())
	_respawn_point = spawn.global_position
	player.energy = start_energy
	Events.energy_changed.emit(player.energy)
	_respawn()

func _physics_process(_delta: float) -> void:
	if not _over and not player.frozen and player.global_position.y > _fall_line:
		_on_fell()

## Fell in a pit: lose a heart. Back to the last flag if any hearts are left, otherwise the level is lost.
func _on_fell() -> void:
	AudioManager.play_sfx("sfx_hurt")
	if GameState.lose_heart():
		_respawn()
	else:
		_fail()

## Water in a pit: a splash, she sinks out of sight, then the same rule as a pit fall.
func _on_fell_in_water() -> void:
	if _over:
		return
	player.sink()
	await get_tree().create_timer(SINK_PAUSE).timeout
	if not _over:
		_on_fell()

## Spikes or an enemy: lose a heart, a short hurt pose, then back to the last flag (or the level is lost).
func _on_hurt() -> void:
	if _over or not player.can_be_hurt():
		return
	player.knock_back()
	AudioManager.play_sfx("sfx_hurt")
	Fx.spawn(player, &"heart", player.global_position + Vector2(0, -170), 0.55)
	if GameState.lose_heart():
		await get_tree().create_timer(HURT_PAUSE).timeout
		if not _over:
			_respawn()
	else:
		_fail()

func _fail() -> void:
	_over = true
	touch_controls.hide()
	player.give_up()
	Events.level_failed.emit()

func _on_goal_reached(goal: Node) -> void:
	if _over:
		return
	_over = true
	touch_controls.hide()
	var level_data := GameState.current_level()
	await goal.play_reunion(player, level_data != null and level_data.is_reunion)
	Events.level_completed.emit(GameState.stars(), GameState.coins, GameState.coin_total, GameState.has_yarn)

func _exit_tree() -> void:
	AudioManager.stop_purr()

func _respawn() -> void:
	player.respawn_at(_respawn_point)
	camera.reset_smoothing()

func _go_next() -> void:
	if GameState.map_walk_from == level_id:   # first time through: the map shows her walking on, then plays it
		GameState.map_auto_play = true
		SceneTransition.change_scene("res://ui/screens/level_map.tscn")
		return
	var next := GameState.catalog.next_after(level_id)
	if next:
		GameState.start_level(next.id)

## Play the level again from the start (fresh hearts, coins and flags).
func restart() -> void:
	SceneTransition.change_scene(scene_file_path)

## The rectangle covering all ground pieces, so the camera never shows past the level's edges.
func _terrain_bounds() -> Rect2:
	var rect := Rect2()
	var first := true
	for piece in terrain.get_children():
		if piece is GroundBlock:
			var r := Rect2(piece.global_position, piece.size)
			rect = r if first else rect.merge(r)
			first = false
	return rect
