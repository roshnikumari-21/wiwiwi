extends SceneTree
## Headless checks for levels 1-1..1-3: each loads, counts its coins, can be finished at the girl;
## and the key moves of 1-2/1-3 really work (plank rides, the cliff lift, a tired cat onto a spike step).
## Run: godot --headless --path . --script res://dev/m1_levels_test.gd

var _fails := 0
var _completed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var gs = root.get_node("GameState")
	root.get_node("Events").level_completed.connect(func(_s, _c, _t, _y): _completed = true)

	for row in [["w1_01", 16], ["w1_02", 19], ["w1_03", 21], ["w1_04", 21], ["w1_05", 25], ["w1_06", 22], ["w1_07", 23], ["w1_08", 25], ["w1_09", 25]]:
		var level = await _load(row[0])
		_check("%s: loads, %d coins" % row, gs.coin_total == row[1] and gs.current_level_id == row[0], [gs.current_level_id, gs.coin_total])
		_check("%s: has a flag and the girl" % row[0], get_nodes_in_group("goal").size() == 1 and level.get_node("Objects").find_children("Checkpoint*", "", false).size() >= 1, "")
		var girl: Node2D = get_nodes_in_group("goal")[0]
		_completed = false
		await _place(level.get_node("Player"), girl.global_position + Vector2(-150, 0))
		for i in 300:
			if _completed:
				break
			await physics_frame
		_check("%s: finished at the girl" % row[0], _completed, "")
		_check("%s: Next level button %s" % [row[0], "shown" if row[0] != "w1_09" else "hidden"],
			(level.get_node("Hud/SafeArea/Hud").menu.find_child("RESULT_NEXT", true, false) != null) == (row[0] != "w1_09"), "")
		level.queue_free()
		await _frames(2)

	# 1-2: the sideways plank carries her over the big pond.
	var level = await _load("w1_02")
	var player = level.get_node("Player")
	await _frames(80)
	var plank = level.get_node("Objects/Plank1")
	await _ride(player, plank, Vector2(3990, 900), Vector2(4320, 900))
	Input.action_press("move_right")
	await _frames(30)
	Input.action_release("move_right")
	_check("1-2: plank ride over the pond", player.global_position.x > 4450.0 and player.is_on_floor() and absf(player.global_position.y - 900.0) < 4.0, player.global_position)
	level.queue_free()
	await _frames(2)

	# 1-3: the lift takes her up the cliff.
	level = await _load("w1_03")
	player = level.get_node("Player")
	await _frames(80)
	var lift = level.get_node("Objects/Plank1")
	await _ride(player, lift, Vector2(2425, 900), Vector2(2425, 630))
	_check("1-3: lift reached the top with her", player.global_position.y < 640.0 and player.is_on_floor(), player.global_position)
	Input.action_press("move_right")
	await _frames(25)
	Input.action_release("move_right")
	await _frames(5)
	_check("1-3: she walks off onto the cliff", player.global_position.x > 2620.0 and absf(player.global_position.y - 640.0) < 4.0 and player.is_on_floor(), player.global_position)

	# 1-3: a tired cat can still hop onto the step over the long spikes.
	player.energy = 0.0
	await _place(player, Vector2(1400, 900))
	Input.action_press("move_right")
	while player.global_position.x < 1470.0:
		await physics_frame
	Input.action_press("jump")
	await _frames(40)
	Input.action_release("jump")
	await _frames(15)
	Input.action_release("move_right")
	_check("1-3: tired cat lands on the spike step", player.is_on_floor() and absf(player.global_position.y - 700.0) < 4.0, player.global_position)

	level.queue_free()
	await _frames(2)

	# 1-4: a mushroom bounce (no jump held) lifts her onto the cliff too high to jump.
	level = await _load("w1_04")
	player = level.get_node("Player")
	await _frames(80)
	await _place(player, Vector2(2150, 700))   # just above the cap, falling
	Input.action_press("move_right")
	var top := 2000.0
	for i in 120:
		await physics_frame
		top = minf(top, player.global_position.y)
		if player.is_on_floor() and i > 10:
			break
	Input.action_release("move_right")
	_check("1-4: mushroom bounce lands her on the cliff", player.is_on_floor() and absf(player.global_position.y - 560.0) < 4.0, player.global_position)
	_check("1-4: small bounce is ~1.6x a jump (feet rose ~480)", top < 765.0 - 440.0 and top > 765.0 - 540.0, top)

	# 1-4: holding jump on the yarn mushroom reaches the Golden Yarn; not holding doesn't.
	await _place(player, Vector2(5250, 700))
	for i in 90:
		await physics_frame
	_check("1-4: small bounce misses the yarn", not gs.has_yarn, "")
	await _place(player, Vector2(5250, 700))
	Input.action_press("jump")
	for i in 90:
		await physics_frame
		if gs.has_yarn:
			break
	Input.action_release("jump")
	_check("1-4: big bounce (jump held) gets the yarn", gs.has_yarn, player.global_position)

	# 1-4: two planks in a row carry her over the wide pond.
	var a = level.get_node("Objects/Plank1")
	await _ride(player, a, Vector2(3640, 900), Vector2(3970, 900))
	var hearts: int = root.get_node("GameState").hearts
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(25)
	Input.action_release("jump")
	for i in 60:   # stop running as soon as she lands, like a player would
		await physics_frame
		if player.is_on_floor():
			break
	Input.action_release("move_right")
	_check("1-4: hop from plank 1 to plank 2", player.is_on_floor() and absf(player.global_position.y - 900.0) < 4.0 and player.global_position.x > 4200.0, player.global_position)
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(25)
	Input.action_release("jump")
	await _frames(70)
	Input.action_release("move_right")
	_check("1-4: and on to the far shore, no heart lost", player.is_on_floor() and player.global_position.x > 4700.0 and root.get_node("GameState").hearts == hearts, [player.global_position, root.get_node("GameState").hearts])
	level.queue_free()
	await _frames(2)

	# 1-5: the lift takes her up to the cliff; the mushroom lifts her onto the high cliff.
	level = await _load("w1_05")
	player = level.get_node("Player")
	await _frames(80)
	await _ride(player, level.get_node("Objects/Plank1"), Vector2(2175, 900), Vector2(2175, 500))
	Input.action_press("move_right")
	await _frames(30)
	Input.action_release("move_right")
	_check("1-5: lift up to the cliff", player.is_on_floor() and absf(player.global_position.y - 520.0) < 4.0, player.global_position)
	await _place(player, Vector2(6150, 700))
	Input.action_press("move_right")
	for i in 120:
		await physics_frame
		if player.is_on_floor() and i > 10:
			break
	Input.action_release("move_right")
	_check("1-5: mushroom onto the high cliff", player.is_on_floor() and absf(player.global_position.y - 480.0) < 4.0, player.global_position)

	level.queue_free()
	await _frames(2)

	# 1-6: the bridge over the slime field: up from the ground, across all three, yarn from the middle one.
	level = await _load("w1_06")
	player = level.get_node("Player")
	await _frames(80)
	var gs6 = root.get_node("GameState")
	await _place(player, Vector2(2020, 900))
	Input.action_press("move_right")
	for hop in 3:
		Input.action_press("jump")
		await _frames(24)
		Input.action_release("jump")
		for i in 60:
			await physics_frame
			if player.is_on_floor():
				break
	Input.action_release("move_right")
	_check("1-6: up on the bridge over the slimes, no heart lost", player.is_on_floor() and absf(player.global_position.y - 680.0) < 4.0 and gs6.hearts == 3, [player.global_position, gs6.hearts])
	await _place(player, Vector2(2725, 680))
	Input.action_press("jump")
	await _frames(40)
	Input.action_release("jump")
	await _frames(30)
	_check("1-6: Golden Yarn from the middle bridge", gs6.has_yarn, player.global_position)
	level.queue_free()
	await _frames(2)

	# 1-7 starts hungry: a cat with no energy still clears the first pond, and the lift still works.
	level = await _load("w1_07")
	player = level.get_node("Player")
	await _frames(80)
	_check("1-7: starts at 30 % energy", is_equal_approx(player.energy, 0.3), player.energy)
	player.energy = 0.0
	await _place(player, Vector2(1000, 900))
	Input.action_press("move_right")
	while player.global_position.x < 1170.0:
		await physics_frame
	Input.action_press("jump")
	await _frames(40)
	Input.action_release("jump")
	for i in 60:
		await physics_frame
		if player.is_on_floor():
			break
	Input.action_release("move_right")
	_check("1-7: tired cat clears the first pond", player.is_on_floor() and player.global_position.x > 1450.0 and absf(player.global_position.y - 900.0) < 4.0, player.global_position)
	await _ride(player, level.get_node("Objects/Plank1"), Vector2(2575, 900), Vector2(2575, 520))
	Input.action_press("move_right")
	await _frames(40)
	Input.action_release("move_right")
	_check("1-7: lift up to the cliff (tired)", player.is_on_floor() and absf(player.global_position.y - 540.0) < 4.0, player.global_position)

	level.queue_free()
	await _frames(2)

	# 1-8: three planks in a row over the big pond, plank to plank, no heart lost.
	level = await _load("w1_08")
	player = level.get_node("Player")
	await _frames(80)
	var gs8 = root.get_node("GameState")
	await _ride(player, level.get_node("Objects/Plank1"), Vector2(3840, 900), Vector2(4170, 900))
	for hop in 3:
		Input.action_press("move_right")
		Input.action_press("jump")
		await _frames(25)
		Input.action_release("jump")
		for i in 70:
			await physics_frame
			if player.is_on_floor():
				break
		Input.action_release("move_right")
	_check("1-8: across three planks to the far shore, no heart lost", player.is_on_floor() and player.global_position.x > 5200.0 and gs8.hearts == 3, [player.global_position, gs8.hearts])

	# 1-8 (owner playtest): off the lift onto the cliff, jump the slime, land safely beyond it.
	await _ride(player, level.get_node("Objects/Plank4"), Vector2(6575, 900), Vector2(6575, 500))
	var h8: int = gs8.hearts
	Input.action_press("move_right")
	var slime8 = level.get_node("Objects/Slime3")
	while player.global_position.x < slime8.global_position.x - 200.0 and player.global_position.x < 7600.0:   # time it to the slime
		await physics_frame
	Input.action_press("jump")
	await _frames(25)
	Input.action_release("jump")
	await _frames(60)
	Input.action_release("move_right")
	_check("1-8: lift -> jump the cliff slime -> land, no heart lost", gs8.hearts == h8 and player.global_position.x > 7400.0, [player.global_position, gs8.hearts])

	# 1-8: the Golden Yarn above the middle plank can be reached by a jump from it.
	await _ride(player, level.get_node("Objects/Plank2"), Vector2(4260, 900), Vector2(4590, 900))
	await _place(player, Vector2(4470, 898))
	Input.action_press("jump")
	await _frames(30)
	Input.action_release("jump")
	await _frames(20)
	_check("1-8: yarn reachable from the middle plank", gs8.has_yarn, player.global_position)
	level.queue_free()
	await _frames(2)

	# 1-9: the mushroom staircase: two bounces up two cliffs, then the yarn with a full jump.
	level = await _load("w1_09")
	player = level.get_node("Player")
	await _frames(80)
	var gs9 = root.get_node("GameState")
	for stair in [[Vector2(2050, 700), 560.0], [Vector2(2750, 360), 260.0]]:
		await _place(player, stair[0])
		Input.action_press("move_right")
		for i in 150:
			await physics_frame
			if player.is_on_floor() and i > 10:
				break
		Input.action_release("move_right")
		_check("1-9: mushroom bounce up to y %d" % stair[1], player.is_on_floor() and absf(player.global_position.y - stair[1]) < 4.0, player.global_position)
	await _place(player, Vector2(3450, 260))
	Input.action_press("jump")
	await _frames(30)
	Input.action_release("jump")
	await _frames(20)
	_check("1-9: yarn above the top step with a full jump", gs9.has_yarn, player.global_position)

	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

## Wait until the plank is back at `start`, step on, and ride until it reaches `end`.
func _ride(player, plank, start: Vector2, end: Vector2) -> void:
	for i in 600:
		if plank.global_position.distance_to(start) < 2.0:
			break
		await physics_frame
	await _place(player, plank.global_position + Vector2(0, -2))
	for i in 600:
		if plank.global_position.distance_to(end) < 2.0:
			break
		await physics_frame
	await _frames(3)

func _load(id: String):
	var level = load("res://scenes/levels/w1/level_%s.tscn" % id).instantiate()
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
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", name, str(got)])
