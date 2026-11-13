extends SceneTree
## World 4's creatures and boxes, played like a player:
## Penguin: waddles, warns (crouch), then slides fast along its whole path and back to waddling;
## landing on it squashes it (even mid-slide); walking into it hurts; a full jump over it while it
## slides toward her clears it.
## Blue slime: blue (recoloured), behaves like a slime (stomp = squash).
## Gift box: bumping it from below pops a coin and it turns into the used gift box.
## Falling icicle (the pinecone hazard, icicle look): shows the icicle pictures, warns, falls straight
## down without spinning and hurts if she stays under it; running on during the warning is safe.
## Run: godot --headless --path . --script res://dev/m4_snow_creatures_test.gd

const GROUND := 900.0   # level 1-1's first ground (x 0-1400; its spikes at x 950 are removed)

var _fails := 0
var _hurt := 0
var _stomped := 0
var _coins := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var events = root.get_node("Events")
	events.player_hurt.connect(func(): _hurt += 1)
	events.enemy_stomped.connect(func(): _stomped += 1)
	events.coin_collected.connect(func(): _coins += 1)
	var P = load("res://scenes/actors/enemies/penguin.gd")

	# Penguin rhythm
	var level = await _level()
	var cat = level.get_node("Player")
	cat.global_position = Vector2(80, GROUND - 5)
	var pg = _add(level, "penguin", Vector2(800, GROUND), 220.0)
	var modes := {}
	var fastest := 0.0
	var xs := []
	for i in 60 * 8:
		await physics_frame
		modes[pg.mode] = true
		fastest = maxf(fastest, absf(pg.velocity.x))
		xs.append(pg.global_position.x)
	_check("the penguin waddles, warns and slides (all three seen)", modes.size() == 3, modes.keys())
	_check("it slides fast (%d px/s) and stays on its path" % int(fastest), fastest > 400.0 and xs.min() > 800.0 - 220.0 - 60.0 and xs.max() < 800.0 + 220.0 + 60.0, [fastest, xs.min(), xs.max()])
	level.queue_free()
	await _frames(2)

	# Stomp it mid-slide
	level = await _level()
	cat = level.get_node("Player")
	pg = _add(level, "penguin", Vector2(800, GROUND), 220.0)
	for i in 600:
		await physics_frame
		if pg.mode == P.Mode.SLIDE:
			break
	_stomped = 0
	_hurt = 0
	cat.global_position = pg.global_position + Vector2(0, -300)
	cat.velocity = Vector2.ZERO
	for i in 60:
		cat.global_position.x = pg.global_position.x
		await physics_frame
		if _stomped > 0 or _hurt > 0:
			break
	_check("landing on a sliding penguin squashes it, no heart lost", _stomped == 1 and _hurt == 0, [_stomped, _hurt])
	level.queue_free()
	await _frames(2)

	# Walking into a waddling penguin hurts
	level = await _level()
	cat = level.get_node("Player")
	pg = _add(level, "penguin", Vector2(800, GROUND), 0.0)
	pg.waddle_time = 99.0
	pg._timer = 99.0
	await _frames(10)
	_hurt = 0
	cat.global_position = Vector2(560, GROUND - 5)
	Input.action_press("move_right")
	for i in 120:
		await physics_frame
		if _hurt > 0:
			break
	Input.action_release("move_right")
	_check("walking into a penguin hurts", _hurt == 1, _hurt)
	level.queue_free()
	await _frames(2)

	# Jump over a penguin sliding toward her
	var hurts := []
	for d in [120, 170, 220]:
		level = await _level()
		cat = level.get_node("Player")
		pg = _add(level, "penguin", Vector2(900, GROUND), 250.0)
		pg.global_position.x = 1150.0   # at its right end: its next slide comes left, toward her
		for i in 600:
			await physics_frame
			if pg.mode == P.Mode.WARN:
				break
		cat.global_position = Vector2(500, GROUND - 5)
		cat.velocity = Vector2.ZERO
		await _frames(2)
		_hurt = 0
		_stomped = 0
		Input.action_press("move_right")
		for i in 240:   # run toward it; jump when it's d px away
			await physics_frame
			if pg.global_position.x - cat.global_position.x < d:
				break
		Input.action_press("jump")
		await _frames(25)
		Input.action_release("jump")
		for i in 90:
			await physics_frame
			if _hurt > 0 or (cat.is_on_floor() and (cat.global_position.x > pg.global_position.x + 60.0 or _stomped > 0)):
				break
		Input.action_release("move_right")
		if _hurt > 0:
			hurts.append(d)
		level.queue_free()
		await _frames(2)
	_check("jumping over a penguin sliding at her never hurts", hurts.is_empty(), hurts)

	# Blue slime
	level = await _level()
	cat = level.get_node("Player")
	var blue = _add(level, "blue_slime", Vector2(800, GROUND), 0.0)
	await _frames(5)
	_check("the blue slime is recoloured blue", blue.get_node("Sprite").material != null and absf(blue.get_node("Sprite").material.get_shader_parameter("hue_shift") - 0.36) < 0.01, "")
	_stomped = 0
	cat.global_position = blue.global_position + Vector2(0, -260)
	cat.velocity = Vector2.ZERO
	for i in 60:
		await physics_frame
		if _stomped > 0:
			break
	_check("a blue slime is stomped like a slime", _stomped == 1, _stomped)
	level.queue_free()
	await _frames(2)

	# Gift box
	level = await _level()
	cat = level.get_node("Player")
	var gift = load("res://scenes/objects/bump_crate.tscn").instantiate()
	gift.look = "gift"
	gift.coins = 1
	gift.position = Vector2(400, 700)
	level.get_node("Objects").add_child(gift)
	await _frames(5)
	_check("a gift box shows the full gift picture", gift.sprite.texture.resource_path.ends_with("gift_full.png"), gift.sprite.texture.resource_path)
	_coins = 0
	cat.global_position = Vector2(400, GROUND - 5)
	cat.velocity = Vector2.ZERO
	await _frames(6)
	Input.action_press("jump")
	await _frames(20)
	Input.action_release("jump")
	await _frames(60)
	_check("bumping it pops a coin and it becomes the used gift box", _coins == 1 and gift.sprite.texture.resource_path.ends_with("gift_used.png"), [_coins, gift.sprite.texture.resource_path])
	level.queue_free()

	# Falling icicle
	var IC = load("res://scenes/objects/pinecone.gd")
	level = await _level()
	cat = level.get_node("Player")
	var icicle = _icicle(level, Vector2(500, GROUND))
	await _frames(3)
	_check("an icicle shows the hanging icicle picture", icicle._cone.texture.resource_path.ends_with("icicle_hanging.png"), icicle._cone.texture.resource_path)
	_hurt = 0
	cat.global_position = Vector2(500, GROUND - 5)
	cat.velocity = Vector2.ZERO
	var spun := false
	var seen_falling := false
	for i in 60 * 3:
		await physics_frame
		if icicle.state == IC.State.FALLING:
			seen_falling = true
			spun = spun or absf(icicle._cone.rotation) > 0.01
			if not icicle._cone.texture.resource_path.ends_with("icicle_falling.png"):
				spun = true
	_check("it falls straight down (no spin) and hurts her if she stays under it", seen_falling and not spun and _hurt == 1, [seen_falling, spun, _hurt])
	level.queue_free()
	await _frames(2)

	level = await _level()
	cat = level.get_node("Player")
	icicle = _icicle(level, Vector2(500, GROUND))
	_hurt = 0
	cat.global_position = Vector2(500, GROUND - 5)
	cat.velocity = Vector2.ZERO
	await create_timer(icicle.warn_time * 0.4).timeout
	Input.action_press("move_right")   # sees the shadow, runs on
	await create_timer(0.5).timeout
	Input.action_release("move_right")
	await create_timer(icicle.warn_time + 1.0).timeout
	_check("running on during its warning keeps her safe", _hurt == 0 and icicle.state == IC.State.DONE, [_hurt, icicle.state])
	level.queue_free()

	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _add(level, kind: String, at: Vector2, patrol: float):
	var n = load("res://scenes/actors/enemies/%s.tscn" % kind).instantiate()
	n.position = at
	n.patrol_distance = patrol
	level.get_node("Objects").add_child(n)
	return n

func _icicle(level, at: Vector2):
	var c = load("res://scenes/objects/pinecone.tscn").instantiate()
	c.look = "icicle"
	c.height = 281.0
	c.position = at
	level.get_node("Objects").add_child(c)
	return c

func _level():
	var level = load("res://scenes/levels/w1/level_w1_01.tscn").instantiate()
	level.get_node("Objects/Spikes").free()
	root.add_child(level)
	await _frames(80)
	return level

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", name, str(got) if not ok else ""])
