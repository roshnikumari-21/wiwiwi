extends SceneTree
## Headless check of the level rules in level 1-1: coins, yarn, hearts, checkpoint, fail and stars.
## Run: godot --headless --path . --script res://dev/m1_rules_test.gd

const LEVEL := "res://scenes/levels/w1/level_w1_01.tscn"

var _fails := 0
var _completed: Array = []
var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var gs = root.get_node("GameState")
	var ev = root.get_node("Events")
	ev.level_completed.connect(func(s, c, t, y): _completed = [s, c, t, y])
	ev.level_failed.connect(func(): _failed = true)

	# --- Attempt 1: pickups, hearts, checkpoint, running out of hearts ---
	var level = await _load()
	var player = level.get_node("Player")
	var hud = level.get_node("Hud/SafeArea/Hud")
	await _frames(2)
	_check("16 coins counted", gs.coin_total == 16, gs.coin_total)
	_check("3 hearts", gs.hearts == 3, gs.hearts)
	_check("HUD shows 0 / 16", hud.get_node("Top/CoinLabel").text == "0 / 16", hud.get_node("Top/CoinLabel").text)

	await _place(player, Vector2(500, 900))
	_check("coin collected", gs.coins == 1, gs.coins)
	_check("HUD shows 1 / 16", hud.get_node("Top/CoinLabel").text == "1 / 16", hud.get_node("Top/CoinLabel").text)

	await _place(player, Vector2(4440, 400))
	_check("yarn collected", gs.has_yarn, gs.has_yarn)

	await _place(player, Vector2(1500, 1800))
	_check("pit costs a heart", gs.hearts == 2, gs.hearts)
	_check("back at the start", player.global_position.distance_to(Vector2(200, 900)) < 5, player.global_position)

	await _place(player, Vector2(3000, 760))
	await _place(player, Vector2(3300, 1800))
	_check("back at the flag", player.global_position.distance_to(Vector2(3000, 760)) < 5, player.global_position)
	_check("2nd heart lost", gs.hearts == 1, gs.hearts)

	await _place(player, Vector2(3300, 1800))
	_check("out of hearts -> level failed", _failed and gs.hearts == 0, gs.hearts)
	_check("fail card shown", hud.get_node("Card").visible, "")
	_check("fail card title", hud.get_node("Card/Center/Panel/Box/Title").text == "Out of hearts", hud.get_node("Card/Center/Panel/Box/Title").text)
	_check("touch controls hidden", not level.get_node("Hud/SafeArea/TouchControls").visible, "")
	level.queue_free()
	await _frames(2)

	# --- Attempt 2: all coins, no yarn, reach the girl -> 2 stars ---
	level = await _load()
	player = level.get_node("Player")
	await _frames(2)
	_check("fresh attempt resets", gs.hearts == 3 and gs.coins == 0 and not gs.has_yarn, [gs.hearts, gs.coins, gs.has_yarn])
	for coin in get_nodes_in_group("coins"):
		await _place(player, coin.global_position + Vector2(0, 50))
	_check("all coins", gs.coins == 16, gs.coins)
	await _place(player, Vector2(5320, 900))   # off the plank, into the girl's reach
	await _frames(10)
	_check("player frozen", player.frozen, "")
	_check("nothing shown before the hug ends", _completed.is_empty(), _completed)
	var girl = level.get_node("Objects/GoalGirl/Girl")
	for i in 400:
		if not _completed.is_empty():
			break
		await physics_frame
	_check("cat walked into her arms", not player.visible, player.global_position)
	_check("girl hugs", girl.texture.resource_path.contains("girl_hug_"), girl.texture.resource_path)
	_check("goal -> completed with 2 stars", _completed == [2, 16, 16, false], _completed)
	level.queue_free()
	await _frames(2)

	# --- Star rules ---
	gs.coin_total = 10
	gs.coins = 7; gs.has_yarn = false
	_check("7/10 coins -> 1 star", gs.stars() == 1, gs.stars())
	gs.coins = 8
	_check("8/10 coins -> 2 stars", gs.stars() == 2, gs.stars())
	gs.has_yarn = true
	_check("8/10 + yarn -> 3 stars", gs.stars() == 3, gs.stars())

	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _load():
	var level = load(LEVEL).instantiate()
	root.add_child(level)
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
