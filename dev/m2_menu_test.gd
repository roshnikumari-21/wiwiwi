extends SceneTree
## Headless check of the home page: it loads, and Play opens the first level not finished yet.
## Uses its own save files, so the real save is never touched.
## Run: godot --headless --path . --script res://dev/m2_menu_test.gd

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var save = root.get_node("SaveManager")
	save.save_path = "user://test_menu_save.json"
	save.reset_progress()
	_check("new player: Play opens 1-1", root.get_node("GameState").next_level_to_play().id == "w1_01", "")
	save.record_result("w1_01", 3, 16, true)
	_check("after 1-1: Play opens 1-2", root.get_node("GameState").next_level_to_play().id == "w1_02", "")

	change_scene_to_file("res://ui/screens/main_menu.tscn")
	for i in 10:
		await process_frame
	var menu = current_scene
	_check("home page loads", menu != null and menu.name == "MainMenu", menu)
	menu.get_node("UI/SafeArea/Play").pressed.emit()
	for i in 60:
		await process_frame
	_check("Play opens level 1-2", current_scene != null and current_scene.get("level_id") == "w1_02", current_scene)

	for path in ["user://test_menu_save.json", "user://test_menu_save.json.bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", name, str(got) if not ok else ""])
