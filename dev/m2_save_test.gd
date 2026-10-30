extends SceneTree
## Headless check of the save system: unlocks, best results, safe writes, backup, migration, settings.
## Uses its own files in user://, so the real save is never touched.
## Run: godot --headless --path . --script res://dev/m2_save_test.gd

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var save = root.get_node("SaveManager")
	var events = root.get_node("Events")
	var gs = root.get_node("GameState")
	save.save_path = "user://test_save.json"
	save.settings_path = "user://test_settings.cfg"
	for f in ["user://test_save.json", "user://test_save.json.bak", "user://test_settings.cfg"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	save.load_game()
	save.load_settings()

	_check("fresh: only 1-1 is open", save.is_unlocked("w1_01") and not save.is_unlocked("w1_02") and not save.is_unlocked("w1_03"), "")
	_check("fresh: shop slots exist (wallet, cosmetics)", save._data.has("wallet") and save._data.has("cosmetics"), save._data)

	save.record_result("w1_01", 2, 14, false)
	_check("finishing 1-1 opens 1-2 only", save.is_unlocked("w1_02") and not save.is_unlocked("w1_03"), "")
	save.record_result("w1_01", 1, 9, true)
	_check("best result kept (2 stars, 14 coins), yarn stays found", save.stars("w1_01") == 2 and save._level("w1_01").best_coins == 14 and save.has_yarn("w1_01"), save._level("w1_01"))

	save.load_game()   # as if the app was closed and opened again
	_check("progress survives a restart", save.is_done("w1_01") and save.stars("w1_01") == 2, save._level("w1_01"))

	save.record_result("w1_02", 3, 19, true)   # second save: the first one becomes the .bak
	var f := FileAccess.open("user://test_save.json", FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	save.load_game()
	_check("damaged save: backup is used", save.is_done("w1_01") and save.stars("w1_01") == 2, save._data)

	f = FileAccess.open("user://test_save.json", FileAccess.WRITE)
	f.store_string('{"levels": {"w1_01": {"done": true, "stars": 3}}}')   # an old save without a version
	f.close()
	save.load_game()
	_check("old save upgraded to the current version", save._data.version == save.VERSION and save._data.has("wallet") and save.stars("w1_01") == 3, save._data)

	save.reset_progress()
	gs.current_level_id = "w1_03"
	events.level_completed.emit(1, 10, 21, false)
	_check("finishing a level saves it automatically", save.is_done("w1_03") and save.stars("w1_03") == 1, save._level("w1_03"))

	_check("settings default: music + sound on", save.get_setting("music_on") == true and save.get_setting("sound_on") == true, "")
	save.set_setting("music_on", false)
	save.load_settings()
	_check("settings survive a restart", save.get_setting("music_on") == false, save.get_setting("music_on"))

	for path in ["user://test_save.json", "user://test_save.json.bak", "user://test_settings.cfg"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", name, str(got) if not ok else ""])
