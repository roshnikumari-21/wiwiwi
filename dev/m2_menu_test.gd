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
	menu.get_node("Stage/Play").pressed.emit()
	for i in 60:
		await process_frame
	_check("Play opens the level map", current_scene != null and current_scene.name == "LevelMap", current_scene)
	var map = current_scene
	_check("map: 1-1 and 1-2 open, 1-3 locked", map.get_node("Map/Level2").texture_normal == map.OPEN and map.get_node("Map/Level3").texture_normal == map.LOCKED, "")
	_check("map: 1-1 shows 3 stars", map.get_node("Map/Level1").get_children().filter(func(n): return n is TextureRect and n.texture == map.STAR_FULL).size() == 3, "")
	_check("map: spots after the built levels are locked", map.get_node("Map/Level10").texture_normal == map.LOCKED, "")
	_check("map: kitten waits on level 2", map.get_node("Map/Kitten").position.x == map.WORLDS[0].spots[1].x, map.get_node("Map/Kitten").position)
	map.get_node("Map/Level3").pressed.emit()   # locked: nothing happens
	for i in 30:
		await process_frame
	_check("map: tapping a locked level does nothing", current_scene == map, current_scene)
	map.get_node("Map/Level2").pressed.emit()
	for i in 60:
		await process_frame
	_check("map: tapping level 2 opens 1-2", current_scene != null and current_scene.get("level_id") == "w1_02", current_scene)
	current_scene.get_node("Hud/SafeArea/Hud").map_pressed.emit()
	for i in 60:
		await process_frame
	_check("result card Map button returns to the map", current_scene != null and current_scene.name == "LevelMap", current_scene)

	save.record_result("w1_10", 3, 27, true)
	change_scene_to_file("res://ui/screens/main_menu.tscn")
	for i in 10:
		await process_frame
	_check("after World 1 the home page still shows the kitten alone (owner decision)", current_scene.get_node_or_null("Stage/Reunited") == null and current_scene.get_node("Stage/Kitten").visible, "")

	for path in ["user://test_menu_save.json", "user://test_menu_save.json.bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", name, str(got) if not ok else ""])
