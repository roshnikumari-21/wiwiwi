extends SceneTree
## Plays every level in the catalog:
##  - it loads, counts its coins, has a checkpoint and the girl, can be finished at her
##    (Next level button, or a "World complete" card on each world's last level)
##  - every crossing is actually ridden or jumped like a player would, with no heart lost:
##    sliding-plank chains, bobbing planks over rivers, diagonal planks, lifts and mushroom cliffs,
##    and World 2's crumbling roof tiles (bridges over the canal, staircases up to a ledge).
## Run: godot --headless --path . --script res://dev/m1_levels_test.gd   [-- w4_01 ...  to check only some]

var _fails := 0
var _completed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var gs = root.get_node("GameState")
	root.get_node("Events").level_completed.connect(func(_s, _c, _t, _y): _completed = true)
	var levels: Array = gs.catalog.levels
	var only: Array = Array(OS.get_cmdline_user_args())   # e.g. `-- w4_01`: check just those levels (by id prefix)
	for data in levels:
		if not only.is_empty() and not only.any(func(p): return data.id.begins_with(p)):
			continue
		var level = await _load(data.scene_path)
		var coins: int = level.get_meta("coins")
		_check("%s: loads, %d coins counted" % [data.id, coins], gs.coin_total == coins and coins > 0 and gs.current_level_id == data.id, gs.coin_total)
		_check("%s: has a checkpoint and the girl" % data.id, level.find_children("*", "Area2D", true, false).filter(func(n): return n.is_in_group("goal")).size() == 1 and level.get_node("Objects").find_children("Checkpoint*", "", false).size() >= 1, "")
		level.queue_free()
		await _frames(2)
		await _crossings(data)

		level = await _load(data.scene_path)
		var girl: Node2D = level.get_node("Objects/GoalGirl")
		_completed = false
		await _place(level.get_node("Player"), girl.global_position + Vector2(-150, 0))
		for i in 900:   # the world finale's hug is longer
			if _completed:
				break
			await physics_frame
		_check("%s: finished at the girl" % data.id, _completed, "")
		var menu = level.get_node("Hud/SafeArea/Hud").menu
		var last: bool = data.is_reunion   # the world's last level
		if last:
			_check("%s: World %d complete card" % [data.id, data.world], menu.find_child("WorldStars", true, false) != null, "")
		elif gs.catalog.next_after(data.id) != null:
			_check("%s: Next level button" % data.id, menu.find_child("RESULT_NEXT", true, false) != null, "")
		else:   # the newest level built so far (its world is still being made): no Next yet
			_check("%s: no Next button yet (newest level)" % data.id, menu.find_child("RESULT_NEXT", true, false) == null, "")
		level.queue_free()
		await _frames(2)
	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

## Finds each crossing in the level and tries it, each in a freshly loaded level (full hearts).
func _crossings(data) -> void:
	var id: String = data.id
	var probe = await _load(data.scene_path)
	var waters := []
	var mushrooms := []
	var tiles := []   # World 2 crumbling roof tiles (positions)
	for o in probe.get_node("Objects").get_children():
		if o.scene_file_path.ends_with("crumble_tile.tscn"):
			tiles.append(o.global_position)
		elif o.scene_file_path.ends_with("water.tscn"):
			waters.append(String(o.name))
		elif o.scene_file_path.ends_with("mushroom.tscn"):
			mushrooms.append(String(o.name))
	probe.queue_free()
	await _frames(2)
	for water_name in waters:
		var level = await _load(data.scene_path)
		var gs = root.get_node("GameState")
		var player = level.get_node("Player")
		var objects: Array = level.get_node("Objects").get_children().filter(func(o): return not o.is_in_group("coins"))
		var water = level.get_node("Objects/" + water_name)
		await _frames(80)   # the start-of-level safe time runs out
		await _water_crossing(level, id, water, objects, player, gs)
		level.queue_free()
		await _frames(2)
	for m_name in mushrooms:
		var level = await _load(data.scene_path)
		await _frames(80)
		await _mushroom_crossing(level, id, level.get_node("Objects/" + m_name), level.get_node("Player"))
		level.queue_free()
		await _frames(2)
	tiles.sort_custom(func(a, b): return a.x < b.x)
	var chains := []   # tiles close together = one crossing (a bridge or a staircase)
	for t in tiles:
		if chains.is_empty() or t.x - chains[-1][-1].x > 450.0:
			chains.append([])
		chains[-1].append(t)
	for chain in chains:
		var level = await _load(data.scene_path)
		await _frames(80)
		await _crumble_crossing(id, chain, level.get_node("Player"))
		level.queue_free()
		await _frames(2)
	# World 4 ledge hops: narrow ledges across a wide river
	var hop_probe = load(data.scene_path).instantiate()
	var hops := {}
	for b in hop_probe.get_node("Terrain").get_children():
		if String(b.name).begins_with("Hop"):
			var tag := String(b.name).get_slice("_", 0)
			if not hops.has(tag):
				hops[tag] = []
			hops[tag].append(Rect2(b.global_position, b.size))
	hop_probe.free()
	for tag in hops:
		var level = await _load(data.scene_path)
		await _frames(80)
		await _hop_crossing(id, hops[tag], level.get_node("Player"))
		level.queue_free()
		await _frames(2)
	# World 4 icicle arches: run the floor route below like a player who watches the shadows
	var arch_probe = load(data.scene_path).instantiate()
	var arches := []   # [from x, to x, floor y]
	for b in arch_probe.get_node("Terrain").get_children():
		var bn := String(b.name)
		if bn.begins_with("Canopy") and bn.ends_with("_Step"):
			var tag := bn.get_slice("_", 0)
			var last_end := 0.0
			for w in arch_probe.get_node("Terrain").get_children():
				if String(w.name).begins_with(tag + "_Walk"):
					last_end = maxf(last_end, w.global_position.x + w.size.x)
			var has_icicles := false
			for o in arch_probe.get_node("Objects").get_children():
				if o.scene_file_path.ends_with("pinecone.tscn") and o.look == "icicle" and o.global_position.x > b.global_position.x and o.global_position.x < last_end:
					has_icicles = true
			if has_icicles:
				arches.append([b.global_position.x - 150.0, last_end + 250.0, b.global_position.y + 180.0])
	arch_probe.free()
	for arch in arches:
		var level = await _load(data.scene_path)
		await _frames(80)
		await _icicle_run(id, arch, level)
		level.queue_free()
		await _frames(2)
	var probe2 = load(data.scene_path).instantiate()
	var ices: Array = probe2.get_node("Terrain").get_children().filter(func(b): return b is GroundBlock and b.theme == "ice" and not b.one_way)
	var ice_names: Array = ices.map(func(b): return String(b.name))
	var penguins: Array = probe2.get_node("Objects").get_children().filter(func(o): return o.scene_file_path.ends_with("penguin.tscn")).map(func(o): return String(o.name))
	probe2.free()
	for p_name in penguins:
		await _penguin_pass(id, data.scene_path, p_name)
	for ice_name in ice_names:
		var level = await _load(data.scene_path)
		await _frames(80)
		await _ice_crossing(id, level.get_node("Terrain/" + ice_name), level.get_node("Player"))
		level.queue_free()
		await _frames(2)

## World 4: run at a penguin like a player, from before its path, and jump it when it's 150-260 px
## ahead (whether it waddles, warns or slides at her). Tried at 3 moments of its rhythm; she must get
## past its path with no heart lost (stomping it on the way is fine).
func _penguin_pass(id: String, path: String, name: String) -> void:
	var fails := []
	for wait in [10, 70, 130]:
		var level = await _load(path)
		await _frames(80 + wait)
		var player = level.get_node("Player")
		var pg = level.get_node("Objects/" + name)
		var gs = root.get_node("GameState")
		gs.hearts = 3
		var home: float = pg._home_x
		var reach: float = pg.patrol_distance + 100.0
		await _place(player, Vector2(home - reach - 350.0, pg.global_position.y - 5.0))
		Input.action_press("move_right")
		for i in 600:
			await physics_frame
			if player.global_position.x > home + reach + 150.0:
				break
			if is_instance_valid(pg) and not pg._squashed and player.is_on_floor():
				var ahead: float = pg.global_position.x - player.global_position.x
				if ahead > 150.0 and ahead < 260.0:
					Input.action_press("jump")
					await _frames(22)
					Input.action_release("jump")
		Input.action_release("move_right")
		await _frames(10)
		if gs.hearts < 3:
			fails.append(wait)
		level.queue_free()
		await _frames(2)
	_check("%s: past %s (3 timings), no heart lost" % [id, name], fails.is_empty(), fails)

## World 4: start at the beginning of an ice stretch, run across it at full speed like a player
## (jumping a slime or penguin when it's 160-240 px ahead), let go at the ice's end and slide to a stop.
## She must stay up on the snow after it (not slide into a gap) with no heart lost.
func _ice_crossing(id: String, ice, player) -> void:
	var gs = root.get_node("GameState")
	gs.hearts = 3
	var start: float = ice.global_position.x
	var end: float = ice.global_position.x + ice.size.x
	await _place(player, Vector2(start + 30.0, ice.global_position.y - 5.0))   # (a pond may come right before it)
	Input.action_press("move_right")
	for i in 600:
		await physics_frame
		if player.global_position.x > end:
			break
		if player.is_on_floor():
			for e in root.get_tree().get_nodes_in_group("enemies"):
				var ahead: float = e.global_position.x - player.global_position.x
				if is_instance_valid(e) and ahead > 160.0 and ahead < 240.0 and absf(e.global_position.y - player.global_position.y) < 40.0:
					Input.action_press("jump")
					await _frames(22)
					Input.action_release("jump")
					break
	Input.action_release("move_right")
	for i in 240:
		await physics_frame
		if player.is_on_floor() and absf(player.velocity.x) < 1.0:
			break
	var ok: bool = player.is_on_floor() and absf(player.global_position.y - ice.global_position.y) < 6.0 and gs.hearts == 3
	_check("%s: across the ice at x %d at full speed, slid to a stop on the snow, no heart lost" % [id, int(start)], ok, [player.global_position, gs.hearts])

## Like a player under the icicles: run along the floor; when a shadow grows (or an icicle falls) just
## ahead, stop and wait until it has landed; if one starts right above her, keep running (she gets
## clear in time). Jump slimes and penguins like on the ice.
func _icicle_run(id: String, arch: Array, level) -> void:
	var gs = root.get_node("GameState")
	gs.hearts = 3
	var player = level.get_node("Player")
	var IC = load("res://scenes/objects/pinecone.gd")
	var icicles: Array = level.get_node("Objects").get_children().filter(func(o): return o.scene_file_path.ends_with("pinecone.tscn"))
	await _place(player, Vector2(arch[0], arch[2] - 5.0))
	var waits := 0
	for i in 60 * 30:
		await physics_frame
		if player.global_position.x > arch[1]:
			break
		var hold := false
		for c in icicles:
			var ahead: float = c.global_position.x - player.global_position.x
			if ahead > 90.0 and ahead < 300.0 and (c.state == IC.State.WARNING or c.state == IC.State.FALLING):
				hold = true
		if hold:
			if Input.is_action_pressed("move_right"):
				waits += 1
			Input.action_release("move_right")
			continue
		Input.action_press("move_right")
		if player.is_on_floor():
			for e in root.get_tree().get_nodes_in_group("enemies"):
				var ahead: float = e.global_position.x - player.global_position.x
				if is_instance_valid(e) and ahead > 160.0 and ahead < 240.0 and absf(e.global_position.y - player.global_position.y) < 40.0:
					Input.action_press("jump")
					await _frames(22)
					Input.action_release("jump")
					break
	Input.action_release("move_right")
	var ok: bool = player.global_position.x > arch[1] and gs.hearts == 3
	_check("%s: under the icicles at x %d, watching the shadows (waited %d times), no heart lost" % [id, int(arch[0]), waits], ok, [player.global_position, gs.hearts])

## Like a player: from the shore, a jump onto each narrow ledge in turn (steering to its middle), then onto the far shore.
func _hop_crossing(id: String, ledges: Array, player) -> void:
	var gs = root.get_node("GameState")
	gs.hearts = 3
	ledges.sort_custom(func(a, b): return a.position.x < b.position.x)
	var shore_y: float = ledges[1].position.y if ledges.size() > 1 else ledges[0].position.y + 80.0
	await _place(player, Vector2(ledges[0].position.x - 200.0, shore_y - 40.0))
	await _frames(20)
	var ok := true
	for l in ledges:
		await _hop_onto(player, l.position.x + l.size.x * 0.5)
		ok = ok and player.is_on_floor() and absf(player.global_position.y - l.position.y) < 6.0 \
			and player.global_position.x > l.position.x and player.global_position.x < l.position.x + l.size.x
	await _hop(player)
	var last: Rect2 = ledges[-1]
	ok = ok and player.is_on_floor() and player.global_position.x > last.position.x + last.size.x + 60.0 and gs.hearts == 3
	_check("%s: %d narrow ledges across the river at x %d, no heart lost" % [id, ledges.size(), int(ledges[0].position.x)], ok, [player.global_position, gs.hearts])

## Like a player: from just before the first tile, hop from tile to tile without stopping (each one
## breaks half a second after she lands) and land on the far side: the shore, or the ledge at the
## top of a staircase.
func _crumble_crossing(id: String, chain: Array, player) -> void:
	var gs = root.get_node("GameState")
	gs.hearts = 3
	var first: Vector2 = chain[0]
	var last: Vector2 = chain[-1]
	var stairs := last.y < first.y - 50.0
	var floor_y: float = first.y + (170.0 if stairs else 0.0)   # the ground the first hop starts from
	await _place(player, Vector2(first.x - 290.0, floor_y - 40.0))
	await _frames(20)
	for i in chain.size() + 1:
		await _hop(player)
	var ok: bool = player.is_on_floor() and player.global_position.x > last.x + 150.0 and gs.hearts == 3 		and (not stairs or player.global_position.y < last.y)
	_check("%s: %d crumbling tiles (%s) at x %d, no heart lost" % [id, chain.size(), "steps" if stairs else "bridge", int(first.x)], ok, [player.global_position, gs.hearts])

func _water_crossing(level, id: String, water, objects: Array, player, gs) -> void:
	if true:
		var x0: float = water.global_position.x
		var x1: float = x0 + water.width
		var planks: Array = objects.filter(func(o): return o.scene_file_path.ends_with("moving_platform.tscn") and o.global_position.x > x0 and o.global_position.x < x1)
		if planks.is_empty():
			return
		planks.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
		var mv: Vector2 = planks[0].move_by
		var kind := "lift" if mv.x == 0.0 and planks.size() == 1 else ("bobbers" if mv.x == 0.0 else ("diagonal" if mv.y != 0.0 else "planks"))
		gs.hearts = 3
		var home: Vector2 = planks[0].global_position if planks[0].get_meta("home", null) == null else planks[0].get_meta("home")
		match kind:
			"planks", "bobbers":
				# Like a player: step on, hop along to the last plank, ride it to the shore end, jump off.
				await _ride(player, planks[0], home, home)
				for hop in planks.size() - 1:
					await _hop(player)
				var last_home: Vector2 = planks[-1].get_meta("home")
				for i in 900:
					if planks[-1].global_position.distance_to(last_home + mv) < 2.0:
						break
					await physics_frame
				Input.action_press("move_right")   # line up at the front of the plank, like a player
				for i in 40:
					if player.global_position.x > planks[-1].global_position.x + 70.0:
						break
					await physics_frame
				await _hop(player)
				var ok: bool = player.global_position.x > x1 and player.is_on_floor() and gs.hearts == 3
				_check("%s: %d %s across the river at x %d, no heart lost" % [id, planks.size(), "sliding planks" if kind == "planks" else "bobbing planks", int(x0)], ok, [player.global_position, gs.hearts])
			"lift", "diagonal":
				await _ride(player, planks[0], home, home + mv)
				Input.action_press("move_right")
				await _frames(45)
				Input.action_release("move_right")
				await _frames(10)
				var top: float = home.y + mv.y + 20.0
				var ok: bool = player.is_on_floor() and player.global_position.x > x1 and absf(player.global_position.y - top) < 25.0
				_check("%s: %s at x %d carries her up to the ledge" % [id, kind, int(x0)], ok, player.global_position)
func _mushroom_crossing(level, id: String, m, player) -> void:
	if true:
		var cliff = _cliff_after(level, m)
		if cliff == null:
			return   # a bonus mushroom (coins / yarn), not a way up
		await _place(player, m.global_position + Vector2(0, -200))
		Input.action_press("move_right")
		for i in 160:
			await physics_frame
			if player.is_on_floor() and i > 10:
				break
		Input.action_release("move_right")
		_check("%s: mushroom at x %d bounces her up the cliff" % [id, int(m.global_position.x)], player.is_on_floor() and absf(player.global_position.y - cliff.global_position.y) < 4.0, player.global_position)

## The higher ground right after a mushroom (it is a "mushroom cliff"), or null.
func _cliff_after(level, m):
	for b in level.get_node("Terrain").get_children():
		if b is GroundBlock and not b.one_way and b.global_position.x > m.global_position.x and b.global_position.x < m.global_position.x + 450.0 and b.global_position.y < m.global_position.y - 220.0:
			return b
	return null

## Wait until the plank is at `start`, step on, ride until it's at `end`.
func _ride(player, plank, start: Vector2, end: Vector2) -> void:
	for i in 900:
		if plank.global_position.distance_to(start) < 2.0:
			break
		await physics_frame
	await _place(player, plank.global_position + Vector2(0, -2))
	for i in 900:
		if plank.global_position.distance_to(end) < 2.0:
			break
		await physics_frame
	await _frames(3)

## A full jump to the right, steering like a player: let go of the arrow once she's above x.
func _hop_onto(player, x: float) -> void:
	Input.action_press("move_right")
	Input.action_press("jump")
	for i in 120:
		await physics_frame
		if i == 25:
			Input.action_release("jump")
		if player.global_position.x >= x - 20.0:
			Input.action_release("move_right")
		if i > 6 and player.is_on_floor():
			break
	Input.action_release("move_right")
	Input.action_release("jump")
	await _frames(4)

## A full jump to the right; stop running as soon as she lands, like a player.
func _hop(player) -> void:
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(25)
	Input.action_release("jump")
	for i in 90:
		await physics_frame
		if player.is_on_floor():
			break
	Input.action_release("move_right")
	await _frames(4)

func _load(path: String):
	var level = load(path).instantiate()
	var coins := 0
	for o in level.get_node("Objects").get_children():
		if o.scene_file_path.ends_with("moving_platform.tscn"):
			o.set_meta("home", o.position)   # where each plank starts (levels sit at the origin)
		coins += int(o.scene_file_path.ends_with("coin.tscn"))
		if o.scene_file_path.ends_with("bump_crate.tscn"):   # World 3: coins inside crates count too
			coins += o.coins
	level.set_meta("coins", coins)
	root.add_child(level)
	await _frames(3)
	return level

func _place(player, at: Vector2) -> void:
	player.global_position = at
	player.velocity = Vector2.ZERO
	await _frames(4)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", name, str(got) if not ok else ""])
