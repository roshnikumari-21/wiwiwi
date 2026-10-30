extends SceneTree
## Headless check of the moving platform in level 1-1: it moves, carries the cat, gets her across the pit.
## Run: godot --headless --path . --script res://dev/m1_platform_test.gd

const LEVEL := "res://scenes/levels/w1/level_w1_01.tscn"

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var level = load(LEVEL).instantiate()
	root.add_child(level)
	var player = level.get_node("Player")
	var plank = level.get_node("Objects/MovingPlatform")
	var start_x: float = plank.global_position.x
	player.global_position = Vector2(start_x, 898)
	player.velocity = Vector2.ZERO
	await _frames(10)
	_check("cat stands on the plank", player.is_on_floor() and abs(player.global_position.y - 900.0) < 4.0, player.global_position)

	await _frames(150)   # 2.5 s: one full trip plus part of the pause
	var moved: float = plank.global_position.x - start_x
	_check("plank reached its far end", abs(moved - 210.0) < 3.0, moved)
	_check("cat was carried along", abs(player.global_position.x - plank.global_position.x) < 4.0 and player.is_on_floor(), [player.global_position, plank.global_position])

	Input.action_press("move_right")
	await _frames(30)
	Input.action_release("move_right")
	await _frames(10)
	_check("cat steps off the plank and reaches the girl", player.frozen and player.is_on_floor() and abs(player.global_position.y - 900.0) < 4.0, [player.global_position, player.frozen])

	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", name, str(got)])
