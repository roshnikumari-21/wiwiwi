extends SceneTree
## World 5 quicksand, played like a player, on the sand preview level (Ground4 = one block of quicksand):
##  - on quicksand she knows it (on_quicksand), on sand she doesn't
##  - she walks at about half speed on it
##  - standing still she sinks and is swallowed in about 2 s (a heart, like falling in water)
##  - walking straight across 700 px of it she never goes under (no heart lost); nor does a TIRED cat
##    across 800 px (the longest stretch the fairness rule allows)
##  - jumping gets her out: she comes straight back up, and the jump is as high as ever
##  - the quicksand is drawn over her legs while she sinks, and not on firm sand
## Run: godot --headless --path . --script res://dev/m5_quicksand_test.gd

var _fails := 0
var _swallowed := 0
var level
var cat
var quick
var sand

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.get_node("Events").player_fell_in_water.connect(func(): _swallowed += 1)
	level = load("res://dev/sand_preview.tscn").instantiate()
	level.get_node("Objects/Slime1").free()   # the preview's slime sits on the quicksand block
	root.add_child(level)
	await _frames(80)
	cat = level.get_node("Player")
	quick = level.get_node("Terrain/Ground4")
	sand = level.get_node("Terrain/Ground1")
	var gs = root.get_node("GameState")

	await _place(sand, 200.0)
	_check("on sand: not on quicksand", not cat.on_quicksand, cat.on_quicksand)
	await _place(quick, 200.0)
	_check("on the quicksand block: on quicksand", cat.on_quicksand, cat.on_quicksand)

	var fast_sand: float = await _top_speed(sand, 150.0)
	var fast_quick: float = await _top_speed(quick, 150.0)
	_check("walks at about half speed on quicksand (%d vs %d px/s)" % [int(fast_quick), int(fast_sand)], absf(fast_quick / fast_sand - 0.5) < 0.05, [fast_quick, fast_sand])

	# Standing still: swallowed in about 2 s
	await _place(quick, 300.0)
	_swallowed = 0
	var hearts: int = gs.hearts
	var t := 0
	var cover_seen := false
	for i in 60 * 4:
		await physics_frame
		await process_frame
		cover_seen = cover_seen or cat.get_node("SandCover").visible
		t += 1
		if _swallowed > 0:
			break
	_check("standing still she sinks and is swallowed in about 2 s (%.1f s)" % (t / 60.0), _swallowed == 1 and t > 100 and t < 150, [_swallowed, t])
	_check("the quicksand is drawn over her while she sinks", cover_seen, cover_seen)
	await create_timer(1.5).timeout
	_check("...and it costs a heart", gs.hearts == hearts - 1, [hearts, gs.hearts])
	gs.hearts = 3

	# Walking straight across 700 px
	await _place(quick, 120.0)
	_swallowed = 0
	var deepest := 0.0
	var x0: float = cat.global_position.x
	Input.action_press("move_right")
	for i in 60 * 6:
		await physics_frame
		deepest = maxf(deepest, cat.sunk)
		if cat.global_position.x > x0 + 700.0:
			break
	Input.action_release("move_right")
	_check("walking across 700 px of quicksand she never goes under (deepest %d px of %d)" % [int(deepest), int(cat.SINK_UNDER)], _swallowed == 0 and deepest < cat.SINK_UNDER * 0.8 and cat.global_position.x > x0 + 700.0, [deepest, _swallowed])

	# The fairness rule's worst case: tired, walking straight across 800 px (the longest a stretch may be)
	await _place(quick, 100.0)
	cat.energy = 0.0
	_swallowed = 0
	deepest = 0.0
	x0 = cat.global_position.x
	Input.action_press("move_right")
	for i in 60 * 8:
		await physics_frame
		deepest = maxf(deepest, cat.sunk)
		if cat.global_position.x > x0 + 800.0 or _swallowed > 0:
			break
	Input.action_release("move_right")
	cat.energy = 1.0
	_check("tired, walking across 800 px (the longest allowed) she still never goes under (deepest %d px)" % int(deepest), _swallowed == 0 and cat.global_position.x > x0 + 800.0, [deepest, _swallowed])
	gs.hearts = 3

	# Jump out
	await _place(quick, 300.0)
	await _frames(50)   # sinking a while
	var before: float = cat.sunk
	var floor_y: float = cat.global_position.y
	var top := floor_y
	Input.action_press("jump")
	var up_again := -1
	for i in 60:
		await physics_frame
		top = minf(top, cat.global_position.y)
		if up_again < 0 and cat.sunk == 0.0:
			up_again = i
	Input.action_release("jump")
	_check("jumping out: she comes straight back up (from %d px, in %d frames)" % [int(before), up_again], before > 20.0 and up_again >= 0 and up_again < 15, [before, up_again])
	_check("a full jump from quicksand is as high as ever (%d px)" % int(floor_y - top), floor_y - top > 280.0, floor_y - top)

	await _place(sand, 300.0)
	await _frames(30)
	await process_frame
	_check("on firm sand: nothing drawn over her, not sunk", not cat.get_node("SandCover").visible and cat.sunk == 0.0, [cat.sunk])

	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _top_speed(block, from: float) -> float:
	await _place(block, from)
	var fastest := 0.0
	Input.action_press("move_right")
	for i in 50:
		await physics_frame
		fastest = maxf(fastest, cat.velocity.x)
	Input.action_release("move_right")
	await _frames(10)
	return fastest

func _place(block, x: float) -> void:
	cat.respawn_at(Vector2(block.global_position.x + x, block.global_position.y - 5.0))
	cat._safe_left = 0.0
	await _frames(6)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", name, str(got) if not ok else ""])
