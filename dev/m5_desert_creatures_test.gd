extends SceneTree
## World 5's creatures and objects, played like a player:
## Sand mole: tunnels (a moving mound), trembles (the warning), pops up and looks around, dives again.
##   Over the mound while it tunnels: nothing happens (no hurt, no squash). Standing on the trembling
##   mound when it pops up: hurt. Up: stomp it (squash, no hurt); walking into it hurts.
## Yellow slime: recoloured sand-yellow, stomped like a slime.
## Clay pot: bumping it from below pops a coin and it turns into the used pot.
## Coconut: hangs on its stem, falls tumbling, hurts if she stays under it, cracks open (no roll).
## Cactus spikes: the cactus picture, same size as the meadow spikes, touching them hurts.
## Run: godot --headless --path . --script res://dev/m5_desert_creatures_test.gd

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
	var M = load("res://scenes/actors/enemies/mole.gd")

	# Mole rhythm
	var level = await _level()
	var cat = level.get_node("Player")
	cat.global_position = Vector2(80, GROUND - 5)
	var mole = _add(level, "mole", Vector2(800, GROUND), 200.0)
	var modes := {}
	var xs := []
	var anims := {}
	for i in 60 * 10:
		await physics_frame
		modes[mole.mode] = true
		anims[String(mole.sprite.animation)] = true
		xs.append(mole.global_position.x)
	_check("the mole tunnels, trembles and pops up (all three seen)", modes.size() == 3, modes.keys())
	_check("it shows the mound, the pop and the looking-around pictures", anims.has("mound") and anims.has("pop") and anims.has("look"), anims.keys())
	_check("it stays on its path", xs.min() > 800.0 - 200.0 - 40.0 and xs.max() < 800.0 + 200.0 + 40.0, [xs.min(), xs.max()])
	level.queue_free()
	await _frames(2)

	# Over the mound while it tunnels: nothing. On the trembling mound when it pops: hurt.
	level = await _level()
	cat = level.get_node("Player")
	mole = _add(level, "mole", Vector2(800, GROUND), 0.0)
	await _frames(3)
	mole._timer = 1.5
	_hurt = 0
	_stomped = 0
	cat.global_position = Vector2(800, GROUND - 260)   # lands right on the tunnelling mound
	cat.velocity = Vector2.ZERO
	await _frames(40)
	_check("landing on the tunnelling mound: nothing happens", _hurt == 0 and _stomped == 0 and mole.mode != M.Mode.UP, [_hurt, _stomped, mole.mode])
	for i in 200:
		await physics_frame
		if mole.mode == M.Mode.UP:
			break
	await _frames(2)
	_check("standing on it when it pops up: it bumps her (hurt)", _hurt == 1, _hurt)
	level.queue_free()
	await _frames(2)

	# Stomp it while it's up
	level = await _level()
	cat = level.get_node("Player")
	mole = _add(level, "mole", Vector2(800, GROUND), 0.0)
	await _frames(3)
	mole._timer = 0.1
	for i in 120:
		await physics_frame
		if mole.mode == M.Mode.UP:
			break
	_hurt = 0
	_stomped = 0
	cat.global_position = mole.global_position + Vector2(0, -260)
	cat.velocity = Vector2.ZERO
	for i in 60:
		cat.global_position.x = mole.global_position.x
		await physics_frame
		if _stomped > 0 or _hurt > 0:
			break
	_check("landing on the mole while it's up squashes it, no heart lost", _stomped == 1 and _hurt == 0, [_stomped, _hurt])
	level.queue_free()
	await _frames(2)

	# Walking into it while it's up hurts
	level = await _level()
	cat = level.get_node("Player")
	mole = _add(level, "mole", Vector2(800, GROUND), 0.0)
	await _frames(3)
	mole.up_time = 99.0
	mole._timer = 0.1
	for i in 120:
		await physics_frame
		if mole.mode == M.Mode.UP:
			break
	_hurt = 0
	cat.global_position = Vector2(560, GROUND - 5)
	Input.action_press("move_right")
	for i in 120:
		await physics_frame
		if _hurt > 0:
			break
	Input.action_release("move_right")
	_check("walking into the mole while it's up hurts", _hurt == 1, _hurt)
	level.queue_free()
	await _frames(2)

	# Yellow slime
	level = await _level()
	cat = level.get_node("Player")
	var yellow = _add(level, "yellow_slime", Vector2(800, GROUND), 0.0)
	await _frames(5)
	var mat = yellow.get_node("Sprite").material
	_check("the yellow slime is recoloured sand-yellow", mat != null and absf(mat.get_shader_parameter("target_hue") - 0.13) < 0.01, "")
	_stomped = 0
	cat.global_position = yellow.global_position + Vector2(0, -260)
	cat.velocity = Vector2.ZERO
	for i in 60:
		await physics_frame
		if _stomped > 0:
			break
	_check("a yellow slime is stomped like a slime", _stomped == 1, _stomped)
	level.queue_free()
	await _frames(2)

	# Clay pot
	level = await _level()
	cat = level.get_node("Player")
	var pot = load("res://scenes/objects/bump_crate.tscn").instantiate()
	pot.look = "pot"
	pot.coins = 1
	pot.position = Vector2(400, 700)
	level.get_node("Objects").add_child(pot)
	await _frames(5)
	_check("a clay pot shows the full pot picture", pot.sprite.texture.resource_path.ends_with("pot_full.png"), pot.sprite.texture.resource_path)
	_coins = 0
	cat.global_position = Vector2(400, GROUND - 5)
	cat.velocity = Vector2.ZERO
	await _frames(6)
	Input.action_press("jump")
	await _frames(20)
	Input.action_release("jump")
	await _frames(60)
	_check("bumping it pops a coin and it becomes the used pot", _coins == 1 and pot.sprite.texture.resource_path.ends_with("pot_used.png"), [_coins, pot.sprite.texture.resource_path])
	level.queue_free()
	await _frames(2)

	# Coconut
	var C = load("res://scenes/objects/pinecone.gd")
	level = await _level()
	cat = level.get_node("Player")
	var coco = load("res://scenes/objects/pinecone.tscn").instantiate()
	coco.look = "coconut"
	coco.position = Vector2(500, GROUND)
	level.get_node("Objects").add_child(coco)
	await _frames(3)
	_check("a coconut hangs on its stem (the hanging picture)", coco._cone.texture.resource_path.ends_with("coconut_hanging.png"), coco._cone.texture.resource_path)
	_hurt = 0
	cat.global_position = Vector2(500, GROUND - 5)
	cat.velocity = Vector2.ZERO
	var spun := false
	var nut = null
	var landed_x := 0.0
	for i in 60 * 3:
		await physics_frame
		if coco.state == C.State.FALLING:
			spun = spun or absf(coco._cone.rotation) > 0.1
		if coco.state == C.State.DONE and nut == null:
			nut = coco._cone
			landed_x = nut.position.x
			break
	await _frames(20)   # a cone would be rolling by now (it fades out a second after landing)
	var rolled: float = absf(nut.position.x - landed_x) if nut != null and is_instance_valid(nut) else 999.0
	_check("it tumbles as it falls and hurts her if she stays under it", spun and _hurt == 1, [spun, _hurt])
	_check("it cracks open where it lands (no roll)", nut != null and rolled < 2.0, rolled)
	level.queue_free()
	await _frames(2)

	# Cactus spikes
	level = await _level()
	cat = level.get_node("Player")
	var meadow = load("res://scenes/objects/spikes.tscn").instantiate()
	var cactus = load("res://scenes/objects/spikes.tscn").instantiate()
	cactus.look = "cactus"
	meadow.position = Vector2(1200, GROUND)
	cactus.position = Vector2(600, GROUND)
	level.get_node("Objects").add_child(meadow)
	level.get_node("Objects").add_child(cactus)
	await _frames(3)
	var cs: Vector2 = cactus.get_node("Shape").shape.size
	var ms: Vector2 = meadow.get_node("Shape").shape.size
	_check("cactus spikes show the cactus picture", cactus.get_node("Sprite").texture.resource_path.ends_with("spikes_cactus_short.png"), "")
	_check("they're as tall as the meadow spikes (%d vs %d px)" % [int(cs.y), int(ms.y)], absf(cs.y - ms.y) < 1.0, [cs, ms])
	_hurt = 0
	cat.global_position = Vector2(400, GROUND - 5)
	Input.action_press("move_right")
	for i in 120:
		await physics_frame
		if _hurt > 0:
			break
	Input.action_release("move_right")
	_check("walking into cactus spikes hurts", _hurt == 1, _hurt)
	level.queue_free()

	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _add(level, kind: String, at: Vector2, patrol: float):
	var n = load("res://scenes/actors/enemies/%s.tscn" % kind).instantiate()
	n.position = at
	n.patrol_distance = patrol
	level.get_node("Objects").add_child(n)
	return n

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
