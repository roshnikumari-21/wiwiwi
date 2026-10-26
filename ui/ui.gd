extends CanvasLayer

# Shown in the top-right corner. Each level sets its own (see the UI node in level_1.tscn).
@export var level_title: String = "Level 1"

var score: int = 0
var total_coins: int = 0
var owner_node: Node = null

# @onready grabs the node once the scene is ready, so we don't repeat $ScoreLabel.
@onready var score_label: Label = $ScoreLabel
@onready var win_label: Label = $WinLabel
@onready var energy_bar: ProgressBar = $EnergyBar

const ENERGY_OK_COLOR := Color(0.62, 0.86, 0.7)    # minty green
const ENERGY_LOW_COLOR := Color(0.96, 0.55, 0.55)  # soft red

func _ready() -> void:
	$LevelLabel.text = level_title

	# Find every coin (they're all in the "coins" group) and listen to its signal.
	var coins := get_tree().get_nodes_in_group("coins")
	total_coins = coins.size()
	for coin in coins:
		coin.collected.connect(_on_coin_collected)
	update_label()

	# Listen to the cat's energy, and show its starting value right away.
	var player = get_tree().get_first_node_in_group("player")
	player.energy_changed.connect(_on_energy_changed)
	_on_energy_changed(player.energy, player.max_energy)

	# Listen for the cat reaching her owner (only if this level has one).
	owner_node = get_tree().get_first_node_in_group("owner")
	if owner_node:
		owner_node.finished.connect(_on_finished)

func _on_finished() -> void:
	win_label.hide()  # the finish message replaces the coins message
	var finish_label: Label = $FinishLabel
	# Is there another level after this one?
	var last_line := "On to the next level..." if owner_node.next_level != "" else "Thanks for playing!"
	finish_label.text = "Home at last!\nCoins: %d / %d\n%s" % [score, total_coins, last_line]
	finish_label.modulate.a = 0.0
	finish_label.show()
	var tween := create_tween()
	tween.tween_interval(0.6)  # let the hug happen first
	tween.tween_property(finish_label, "modulate:a", 1.0, 0.6)

# The signal hands us two values: the current energy and the maximum.
func _on_energy_changed(current: float, maximum: float) -> void:
	energy_bar.max_value = maximum
	energy_bar.value = current
	var fill: StyleBoxFlat = energy_bar.get_theme_stylebox("fill")
	fill.bg_color = ENERGY_LOW_COLOR if current < maximum * 0.25 else ENERGY_OK_COLOR

# Called each time any coin emits "collected".
func _on_coin_collected() -> void:
	score += 1
	update_label()
	if score == total_coins:
		show_win_message()

func show_win_message() -> void:
	# Start invisible, then fade in over 0.6 seconds.
	win_label.modulate.a = 0.0
	win_label.show()
	create_tween().tween_property(win_label, "modulate:a", 1.0, 0.6)

func update_label() -> void:
	score_label.text = "Coins: %d" % score
