extends Node
## Which level is being played, the level catalog, and the running attempt (hearts, coins, yarn).

const CATALOG_PATH := "res://data/levels/level_catalog.tres"
const MAX_HEARTS := 3
const COINS_FOR_SECOND_STAR := 0.8   ## share of the level's coins needed for ★★

var catalog: LevelCatalog = preload(CATALOG_PATH)
var current_level_id: String = ""

# The running attempt. Reset each time a level starts (or restarts).
var hearts: int = MAX_HEARTS
var coins: int = 0
var coin_total: int = 0
var has_yarn: bool = false

func _ready() -> void:
	Events.coin_collected.connect(func(): coins += 1)
	Events.yarn_collected.connect(func(): has_yarn = true)

func current_level() -> LevelData:
	return catalog.get_level(current_level_id)

## Load a level by id with a fade (e.g. from the level map or "Next level").
func start_level(level_id: String) -> void:
	var level := catalog.get_level(level_id)
	if level == null:
		push_error("Unknown level id: %s" % level_id)
		return
	SceneTransition.change_scene(level.scene_path)

## The level the Play button should open: the first one not finished yet (or the last one).
func next_level_to_play() -> LevelData:
	for level in catalog.levels:
		if not SaveManager.is_done(level.id):
			return level
	return catalog.levels[-1]

## Called by the level when it loads.
func begin_attempt(level_id: String, coins_in_level: int) -> void:
	current_level_id = level_id
	hearts = MAX_HEARTS
	coins = 0
	coin_total = coins_in_level
	has_yarn = false
	Events.hearts_changed.emit(hearts)

## Returns true if the cat still has hearts left.
func lose_heart() -> bool:
	hearts = max(hearts - 1, 0)
	Events.hearts_changed.emit(hearts)
	return hearts > 0

## ★ reach the goal · ★★ at least 80 % of the coins · ★★★ the Golden Yarn.
func stars() -> int:
	var enough_coins := coin_total == 0 or coins >= ceili(coin_total * COINS_FOR_SECOND_STAR)
	return 1 + int(enough_coins) + int(has_yarn)
