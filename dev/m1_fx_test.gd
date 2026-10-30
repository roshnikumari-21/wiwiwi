extends SceneTree
## Headless check that one-shot effects appear where expected and remove themselves afterwards.
## Run: godot --headless --path . --script res://dev/m1_fx_test.gd

const LEVEL := "res://scenes/levels/w1/level_w1_01.tscn"

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var level = load(LEVEL).instantiate()
	root.add_child(level)
	var player = level.get_node("Player")
	var objects = level.get_node("Objects")
	await _frames(80)

	await _place(player, Vector2(500, 900))   # first coin
	_check("coin: sparkle burst plays", _fx_count(objects) == 1, _fx_count(objects))
	await _frames(30)
	_check("coin: burst cleans itself up", _fx_count(objects) == 0, _fx_count(objects))

	player.energy = 0.3
	await _place(player, Vector2(2250, 900))  # milk bowl
	_check("milk: energy sparkle plays", _fx_count(objects) == 1, _fx_count(objects))
	await _frames(40)

	await _place(player, Vector2(3000, 760))  # checkpoint flag
	_check("flag: star burst plays", _fx_count(objects) == 1, _fx_count(objects))
	await _frames(40)

	await _place(player, Vector2(950, 900))   # spikes
	_check("hurt: heart break plays", _fx_count(level) == 1, _fx_count(level))
	await _frames(80)

	player.global_position = Vector2(700, 300)   # a high drop onto the ground
	player.velocity = Vector2.ZERO
	var dust := false
	for i in 60:
		await physics_frame
		dust = dust or _fx_count(level) > 0
	_check("big landing: dust puff plays", dust, "")
	await _frames(40)
	_check("nothing left over", _fx_count(level) + _fx_count(objects) == 0, _fx_count(level) + _fx_count(objects))

	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _fx_count(parent: Node) -> int:
	return parent.get_children().filter(func(n): return n is Fx).size()

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
