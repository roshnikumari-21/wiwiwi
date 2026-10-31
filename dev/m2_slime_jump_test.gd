extends SceneTree
## Jumping at/over a slime from many distances, with a full jump and a quick tap, slime standing or
## walking toward the cat. While the cat is in the air a slime must never hurt her: she either clears
## it or stomps it. (Jumping from closer than 100 px means she already ran into it on the ground.)
## Walking into a slime on the ground still hurts (that's the rule).
## Run: godot --headless --path . --script res://dev/m2_slime_jump_test.gd

var SLIME: PackedScene

var _fails := 0
var _hurt := false
var _stomped := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	SLIME = load("res://scenes/actors/enemies/slime.tscn")
	root.get_node("Events").player_hurt.connect(func(): _hurt = true)
	root.get_node("Events").enemy_stomped.connect(func(): _stomped = true)
	var results := {"hurt": [], "stomp": 0, "clear": 0}
	for moving in [false, true]:
		for hold in [25, 4]:
			for d in range(100, 401, 20):
				var r: String = await _try(d, hold, moving)
				if r == "hurt":
					results.hurt.append("%s %s d=%d" % ["walking slime" if moving else "still slime", "full jump" if hold > 10 else "tap", d])
				else:
					results[r] += 1
	_check("no jump at a slime hurts the cat (%d stomps, %d clears)" % [results.stomp, results.clear], results.hurt.is_empty(), "\n    " + "\n    ".join(results.hurt))
	# walking straight into a slime still hurts
	var level = await _level()
	var cat = level.get_node("Player")
	var s = _slime(level, false)
	_hurt = false
	cat.global_position = Vector2(1900, 900)
	Input.action_press("move_right")
	for i in 120:
		await physics_frame
		if _hurt:
			break
	Input.action_release("move_right")
	_check("walking into a slime on the ground still hurts", _hurt, "")
	level.queue_free()
	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _level():
	var level = load("res://scenes/levels/w1/level_w1_01.tscn").instantiate()
	root.add_child(level)
	for o in level.get_node("Objects").get_children():
		o.queue_free()   # an empty stretch: Ground2 is flat from 1600 to 2500
	for i in 80:
		await physics_frame
	return level

func _slime(level, moving: bool):
	var s = SLIME.instantiate()
	s.position = Vector2(2150, 900)
	s.patrol_distance = 160.0 if moving else 0.0
	s.speed = 90.0 if moving else 0.0
	s.start_left = true   # walks toward the cat
	level.get_node("Objects").add_child(s)
	return s

func _try(d: int, hold: int, moving: bool) -> String:
	var level = await _level()
	var cat = level.get_node("Player")
	var s = _slime(level, moving)
	await physics_frame
	_hurt = false
	_stomped = false
	cat.global_position = Vector2(1650, 900)
	cat.velocity = Vector2.ZERO
	Input.action_press("move_right")
	while cat.global_position.x < s.global_position.x - d and cat.global_position.x < 2400.0:
		await physics_frame
		if _hurt:
			break
	if not _hurt:
		Input.action_press("jump")
		for i in 90:
			await physics_frame
			if i == hold:
				Input.action_release("jump")
			if i > 3 and cat.is_on_floor():
				Input.action_release("move_right")   # landed: stop, like a player who cleared it
				break
			if _hurt or _stomped:
				break
	Input.action_release("jump")
	Input.action_release("move_right")
	var result := "hurt" if _hurt else ("stomp" if _stomped else "clear")
	level.queue_free()
	await physics_frame
	return result

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, str(got) if not ok else ""])
