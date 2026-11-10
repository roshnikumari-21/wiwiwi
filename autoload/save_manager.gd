extends Node
## Local save, no server: progress in user://save.json (versioned) and device settings in
## user://settings.cfg. Writes are safe: a temp file is written first and swapped in, and the
## previous save is kept as a .bak, so a crash or a flat battery mid-save can't lose progress.

signal progress_changed
signal settings_changed(key: String, value)

const VERSION := 1
const DEFAULT_SETTINGS := {
	"music_on": true,
	"sound_on": true,
	"controls_size": 1.0,   ## touch-button size, 0.6..1.4
}

var save_path := "user://save.json"        ## tests point these somewhere else
var settings_path := "user://settings.cfg"

var _data: Dictionary
var _settings := ConfigFile.new()

func _ready() -> void:
	load_game()
	load_settings()
	Events.level_completed.connect(_on_level_completed)
	Events.enemy_stomped.connect(func(): _add_stat("slimes", 1))

# --- Progress -------------------------------------------------------------------------------

func load_game() -> void:
	var loaded = _read_json(save_path)
	if loaded == null:
		loaded = _read_json(save_path + ".bak")   # the main file was damaged: use the backup
	_data = _migrate(loaded) if loaded is Dictionary else _fresh()

func is_done(level_id: String) -> bool:
	return _level(level_id).get("done", false)

func stars(level_id: String) -> int:
	return _level(level_id).get("stars", 0)

func has_yarn(level_id: String) -> bool:
	return _level(level_id).get("yarn", false)

## The first level is always open; every other level opens when the one before it is done.
func is_unlocked(level_id: String) -> bool:
	var levels: Array = GameState.catalog.levels
	for i in levels.size():
		if levels[i].id == level_id:
			return i == 0 or is_done(levels[i - 1].id)
	return false

## Keeps the best result: stars and coins never go down, a found Golden Yarn stays found.
func record_result(level_id: String, star_count: int, coins: int, yarn: bool) -> void:
	var old := _level(level_id)
	_data["levels"][level_id] = {
		"done": true,
		"stars": maxi(old.get("stars", 0), star_count),
		"best_coins": maxi(old.get("best_coins", 0), coins),
		"yarn": old.get("yarn", false) or yarn,
	}
	save_game()
	progress_changed.emit()

# --- Cat Shop -------------------------------------------------------------------------------
# "cosmetics" lists the cats bought; the ginger kitten is everyone's from the start.

func owns_cat(id: String) -> bool:
	return id == CatSkins.DEFAULT or id in _data["cosmetics"]

func chosen_cat() -> String:
	return _data.get("cat", CatSkins.DEFAULT)

## Pays and adds the cat, then chooses it. False (nothing changes) if the purse is too light.
func buy_cat(id: String) -> bool:
	if owns_cat(id):
		return true
	if not spend_coins(CatSkins.find(id).price):
		return false
	_data["cosmetics"].append(id)
	choose_cat(id)
	return true

func choose_cat(id: String) -> void:
	if not owns_cat(id):
		return
	_data["cat"] = id
	save_game()
	progress_changed.emit()

func save_game() -> void:
	var tmp := save_path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("Can't write save: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(_data, "\t"))
	file.close()
	if FileAccess.file_exists(save_path):
		DirAccess.rename_absolute(save_path, save_path + ".bak")
	DirAccess.rename_absolute(tmp, save_path)

## Start over (used by tests; a "reset progress" option could use it later).
func reset_progress() -> void:
	_data = _fresh()
	save_game()
	progress_changed.emit()

func _on_level_completed(star_count: int, coins: int, _coin_total: int, yarn: bool) -> void:
	_data["wallet"]["coins"] = purse() + coins   # record_result below saves it
	_data["stats"]["coins_ever"] = stat("coins_ever") + coins
	if GameState.hearts == GameState.MAX_HEARTS:
		_data["stats"]["flawless"] = 1   # finished a level without losing a heart
	record_result(GameState.current_level_id, star_count, coins, yarn)

## Stars won over all levels, and how many there are to win (3 per level).
func total_stars() -> Vector2i:
	var levels: Array = GameState.catalog.levels
	var got := 0
	for level in levels:
		got += stars(level.id)
	return Vector2i(got, levels.size() * 3)

## Golden Yarns found, and how many there are (1 per level).
func total_yarns() -> Vector2i:
	var levels: Array = GameState.catalog.levels
	var got := 0
	for level in levels:
		got += int(has_yarn(level.id))
	return Vector2i(got, levels.size())

# --- Lifetime stats (for Play Games achievements and leaderboards) ---------------------------
# coins_ever = every coin picked up in finished levels (never goes down, unlike the purse),
# slimes = slimes squished, flawless = 1 once a level was finished with all hearts.

func stat(key: String) -> int:
	return int(_data["stats"].get(key, 0))

func _add_stat(key: String, amount: int) -> void:
	_data["stats"][key] = stat(key) + amount
	save_game()
	progress_changed.emit()

# --- Coin purse -----------------------------------------------------------------------------
# Every coin picked up in a finished level goes in the purse (replays earn more), to spend in the
# Cat Shop. Coins from a level that wasn't finished are not kept.

func purse() -> int:
	return int(_data["wallet"].get("coins", 0))

func add_coins(amount: int) -> void:
	_data["wallet"]["coins"] = purse() + amount
	save_game()
	progress_changed.emit()

## Takes the coins if there are enough; returns false (and takes nothing) if not.
func spend_coins(amount: int) -> bool:
	if amount > purse():
		return false
	_data["wallet"]["coins"] = purse() - amount
	save_game()
	progress_changed.emit()
	return true

func _level(level_id: String) -> Dictionary:
	return _data["levels"].get(level_id, {})

func _fresh() -> Dictionary:
	# New keys added later (wallet, cosmetics, cat, stats) are filled in by _migrate for old saves.
	return {"version": VERSION, "levels": {}, "wallet": {"coins": 0}, "cosmetics": [], "cat": "ginger",
		"stats": {"coins_ever": 0, "slimes": 0, "flawless": 0}}

## Bring an older save up to the current version, step by step.
func _migrate(data: Dictionary) -> Dictionary:
	var fresh := _fresh()
	if not data.has("stats") and data.has("wallet"):   # saves from before the stats: count the purse as earned
		fresh["stats"]["coins_ever"] = int(data["wallet"].get("coins", 0))
	for key in fresh:
		if not data.has(key):
			data[key] = fresh[key]
	data["version"] = VERSION
	return data

func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else null

# --- Settings -------------------------------------------------------------------------------

func load_settings() -> void:
	_settings = ConfigFile.new()
	_settings.load(settings_path)   # a missing file just means defaults

func get_setting(key: String):
	return _settings.get_value("settings", key, DEFAULT_SETTINGS.get(key))

func set_setting(key: String, value) -> void:
	_settings.set_value("settings", key, value)
	_settings.save(settings_path)
	settings_changed.emit(key, value)
