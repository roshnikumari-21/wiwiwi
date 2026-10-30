class_name Hud
extends Control
## In-level HUD: hearts, coins and the Golden Yarn top-left, energy below, pause button top-right.
## Owns the popups (Paused / Level complete! / Try again?) and pausing the game.

signal restart_pressed
signal next_pressed
signal map_pressed
signal home_pressed

const HEART_FULL := preload("res://assets/art/objects/heart_full.png")
const HEART_EMPTY := preload("res://assets/art/objects/heart_empty.png")
const YARN_MISSING_TINT := Color(0.2, 0.2, 0.25, 0.45)
const ENERGY_LOW := 0.25                         ## below this the bar turns orange as a warning
const ENERGY_LOW_TINT := Color(1.0, 0.62, 0.35)

@onready var _hearts: Array[Node] = $Top/Hearts.get_children()
@onready var _coin_label: Label = $Top/CoinLabel
@onready var _yarn: TextureRect = $Top/Yarn
@onready var _energy_bar: ProgressBar = $Energy/Bar
@onready var _pause_button: TextureButton = $Pause
var menu: GameMenu
var _fps: Label   ## test builds only: frames per second, for the performance check
var _over := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # the pause button and popups work while paused
	_yarn.modulate = YARN_MISSING_TINT
	Events.hearts_changed.connect(_show_hearts)
	Events.coin_collected.connect(_show_coins)  # GameState connected first, so it has already counted it
	Events.yarn_collected.connect(_on_yarn)
	Events.energy_changed.connect(_show_energy)
	Events.milk_drunk.connect(_on_milk)
	Events.level_completed.connect(_on_completed)
	Events.level_failed.connect(_on_failed)
	_show_hearts(GameState.hearts)
	_show_coins.call_deferred()  # the level counts its coins right after the HUD is ready

	menu = GameMenu.new()
	menu.name = "Menu"
	add_child(menu)
	menu.resume_pressed.connect(resume)
	menu.restart_pressed.connect(_leave.bind(restart_pressed))
	menu.next_pressed.connect(_leave.bind(next_pressed))
	menu.map_pressed.connect(_leave.bind(map_pressed))
	menu.home_pressed.connect(_leave.bind(home_pressed))
	_pause_button.pressed.connect(pause)

	if OS.is_debug_build():
		_fps = Label.new()
		_fps.add_theme_font_size_override("font_size", 28)
		_fps.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 0.7))
		_fps.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_fps.position += Vector2(-290, 10)
		add_child(_fps)

func _process(_delta: float) -> void:
	if _fps:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()

## Phone call, home button, notification shade: the game pauses itself.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		pause()

func pause() -> void:
	if _over or get_tree().paused:
		return
	for action in ["move_left", "move_right", "jump"]:
		Input.action_release(action)   # a finger held on a button mustn't keep the cat running
	get_tree().paused = true
	_pause_button.hide()
	menu.show_pause()

func resume() -> void:
	menu.close()
	_pause_button.show()
	get_tree().paused = false

func is_paused() -> bool:
	return get_tree().paused

## Leaving the level (restart / next / map / home): unpause first so the scene change can run.
func _leave(choice: Signal) -> void:
	get_tree().paused = false
	choice.emit()

func _show_hearts(hearts: int) -> void:
	for i in _hearts.size():
		_hearts[i].texture = HEART_FULL if i < hearts else HEART_EMPTY

func _show_coins() -> void:
	_coin_label.text = "%d / %d" % [GameState.coins, GameState.coin_total]

func _show_energy(energy: float) -> void:
	_energy_bar.value = energy
	_energy_bar.modulate = ENERGY_LOW_TINT if energy < ENERGY_LOW else Color.WHITE

func _on_milk() -> void:
	var icon: Control = $Energy/MilkIcon
	icon.pivot_offset = icon.size * 0.5
	var pop := create_tween()
	pop.tween_property(icon, "scale", Vector2(1.35, 1.35), 0.12)
	pop.tween_property(icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)

func _on_yarn() -> void:
	_yarn.modulate = Color.WHITE
	var pop := create_tween()
	pop.tween_property(_yarn, "scale", Vector2(1.4, 1.4), 0.12)
	pop.tween_property(_yarn, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)

func _on_completed(stars: int, coins: int, coin_total: int, has_yarn: bool) -> void:
	_end()
	menu.show_complete(stars, coins, coin_total, has_yarn, GameState.catalog.next_after(GameState.current_level_id) != null)

func _on_failed() -> void:
	_end()
	menu.show_fail()

func _end() -> void:
	_over = true
	_pause_button.hide()
