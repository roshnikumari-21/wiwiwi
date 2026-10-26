extends CanvasLayer

var score: int = 0
var total_coins: int = 0

# @onready grabs the node once the scene is ready, so we don't repeat $ScoreLabel.
@onready var score_label: Label = $ScoreLabel
@onready var win_label: Label = $WinLabel

func _ready() -> void:
	# Find every coin (they're all in the "coins" group) and listen to its signal.
	var coins := get_tree().get_nodes_in_group("coins")
	total_coins = coins.size()
	for coin in coins:
		coin.collected.connect(_on_coin_collected)
	update_label()

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
