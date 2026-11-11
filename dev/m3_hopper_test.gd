extends SceneTree
## World 2 hopper slime: it really hops (leaves the ground about hop_height up), moves along and
## stays on its patrol path, turning at the ends; the slime's contact rules still hold: landing on
## it from above squashes it, walking into it on the ground hurts, and jumping over it never does.
## Run: godot --headless --path . --script res://dev/m3_hopper_test.gd

const HOME := Vector2(600, 900)   # level 1-1's first ground (y 900, 0-1400 wide; its spikes are removed)

var _fails := 0
var _hurt := false
var _stomped := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var events = root.get_node("Events")
	events.player_hurt.connect(func(): _hurt = true)
	events.enemy_stomped.connect(func(): _stomped = true)

	# Hopping and patrol (cat parked far away)
	var level = await _level()
	var cat = level.get_node("Player")
	cat.global_position = Vector2(3700, 880)
	var h = _hopper(level)
	var top := HOME.y
	var xs := []
	for i in 60 * 12:
		await physics_frame
		top = minf(top, h.global_position.y)
		xs.append(h.global_position.x)
	var reach: float = h.patrol_distance + h.hop_length
	_check("it hops about hop_height up (%d px)" % int(HOME.y - top), HOME.y - top > h.hop_height * 0.8 and HOME.y - top < h.hop_height * 1.2, HOME.y - top)
	_check("it moves along its path (%d px covered)" % int(xs.max() - xs.min()), xs.max() - xs.min() > h.patrol_distance, [xs.min(), xs.max()])
	_check("it stays on its patrol path and turns at the ends", xs.min() > HOME.x - reach and xs.max() < HOME.x + reach, [xs.min(), xs.max()])
	level.queue_free()
	await _frames(2)

	# Landing on it squashes it (from high above, wherever it is in its hop)
	level = await _level()
	cat = level.get_node("Player")
	h = _hopper(level)
	await _frames(30)
	_stomped = false
	_hurt = false
	cat.global_position = h.global_position + Vector2(0, -420)
	cat.velocity = Vector2.ZERO
	for i in 90:
		cat.global_position.x = h.global_position.x   # follow it while falling, like a player aiming
		await physics_frame
		if _stomped:
			break
	_check("landing on it from above squashes it, no heart lost", _stomped and not _hurt, [_stomped, _hurt])
	level.queue_free()
	await _frames(2)

	# Walking into it on the ground hurts
	level = await _level()
	cat = level.get_node("Player")
	h = _hopper(level)
	h.hop_every = 99.0   # it sits still
	await _frames(20)
	_hurt = false
	cat.global_position = HOME + Vector2(-260, -5)
	Input.action_press("move_right")
	for i in 120:
		await physics_frame
		if _hurt:
			break
	Input.action_release("move_right")
	_check("walking into it on the ground hurts", _hurt, "")
	level.queue_free()
	await _frames(2)

	# Jumping over it (full jump from 140-320 px away, at different moments of its hopping, a hopper
	# hopping back and forth in place or travelling a longer path) never hurts
	var hurts := []
	var tries := 0
	for patrol in [0.0, 150.0]:
		for wait in [20, 45, 70]:
			for d in range(140, 321, 30):
				tries += 1
				if await _jump_over(d, patrol, wait):
					hurts.append("path %d, wait %d, from %d px" % [int(patrol), wait, d])
	_check("jumping over a hopper never hurts (%d jumps)" % tries, hurts.is_empty(), "\n    " + "\n    ".join(hurts))

	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

## One full jump over a hopper; true if she got hurt during the jump.
func _jump_over(d: int, patrol: float, wait: int) -> bool:
	var level = await _level()
	var cat = level.get_node("Player")
	var h = _hopper(level)
	h.patrol_distance = patrol
	await _frames(wait)
	_hurt = false
	_stomped = false
	var hx: float = h.global_position.x
	cat.global_position = Vector2(hx - d, HOME.y - 5)
	await _frames(3)
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(25)
	Input.action_release("jump")
	for i in 90:
		await physics_frame
		if _hurt or (cat.is_on_floor() and cat.global_position.x > hx + 80):
			break   # landed past it (or squashed it on the way: also fine)
	var hurt := _hurt   # only the jump itself counts; after landing she keeps running, like a player
	Input.action_release("move_right")
	level.queue_free()
	await _frames(2)
	return hurt

func _level():
	var level = load("res://scenes/levels/w1/level_w1_01.tscn").instantiate()
	level.get_node("Objects/Spikes").free()   # 1-1's spikes at x 950: a squash bounce can land there
	root.add_child(level)
	await _frames(80)   # the start-of-level safe time runs out
	return level

func _hopper(level):
	var h = load("res://scenes/actors/enemies/hopper_slime.tscn").instantiate()
	h.position = HOME
	h.patrol_distance = 150.0
	level.get_node("Objects").add_child(h)
	return h

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", name, str(got) if not ok else ""])
