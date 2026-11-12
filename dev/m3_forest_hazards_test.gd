extends SceneTree
## World 3's hedgehog and pinecone, played like a player.
## Hedgehog: walks its path; landing on it HURTS (no stomping); walking into it hurts; a full jump
## taken 100-240 px before it never hurts (measured 12 Nov 2026: 100-300 px clears a standing one,
## 100-240 px one walking toward her; from farther she comes down on its spines, which is the point).
## Pinecone: waits until the cat is near; then shakes with a growing shadow for warn_time before it
## drops (the warning); standing under it gets her hurt; stepping away during the warning keeps her
## safe; with `every` set it drops again and again.
## Run: godot --headless --path . --script res://dev/m3_forest_hazards_test.gd

const GROUND := 900.0   # level 1-1's first ground (x 0-1400; its spikes at x 950 are removed)

var _fails := 0
var _hurt := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.get_node("Events").player_hurt.connect(func(): _hurt += 1)
	var C = load("res://scenes/objects/pinecone.gd")

	# --- Hedgehog ---
	var level = await _level()
	var cat = level.get_node("Player")
	var hog = _hedgehog(level, Vector2(700, GROUND), 120.0)
	var xs := []
	for i in 240:
		await physics_frame
		xs.append(hog.global_position.x)
	_check("the hedgehog walks its path", xs.max() - xs.min() > 150.0 and xs.min() > 700.0 - 120.0 - 30.0 and xs.max() < 700.0 + 120.0 + 30.0, [xs.min(), xs.max()])
	_hurt = 0
	await _place(cat, hog.global_position + Vector2(0, -260))
	for i in 60:
		cat.global_position.x = hog.global_position.x
		await physics_frame
		if _hurt > 0:
			break
	_check("landing on a hedgehog hurts (no stomping)", _hurt == 1 and is_instance_valid(hog) and not hog._squashed, _hurt)
	level.queue_free()
	await _frames(2)

	level = await _level()
	cat = level.get_node("Player")
	hog = _hedgehog(level, Vector2(700, GROUND), 0.0)
	await _frames(10)
	_hurt = 0
	await _place(cat, Vector2(440, GROUND - 5))
	Input.action_press("move_right")
	for i in 120:
		await physics_frame
		if _hurt > 0:
			break
	Input.action_release("move_right")
	_check("walking into a hedgehog hurts", _hurt == 1, _hurt)
	level.queue_free()
	await _frames(2)

	var hurts := []
	var tries := 0
	for patrol in [0.0, 120.0]:
		for wait in [10, 60]:
			for d in range(100, 241, 20):
				tries += 1
				if await _jump_over(d, patrol, wait):
					hurts.append("path %d, wait %d, from %d px" % [int(patrol), wait, d])
	_check("jumping over a hedgehog never hurts (%d jumps)" % tries, hurts.is_empty(), "\n    " + "\n    ".join(hurts))

	# --- Pinecone ---
	level = await _level()
	cat = level.get_node("Player")
	var cone = _pinecone(level, Vector2(500, GROUND), 0.0)
	await _place(cat, Vector2(1300, GROUND - 5))   # 800 px away: too far to wake it
	await create_timer(1.5).timeout
	_check("a pinecone waits while the cat is far away", cone.state == C.State.WAITING, cone.state)
	_hurt = 0
	await _place(cat, Vector2(500, GROUND - 5))   # right under it
	await create_timer(cone.warn_time * 0.5).timeout
	_check("when she comes near it warns first: shaking, shadow growing", cone.state == C.State.WARNING and cone._shadow.scale.x > 0.2, [cone.state, cone._shadow.scale])
	await create_timer(cone.warn_time + 1.0).timeout
	_check("standing under it: it drops and hurts her", _hurt == 1 and cone.state == C.State.DONE, [_hurt, cone.state])
	level.queue_free()
	await _frames(2)

	level = await _level()
	cat = level.get_node("Player")
	cone = _pinecone(level, Vector2(500, GROUND), 0.0)
	_hurt = 0
	await _place(cat, Vector2(500, GROUND - 5))
	await create_timer(cone.warn_time * 0.4).timeout
	Input.action_press("move_right")   # sees the shadow, runs on
	await create_timer(0.5).timeout
	Input.action_release("move_right")
	await create_timer(cone.warn_time + 1.0).timeout
	_check("running on during the warning keeps her safe", _hurt == 0 and cone.state == C.State.DONE, [_hurt, cone.state])
	level.queue_free()
	await _frames(2)

	level = await _level()
	cat = level.get_node("Player")
	cone = _pinecone(level, Vector2(500, GROUND), 1.6)
	await _place(cat, Vector2(800, GROUND - 5))   # near, but not under it
	var drops := 0
	var was_falling := false
	for i in 60 * 8:
		await physics_frame
		var falling: bool = cone.state == C.State.FALLING
		if falling and not was_falling:
			drops += 1
		was_falling = falling
	_check("with 'every' set it drops again and again (%d drops in 8 s)" % drops, drops >= 2, drops)
	level.queue_free()

	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _jump_over(d: int, patrol: float, wait: int) -> bool:
	var level = await _level()
	var cat = level.get_node("Player")
	var hog = _hedgehog(level, Vector2(700, GROUND), patrol)
	await _frames(wait)
	_hurt = 0
	var hx: float = hog.global_position.x
	await _place(cat, Vector2(hx - d, GROUND - 5))
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(25)
	Input.action_release("jump")
	for i in 90:
		await physics_frame
		if _hurt > 0 or (cat.is_on_floor() and cat.global_position.x > hog.global_position.x + 90.0):
			break
	var hurt := _hurt > 0
	Input.action_release("move_right")
	level.queue_free()
	await _frames(2)
	return hurt

func _level():
	var level = load("res://scenes/levels/w1/level_w1_01.tscn").instantiate()
	level.get_node("Objects/Spikes").free()
	root.add_child(level)
	await _frames(80)   # the start-of-level safe time runs out
	return level

func _hedgehog(level, at: Vector2, patrol: float):
	var h = load("res://scenes/actors/enemies/hedgehog.tscn").instantiate()
	h.position = at
	h.patrol_distance = patrol
	level.get_node("Objects").add_child(h)
	return h

func _pinecone(level, at: Vector2, every: float):
	var c = load("res://scenes/objects/pinecone.tscn").instantiate()
	c.position = at
	c.every = every
	level.get_node("Objects").add_child(c)
	return c

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
