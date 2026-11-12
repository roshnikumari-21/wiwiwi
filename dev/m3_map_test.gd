extends SceneTree
## Level map with worlds: it opens on the world of the next level, ◀ ▶ switch worlds (◀ hidden on
## World 1, ▶ hidden on the last world), the sign names the world, each world shows its 10 spots
## and its girl, and a world's levels stay locked until the previous world is finished.
## Run: godot --headless --path . --script res://dev/m3_map_test.gd

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var save = root.get_node("SaveManager")
	save.save_path = "user://map_test.json"
	save.reset_progress()
	save.record_result("w1_01", 3, 20, true)

	var map = load("res://ui/screens/level_map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	var prev: Control = map.find_child("PreviousWorld", true, false)
	var next: Control = map.find_child("NextWorld", true, false)
	_check("a new player's map opens on World 1", map.world == 1, map.world)
	_check("World 1: ▶ shown, ◀ hidden", next.visible and not prev.visible, [prev.visible, next.visible])
	_check("the sign names it", _name(map) == "World 1  ·  Meadow", _name(map))
	_check("World 1 shows its 10 spots, 2 open (1-1 done, 1-2 next)", _spots(map).size() == 10 and _open(map) == 2, [_spots(map).size(), _open(map)])
	_check("the kitten waits on 1-2", map.find_child("Kitten", true, false) != null, "")

	next.pressed.emit()
	await process_frame
	await process_frame
	var last_world: int = map.WORLDS.size()
	_check("▶ shows World 2: Sunset Town, ◀ shown (▶ only if a world follows)", map.world == 2 and _name(map) == "World 2  ·  Sunset Town" and prev.visible and next.visible == (last_world > 2), [map.world, _name(map)])
	for w in range(3, last_world + 1):
		next.pressed.emit()
		await process_frame
	_check("the last world (%d) hides ▶" % last_world, map.world == last_world and not next.visible and _spots(map).size() == 10, [map.world, next.visible])
	for w in range(3, last_world + 1):
		prev.pressed.emit()
		await process_frame
	_check("World 2 shows 10 spots, all locked for now", _spots(map).size() == 10 and _open(map) == 0, [_spots(map).size(), _open(map)])
	_check("World 2 has its own girl and no kitten (her next level is in World 1)", map.find_children("Girl", "", true, false).size() == 1 and map.find_child("Kitten", true, false) == null, "")
	_check("World 2 shows its own map picture", map.get_node("Map/Picture").texture.resource_path.ends_with("map_w2.png"), map.get_node("Map/Picture").texture.resource_path)

	prev.pressed.emit()
	await process_frame
	await process_frame
	_check("◀ goes back to World 1 with its progress", map.world == 1 and _open(map) == 2 and map.find_children("Girl", "", true, false).size() == 1, [map.world, _open(map)])
	map.queue_free()
	await process_frame

	# Only a first finish makes the map walk on (a replay doesn't)
	var gs = root.get_node("GameState")
	var events = root.get_node("Events")
	gs.begin_attempt("w1_01", 20)   # already done
	events.level_completed.emit(3, 20, 20, true)
	_check("replaying a finished level: no walk on the map", gs.map_walk_from == "", gs.map_walk_from)
	gs.begin_attempt("w1_02", 20)   # first time
	events.level_completed.emit(3, 20, 20, true)
	_check("finishing a level the first time: the map will walk on from it", gs.map_walk_from == "w1_02", gs.map_walk_from)

	# The walk: 1-2 just finished, 1-3 drawn locked, then the kitten hops there and it opens
	save.record_result("w1_02", 3, 20, true)
	map = load("res://ui/screens/level_map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	_check("walk starts: 1-3 still drawn locked, the map ignores taps", _open(map) == 2 and map._busy, [_open(map), map._busy])
	await create_timer(3.0).timeout
	var kitten: Node2D = map.find_child("Kitten", true, false)
	_check("walk ends: 1-3 open, the kitten on it, nothing started", _open(map) == 3 and not map._busy and kitten != null \
		and is_equal_approx(kitten.position.x, map.WORLDS[0].spots[2].x) and map.last_played == "", [_open(map), map.last_played])
	map.queue_free()
	await process_frame

	# Next after a first finish: the walk, then the new level starts by itself
	gs.map_walk_from = "w1_02"
	gs.map_auto_play = true
	map = load("res://ui/screens/level_map.tscn").instantiate()
	root.add_child(map)
	await create_timer(3.5).timeout
	_check("after Next: the walk, then 1-3 starts", map.last_played == "w1_03", map.last_played)
	if is_instance_valid(map):
		map.queue_free()
	await create_timer(1.5).timeout   # let the level load (the scene change), then leave it
	if root.get_tree().current_scene:
		root.get_tree().current_scene.queue_free()
	await process_frame

	# World 1 finished: walk to the girl, "World 2 unlocked!", Let's go → World 2 with 2-1 open
	for i in range(1, 11):
		save.record_result("w1_%02d" % i, 3, 20, true)
	gs.map_walk_from = "w1_10"
	map = load("res://ui/screens/level_map.tscn").instantiate()
	root.add_child(map)
	await create_timer(4.0).timeout
	_check("after World 1: the 'World 2 unlocked' card", map.menu.current == "unlocked" and map.menu.find_child("WorldName", true, false).text == "WORLD_2_NAME", map.menu.current)
	map._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)   # Android Back = Let's go
	await create_timer(1.8).timeout
	_check("then World 2 with 2-1 open and the kitten on it", map.world == 2 and _open(map) == 1 and map.find_child("Kitten", true, false) != null and not map._busy, [map.world, _open(map)])
	map.queue_free()

	for f in ["", ".bak"]:
		DirAccess.remove_absolute(save.save_path + f)
	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _name(map) -> String:
	return map.find_child("WorldName", true, false).text

func _spots(map) -> Array:
	return map.get_node("Map").get_children().filter(func(n): return n is TextureButton and not n.is_queued_for_deletion())

func _open(map) -> int:
	return _spots(map).filter(func(b): return b.texture_normal.resource_path.ends_with("level_open.png")).size()

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", name, str(got) if not ok else ""])
