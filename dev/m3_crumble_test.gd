extends SceneTree
## World 2 crumbling roof tile (and World 4's thin ice look), played like a player: she lands on it → it cracks but holds for
## shake_time → it breaks and she drops → it comes back return_time later, but never while she's
## standing in its spot. It can be jumped up through from below (one-way).
## Run: godot --headless --path . --script res://dev/m3_crumble_test.gd

const TILE_AT := Vector2(380, 560)   # floating 340 px above level 1-1's start (ground y 900; spikes at 950, a pit at 1400)

var _fails := 0
var C   # crumble_tile.gd, loaded at run time (it uses the game's autoloads)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var level = load("res://scenes/levels/w1/level_w1_01.tscn").instantiate()
	root.add_child(level)
	C = load("res://scenes/objects/crumble_tile.gd")
	var tile = load("res://scenes/objects/crumble_tile.tscn").instantiate()
	tile.position = TILE_AT
	level.get_node("Objects").add_child(tile)
	var cat = level.get_node("Player")
	await _frames(80)   # the start-of-level safe time runs out

	# Lands on it
	await _place(cat, TILE_AT + Vector2(0, -120))
	for i in 60:
		await physics_frame
		if cat.is_on_floor():
			break
	_check("she lands on the tile", cat.is_on_floor() and absf(cat.global_position.y - TILE_AT.y) < 6.0, cat.global_position)
	await _frames(2)
	_check("landing cracks it", tile.state == C.State.SHAKING and tile.sprite.texture == C.LOOKS["roof"]["cracked"], tile.state)
	await create_timer(tile.shake_time * 0.6).timeout
	_check("it still holds her while shaking", cat.is_on_floor() and absf(cat.global_position.y - TILE_AT.y) < 6.0, cat.global_position)
	await create_timer(tile.shake_time * 0.6).timeout
	await _frames(20)
	_check("then it breaks and she drops", tile.state == C.State.GONE and cat.global_position.y > TILE_AT.y + 100.0, [tile.state, cat.global_position])

	# Comes back after return_time (she's on the ground below, out of its way)
	await create_timer(tile.return_time + 0.5).timeout
	_check("it comes back, solid again", tile.state == C.State.WHOLE_TILE and not tile.shape.disabled and tile.sprite.visible, tile.state)

	# Never reappears inside her: break it, then keep her standing in its spot (on a step) past return_time
	await _place(cat, TILE_AT + Vector2(0, -120))
	for i in 60:
		await physics_frame
		if tile.state == C.State.GONE:
			break
	await create_timer(tile.shake_time + 0.3).timeout
	var step := StaticBody2D.new()   # something to stand on exactly where the tile was
	var box := CollisionShape2D.new()
	box.shape = RectangleShape2D.new()
	box.shape.size = Vector2(400, 40)
	box.position = Vector2(0, 20)
	step.add_child(box)
	step.position = TILE_AT + Vector2(0, 60)
	level.add_child(step)
	await _place(cat, TILE_AT + Vector2(0, 40))
	await create_timer(tile.return_time + 0.6).timeout
	_check("while she stands in its spot it waits", tile.state == C.State.GONE, tile.state)
	step.queue_free()
	await create_timer(1.2).timeout
	_check("and comes back once she's gone", tile.state == C.State.WHOLE_TILE, tile.state)

	# One-way: rising from just below, she passes through it and lands on top
	await _place(cat, TILE_AT + Vector2(0, 90))
	cat.velocity = Vector2(0, -1000)
	var landed := false
	for i in 90:
		await physics_frame
		if cat.is_on_floor() and absf(cat.global_position.y - TILE_AT.y) < 6.0:
			landed = true
			break
	_check("rising from below passes through and lands on top", landed, cat.global_position)

	# World 4's thin ice: the same tile with the ice look — it shows the ice pictures and cracks the same way
	var ice = load("res://scenes/objects/crumble_tile.tscn").instantiate()
	ice.look = "ice"
	ice.position = TILE_AT + Vector2(700, 0)
	level.get_node("Objects").add_child(ice)
	await _frames(3)
	_check("thin ice shows the ice picture, its top where she walks", ice.sprite.texture == C.LOOKS["ice"]["whole"] and ice.sprite.position.y == -14.0, ice.sprite.position)
	await _place(cat, ice.position + Vector2(0, -60))
	for i in 60:
		await physics_frame
		if ice.state != C.State.WHOLE_TILE:
			break
	_check("landing on thin ice cracks it (the cracked ice picture)", ice.state == C.State.SHAKING and ice.sprite.texture == C.LOOKS["ice"]["cracked"], ice.state)

	level.queue_free()
	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _place(cat, at: Vector2) -> void:
	cat.global_position = at
	cat.velocity = Vector2.ZERO
	await _frames(2)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", name, str(got) if not ok else ""])
