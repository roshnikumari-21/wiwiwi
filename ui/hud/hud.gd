class_name Hud
extends Control
## In-level HUD: hearts, coins and the Golden Yarn in the top-left corner,
## plus the end-of-level card (stars or "out of hearts"). Placeholder look; real screens come in M2.

signal restart_pressed
signal next_pressed
signal map_pressed

const HEART_FULL := preload("res://assets/art/objects/heart_full.png")
const HEART_EMPTY := preload("res://assets/art/objects/heart_empty.png")
const STAR_FULL := preload("res://assets/art/objects/star_full.png")
const STAR_EMPTY := preload("res://assets/art/objects/star_empty.png")
const YARN_MISSING_TINT := Color(0.2, 0.2, 0.25, 0.45)
const ENERGY_LOW := 0.25                         ## below this the bar turns orange as a warning
const ENERGY_LOW_TINT := Color(1.0, 0.62, 0.35)

@onready var _hearts: Array[Node] = $Top/Hearts.get_children()
@onready var _coin_label: Label = $Top/CoinLabel
@onready var _yarn: TextureRect = $Top/Yarn
@onready var _energy_bar: ProgressBar = $Energy/Bar
@onready var _card: Control = $Card
var _fps: Label   ## test builds only: frames per second, for the performance check
@onready var _title: Label = $Card/Center/Panel/Box/Title
@onready var _stars: Array[Node] = $Card/Center/Panel/Box/Stars.get_children()
@onready var _card_coins: Label = $Card/Center/Panel/Box/Coins
@onready var _button: Button = $Card/Center/Panel/Box/Buttons/Again
@onready var _next: Button = $Card/Center/Panel/Box/Buttons/Next

func _ready() -> void:
	_card.hide()
	_yarn.modulate = YARN_MISSING_TINT
	Events.hearts_changed.connect(_show_hearts)
	Events.coin_collected.connect(_show_coins)  # GameState connected first, so it has already counted it
	Events.yarn_collected.connect(_on_yarn)
	Events.energy_changed.connect(_show_energy)
	Events.milk_drunk.connect(_on_milk)
	Events.level_completed.connect(_on_completed)
	Events.level_failed.connect(_on_failed)
	_button.pressed.connect(restart_pressed.emit)
	_next.pressed.connect(next_pressed.emit)
	$Card/Center/Panel/Box/Buttons/Map.pressed.connect(map_pressed.emit)
	_show_hearts(GameState.hearts)
	_show_coins.call_deferred()
	if OS.is_debug_build():
		_fps = Label.new()
		_fps.add_theme_font_size_override("font_size", 28)
		_fps.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 0.7))
		_fps.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_fps.position += Vector2(-150, 10)
		add_child(_fps)

func _process(_delta: float) -> void:
	if _fps:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()  # the level counts its coins right after the HUD is ready

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

func _on_completed(stars: int, coins: int, coin_total: int, _has_yarn: bool) -> void:
	_title.text = tr("RESULT_WIN")
	_card_coins.text = tr("RESULT_COINS") % [coins, coin_total]
	_card_coins.show()
	_button.text = tr("RESULT_REPLAY")
	for i in _stars.size():
		_stars[i].texture = STAR_FULL if i < stars else STAR_EMPTY
	$Card/Center/Panel/Box/Stars.show()
	_next.visible = GameState.catalog.next_after(GameState.current_level_id) != null
	_open_card()

func _on_failed() -> void:
	_title.text = tr("RESULT_FAIL")
	$Card/Center/Panel/Box/Stars.hide()
	_card_coins.hide()
	_button.text = tr("RESULT_RETRY")
	_open_card()

func _open_card() -> void:
	_card.modulate.a = 0.0
	_card.show()
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.3).set_delay(0.6)
	(_next if _next.visible else _button).grab_focus.call_deferred()
