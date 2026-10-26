extends CanvasLayer

var score: int = 0
var total_coins: int = 0

# @onready grabs the node once the scene is ready, so we don't repeat $ScoreLabel.
@onready var score_label: Label = $ScoreLabel
@onready var win_label: Label = $WinLabel
@onready var energy_bar: ProgressBar = $EnergyBar

const ENERGY_OK_COLOR := Color(0.62, 0.86, 0.7)    # minty green
const ENERGY_LOW_COLOR := Color(0.96, 0.55, 0.55)  # soft red

func _ready() -> void:
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
