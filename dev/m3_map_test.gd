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
	_check("▶ shows World 2: Sunset Town, ◀ shown, ▶ hidden", map.world == 2 and _name(map) == "World 2  ·  Sunset Town" and prev.visible and not next.visible, [map.world, _name(map)])
	_check("World 2 shows 10 spots, all locked for now", _spots(map).size() == 10 and _open(map) == 0, [_spots(map).size(), _open(map)])
	_check("World 2 has its own girl and no kitten (her next level is in World 1)", map.find_children("Girl", "", true, false).size() == 1 and map.find_child("Kitten", true, false) == null, "")
	_check("World 2 shows its own map picture", map.get_node("Map/Picture").texture.resource_path.ends_with("map_w2.png"), map.get_node("Map/Picture").texture.resource_path)

	prev.pressed.emit()
	await process_frame
	await process_frame
	_check("◀ goes back to World 1 with its progress", map.world == 1 and _open(map) == 2 and map.find_children("Girl", "", true, false).size() == 1, [map.world, _open(map)])
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
