extends SceneTree
## World 3's level tools, played like a player, in the demo level and in every World 3 level:
##  - tree climb: from the floor, hop up each zigzag ledge in turn, then onto the cliff top
##  - two routes: hop onto the entry step, up to the walkways, run along hopping the gaps to the end
##    (collecting the Golden Yarn if it's up there), never dropping to the floor, no heart lost
## Run: godot --headless --path . --script res://dev/m3_routes_test.gd

var _fails := 0
var _yarn := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.get_node("Events").yarn_collected.connect(func(): _yarn = true)
	var scenes := ["res://dev/forest_tools_demo.tscn"]
	for data in root.get_node("GameState").catalog.in_world(3):
		scenes.append(data.scene_path)
	for path in scenes:
		var probe = load(path).instantiate()
		var climbs := {}
		var canopies := {}
		for b in probe.get_node("Terrain").get_children():
			var n := String(b.name)
			if n.begins_with("Climb"):
				climbs[n.get_slice("_", 0)] = true
			elif n.begins_with("Canopy"):
				canopies[n.get_slice("_", 0)] = true
		probe.free()
		var id: String = path.get_file().get_basename()
		for tag in climbs:
			await _climb(path, id, tag)
		for tag in canopies:
			await _canopy(path, id, tag)
	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _climb(path: String, id: String, tag: String) -> void:
	var level = await _load(path)
	var cat = level.get_node("Player")
	var gs = root.get_node("GameState")
	gs.hearts = 3
	var ledges := _blocks(level, tag + "_Ledge")
	ledges.sort_custom(func(a, b): return a.global_position.y > b.global_position.y)   # lowest first
	var floor_y: float = ledges[0].global_position.y + 180.0
	await _place(cat, Vector2(ledges[0].global_position.x - 60.0, floor_y - 5.0))
	var ok := true
	for ledge in ledges:
		ok = ok and await _hop_to(cat, ledge.global_position.x + ledge.size.x * 0.5, ledge.global_position.y)
	# then onto the cliff: the ground block right of the top ledge
	var top = ledges[-1]
	var cliff = _cliff_after(level, top)
	ok = ok and cliff != null and await _hop_to(cat, cliff.global_position.x + 150.0, cliff.global_position.y)
	_check("%s: %s — up %d ledges onto the cliff, no heart lost" % [id, tag, ledges.size()], ok and gs.hearts == 3, [cat.global_position, gs.hearts])
	level.queue_free()
	await _frames(2)

func _canopy(path: String, id: String, tag: String) -> void:
	var level = await _load(path)
	var cat = level.get_node("Player")
	var gs = root.get_node("GameState")
	gs.hearts = 3
	_yarn = false
	var step = _blocks(level, tag + "_Step")[0]
	var walks := _blocks(level, tag + "_Walk")
	walks.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	var floor_y: float = step.global_position.y + 180.0
	var yarn_node = level.get_node("Objects").find_child("GoldenYarn", false, false)
	var has_yarn: bool = yarn_node != null and absf(yarn_node.global_position.y - (walks[0].global_position.y - 120.0)) < 5.0 		and yarn_node.global_position.x > walks[0].global_position.x and yarn_node.global_position.x < walks[-1].global_position.x + walks[-1].size.x   # on THIS route
	await _place(cat, Vector2(step.global_position.x - 80.0, floor_y - 5.0))
	var ok: bool = await _hop_to(cat, step.global_position.x + 150.0, step.global_position.y)
	for w in walks:
		ok = ok and await _hop_to(cat, w.global_position.x + 120.0, w.global_position.y)
		ok = ok and await _run_to(cat, w.global_position.x + w.size.x - 50.0, w.global_position.y)
	var high: bool = absf(cat.global_position.y - walks[-1].global_position.y) < 6.0
	_check("%s: %s — up to the walkways and along all %d, no heart lost%s" % [id, tag, walks.size(), ", yarn found" if has_yarn else ""],
		ok and high and gs.hearts == 3 and (_yarn or not has_yarn), [cat.global_position, gs.hearts, _yarn])
	level.queue_free()
	await _frames(2)

## A jump toward a platform's spot; steer like a player: let go of the arrow once above it.
## True if she lands on top of it (its top y).
func _hop_to(cat, x: float, top: float) -> bool:
	var dir := "move_right" if x > cat.global_position.x else "move_left"
	Input.action_press(dir)
	Input.action_press("jump")
	var landed := false
	for i in 120:
		await physics_frame
		if i == 24:
			Input.action_release("jump")
		if absf(cat.global_position.x - x) < 40.0:
			Input.action_release(dir)
		if i > 6 and cat.is_on_floor():
			landed = absf(cat.global_position.y - top) < 6.0
			break
	Input.action_release(dir)
	Input.action_release("jump")
	await _frames(6)
	return landed

## Walk along the current platform to x (stays on the same height).
func _run_to(cat, x: float, top: float) -> bool:
	Input.action_press("move_right")
	for i in 240:
		await physics_frame
		if cat.global_position.x >= x:
			break
	Input.action_release("move_right")
	await _frames(4)
	return absf(cat.global_position.y - top) < 6.0

func _blocks(level, prefix: String) -> Array:
	return level.get_node("Terrain").get_children().filter(func(b): return String(b.name).begins_with(prefix))

func _cliff_after(level, ledge):
	var right: float = ledge.global_position.x + ledge.size.x
	for b in level.get_node("Terrain").get_children():
		if b is GroundBlock and not b.one_way and b.global_position.x >= right - 2.0 and b.global_position.x < right + 250.0 \
				and b.global_position.y < ledge.global_position.y + 10.0:
			return b
	return null

func _load(path: String):
	var level = load(path).instantiate()
	root.add_child(level)
	await _frames(80)   # the start-of-level safe time runs out
	return level

func _place(cat, at: Vector2) -> void:
	cat.global_position = at
	cat.velocity = Vector2.ZERO
	await _frames(4)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", name, str(got) if not ok else ""])
