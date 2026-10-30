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

	for row in [["w1_01", 16], ["w1_02", 19], ["w1_03", 21]]:
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
		_check("%s: Next level button %s" % [row[0], "shown" if row[0] != "w1_03" else "hidden"],
			(level.get_node("Hud/SafeArea/Hud").menu.find_child("RESULT_NEXT", true, false) != null) == (row[0] != "w1_03"), "")
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
