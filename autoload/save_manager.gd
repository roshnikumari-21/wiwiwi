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
	record_result(GameState.current_level_id, star_count, coins, yarn)

func _level(level_id: String) -> Dictionary:
	return _data["levels"].get(level_id, {})

func _fresh() -> Dictionary:
	# wallet + cosmetics are empty slots for a future shop, so it needs no save migration.
	return {"version": VERSION, "levels": {}, "wallet": {"coins": 0}, "cosmetics": []}

## Bring an older save up to the current version, step by step.
func _migrate(data: Dictionary) -> Dictionary:
	var fresh := _fresh()
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
