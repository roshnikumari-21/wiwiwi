extends SceneTree
## Headless check of the Android Back button on every screen.
## Run: godot --headless --path . --script res://dev/m2_back_test.gd

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _back() -> void:
	current_scene.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(5)

func _run() -> void:
	var save = root.get_node("SaveManager")
	save.save_path = "user://test_back_save.json"
	save.reset_progress()

	change_scene_to_file("res://ui/screens/main_menu.tscn")
	await _frames(10)
	var home = current_scene
	home.get_node("Stage/Settings").pressed.emit()
	await _frames(3)
	await _back()
	_check("home: Back closes Settings", not home.menu.visible, home.menu.current)
	await _back()
	_check("home: Back asks 'Leave wiwiwi?'", home.menu.current == "quit" and home.menu.visible, home.menu.current)
	home.menu.find_child("BTN_STAY", true, false).pressed.emit()
	await _frames(3)
	_check("Stay closes the question", not home.menu.visible, "")
	await _back()
	await _back()
	_check("Back on the question closes it", not home.menu.visible, "")

	change_scene_to_file("res://ui/screens/level_map.tscn")
	await _frames(10)
	await _back()
	await _frames(60)
	_check("map: Back goes home", current_scene.name == "MainMenu", current_scene.name)

	change_scene_to_file("res://scenes/levels/w1/level_w1_01.tscn")
	await _frames(10)
	var hud = current_scene.get_node("Hud/SafeArea/Hud")
	await _back()
	_check("level: Back pauses", paused and hud.menu.current == "pause", hud.menu.current)
	hud.menu.find_child("SETTINGS_TITLE", true, false).pressed.emit()
	await _frames(3)
	await _back()
	_check("settings (from pause): Back returns to pause", hud.menu.current == "pause" and paused, hud.menu.current)
	await _back()
	_check("pause: Back resumes", not paused and not hud.menu.visible, "")
	root.get_node("Events").level_failed.emit()
	await _frames(5)
	await _back()
	await _frames(60)
	_check("try again: Back goes to the map", current_scene.name == "LevelMap", current_scene.name)

	for path in ["user://test_back_save.json", "user://test_back_save.json.bak"]:
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
