extends SceneTree
## Headless check of the pause menu and result popups in a level.
## Run: godot --headless --path . --script res://dev/m2_popups_test.gd

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var save = root.get_node("SaveManager")
	save.save_path = "user://test_popups_save.json"
	save.reset_progress()
	change_scene_to_file("res://scenes/levels/w1/level_w1_01.tscn")
	await _frames(10)
	var level = current_scene
	var hud = level.get_node("Hud/SafeArea/Hud")
	var player = level.get_node("Player")

	Input.action_press("move_right")
	await _frames(10)
	hud.get_node("Pause").pressed.emit()
	await _frames(2)
	var x: float = player.global_position.x
	await _frames(30)
	_check("pause: game stops", paused and player.global_position.x == x, player.global_position.x - x)
	_check("pause: menu shows Resume/Restart/Map/Home", ["BTN_RESUME", "BTN_RESTART", "RESULT_MAP", "BTN_HOME"].all(func(n): return hud.menu.find_child(n, true, false) != null), "")
	_check("pause: held button released", not Input.is_action_pressed("move_right"), "")
	hud.menu.find_child("BTN_RESUME", true, false).pressed.emit()
	await _frames(5)
	_check("resume: game runs again, menu gone", not paused and not hud.menu.visible, "")

	hud.pause()
	hud.menu.find_child("BTN_HOME", true, false).pressed.emit()
	await _frames(60)
	_check("Home from pause opens the home page", current_scene.name == "MainMenu" and not paused, current_scene.name)

	change_scene_to_file("res://scenes/levels/w1/level_w1_01.tscn")
	await _frames(10)
	level = current_scene
	hud = level.get_node("Hud/SafeArea/Hud")
	root.get_node("Events").level_completed.emit(2, 13, 16, true)
	await _frames(5)
	_check("complete popup: Map, Replay, Next", ["RESULT_MAP", "RESULT_REPLAY", "RESULT_NEXT"].all(func(n): return hud.menu.find_child(n, true, false) != null), "")
	_check("complete popup: coins 13 / 16", hud.menu.find_child("Coins", true, false).text == "13 / 16", "")
	_check("pause button hidden after the level ends", not hud.get_node("Pause").visible, "")
	hud.pause()
	_check("can't pause over the result popup", not paused, "")
	var first_time: bool = root.get_node("GameState").map_walk_from == "w1_01"
	hud.menu.find_child("RESULT_NEXT", true, false).pressed.emit()
	await _frames(60)
	if first_time:   # a first finish goes via the map: the kitten walks to 1-2, then it starts
		_check("Next after a first finish: the map walks on", current_scene.name == "LevelMap", current_scene.name)
		await create_timer(4.0).timeout
		await _frames(30)
	_check("Next opens level 1-2", current_scene.get("level_id") == "w1_02", current_scene.name)

	for path in ["user://test_popups_save.json", "user://test_popups_save.json.bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", name, str(got) if not ok else ""])
