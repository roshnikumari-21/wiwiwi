extends SceneTree
## World 4 slippery ice, played like a player, on the snow preview level (one big block of ice):
##  - on ice she knows it (on_ice), on snow she doesn't
##  - letting go at full speed: on snow she stops in a few px, on ice she slides ~150-300 px
##  - starting from standing on ice she gets going slower than on snow
##  - turning around on ice takes longer than on snow
##  - she can still jump normally from ice (full height)
## Run: godot --headless --path . --script res://dev/m4_ice_test.gd

var _fails := 0
var level
var cat
var ice
var snow

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	level = load("res://dev/snow_preview.tscn").instantiate()
	root.add_child(level)
	await _frames(80)
	cat = level.get_node("Player")
	ice = level.get_node("Terrain/Ground4")
	snow = level.get_node("Terrain/Ground1")

	await _place(snow, 200.0)
	_check("on snow: not on ice", not cat.on_ice, cat.on_ice)
	await _place(ice, 200.0)
	_check("on the ice block: on ice", cat.on_ice, cat.on_ice)

	var stop_snow: float = await _run_and_let_go(snow, 150.0)
	var stop_ice: float = await _run_and_let_go(ice, 150.0)
	_check("let go at full speed: stops within 40 px on snow (%d px)" % int(stop_snow), stop_snow < 40.0, stop_snow)
	_check("on ice she slides on 150-300 px (%d px)" % int(stop_ice), stop_ice > 150.0 and stop_ice < 300.0, stop_ice)

	var t_snow: int = await _frames_to_full_speed(snow, 150.0)
	var t_ice: int = await _frames_to_full_speed(ice, 150.0)
	_check("from standing: slower to get going on ice (%d vs %d frames)" % [t_ice, t_snow], t_ice > t_snow * 2, [t_ice, t_snow])

	var turn_snow: int = await _frames_to_turn(snow, 150.0)
	var turn_ice: int = await _frames_to_turn(ice, 150.0)
	_check("turning around takes longer on ice (%d vs %d frames)" % [turn_ice, turn_snow], turn_ice > turn_snow * 2, [turn_ice, turn_snow])

	await _place(ice, 400.0)
	var floor_y: float = cat.global_position.y
	var top := floor_y
	Input.action_press("jump")
	for i in 60:
		await physics_frame
		top = minf(top, cat.global_position.y)
	Input.action_release("jump")
	_check("a full jump from ice is as high as ever (%d px)" % int(floor_y - top), floor_y - top > 280.0, floor_y - top)

	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

## Run right to full speed, let go, and measure how far she goes on before stopping.
func _run_and_let_go(block, from: float) -> float:
	await _place(block, from)
	Input.action_press("move_right")
	for i in 60:
		await physics_frame
		if absf(cat.velocity.x - cat.run_speed) < 2.0:
			break
	await _frames(5)
	Input.action_release("move_right")
	var x0: float = cat.global_position.x
	for i in 200:
		await physics_frame
		if absf(cat.velocity.x) < 1.0:
			break
	return cat.global_position.x - x0

func _frames_to_full_speed(block, from: float) -> int:
	await _place(block, from)
	Input.action_press("move_right")
	var n := 0
	for i in 200:
		await physics_frame
		n += 1
		if cat.velocity.x >= cat.run_speed * 0.95:
			break
	Input.action_release("move_right")
	await _frames(120)
	return n

## Running right at full speed, press left: frames until she's moving left.
func _frames_to_turn(block, from: float) -> int:
	await _place(block, from)
	Input.action_press("move_right")
	for i in 120:
		await physics_frame
		if cat.velocity.x >= cat.run_speed * 0.95:
			break
	Input.action_release("move_right")
	Input.action_press("move_left")
	var n := 0
	for i in 200:
		await physics_frame
		n += 1
		if cat.velocity.x < 0.0:
			break
	Input.action_release("move_left")
	await _frames(120)
	return n

func _place(block, x: float) -> void:
	cat.global_position = Vector2(block.global_position.x + x, block.global_position.y - 5.0)
	cat.velocity = Vector2.ZERO
	await _frames(6)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", name, str(got) if not ok else ""])
