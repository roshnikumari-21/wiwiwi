class_name Hud
extends Control
## In-level HUD: hearts, coins and the Golden Yarn in the top-left corner,
## plus the end-of-level card (stars or "out of hearts"). Placeholder look; real screens come in M2.

signal restart_pressed

const HEART_FULL := preload("res://assets/art/objects/heart_full.png")
const HEART_EMPTY := preload("res://assets/art/objects/heart_empty.png")
const STAR_FULL := preload("res://assets/art/objects/star_full.png")
const STAR_EMPTY := preload("res://assets/art/objects/star_empty.png")
const YARN_MISSING_TINT := Color(0.2, 0.2, 0.25, 0.45)

@onready var _hearts: Array[Node] = $Top/Hearts.get_children()
@onready var _coin_label: Label = $Top/CoinLabel
@onready var _yarn: TextureRect = $Top/Yarn
@onready var _card: Control = $Card
@onready var _title: Label = $Card/Center/Panel/Box/Title
@onready var _stars: Array[Node] = $Card/Center/Panel/Box/Stars.get_children()
@onready var _card_coins: Label = $Card/Center/Panel/Box/Coins
@onready var _button: Button = $Card/Center/Panel/Box/Again

func _ready() -> void:
	_card.hide()
	_yarn.modulate = YARN_MISSING_TINT
	Events.hearts_changed.connect(_show_hearts)
	Events.coin_collected.connect(_show_coins)  # GameState connected first, so it has already counted it
	Events.yarn_collected.connect(_on_yarn)
	Events.level_completed.connect(_on_completed)
	Events.level_failed.connect(_on_failed)
	_button.pressed.connect(restart_pressed.emit)
	_show_hearts(GameState.hearts)
	_show_coins.call_deferred()  # the level counts its coins right after the HUD is ready

func _show_hearts(hearts: int) -> void:
	for i in _hearts.size():
		_hearts[i].texture = HEART_FULL if i < hearts else HEART_EMPTY

func _show_coins() -> void:
	_coin_label.text = "%d / %d" % [GameState.coins, GameState.coin_total]

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
	_button.grab_focus.call_deferred()
