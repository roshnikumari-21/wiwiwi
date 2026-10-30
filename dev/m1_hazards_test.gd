extends SceneTree
## Headless check of spikes and the slime in level 1-1: hurt + respawn, safe time, side hit, stomp.
## Run: godot --headless --path . --script res://dev/m1_hazards_test.gd

const LEVEL := "res://scenes/levels/w1/level_w1_01.tscn"
const SPIKES_AT := Vector2(950, 900)

var _fails := 0
var _stomps := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var gs = root.get_node("GameState")
	root.get_node("Events").enemy_stomped.connect(func(): _stomps += 1)
	var level = load(LEVEL).instantiate()
	root.add_child(level)
	var player = level.get_node("Player")
	await _frames(80)   # let the start-of-level safe time run out

	# Spikes
	await _place(player, SPIKES_AT)
	_check("spikes cost a heart", gs.hearts == 2, gs.hearts)
	_check("hurt pose", player.frozen and player.sprite.animation == "hurt", player.sprite.animation)
	await _frames(50)
	_check("back at the start after the pause", player.global_position.distance_to(Vector2(200, 900)) < 5 and not player.frozen, player.global_position)
	await _place(player, SPIKES_AT)
	_check("safe right after respawn", gs.hearts == 2, gs.hearts)
	await _frames(80)
	player.global_position = Vector2(600, 900)
	await _place(player, SPIKES_AT)
	_check("hurt again once safe time ends", gs.hearts == 1, gs.hearts)
	await _frames(130)

	# Slime: walking into its side hurts
	var slime = level.get_node("Objects/Slime")
	_check("slime patrols", abs(slime.velocity.x) > 50.0, slime.velocity)
	gs.hearts = 3
	await _place(player, slime.global_position + Vector2(-40, 0))
	_check("slime side-hit costs a heart", gs.hearts == 2, gs.hearts)
	await _frames(130)

	# Slime: landing on top squashes it and bounces the cat, no heart lost
	player.global_position = slime.global_position + Vector2(0, -90)
	player.velocity = Vector2(0, 600)
	for i in 10:   # touch is reported a frame late; stop as soon as the stomp lands
		await physics_frame
		if _stomps > 0:
			break
	_check("stomp: slime squashed", _stomps == 1 and slime.sprite.animation == "squash", [_stomps, slime.sprite.animation])
	_check("stomp: cat bounces up", player.velocity.y < -500.0, player.velocity.y)
	_check("stomp: no heart lost", gs.hearts == 2, gs.hearts)
	await _frames(70)
	_check("squashed slime goes away", not is_instance_valid(slime), "")

	# Water: falling in splashes, she sinks, loses a heart and comes back at the respawn point.
	await _frames(80)
	gs.hearts = 3
	player.global_position = Vector2(1500, 960)
	player.velocity = Vector2(0, 400)
	for i in 30:   # until she reaches the water
		await physics_frame
		if player.frozen:
			break
	_check("water: she sinks (no control)", player.frozen, player.global_position)
	_check("water: splash shown", level.get_node("Objects/Water1").find_children("*", "CPUParticles2D", false, false).size() == 1, "")
	await _frames(60)   # the sinking pause, then the heart and the respawn
	_check("water: heart lost", gs.hearts == 2, gs.hearts)
	_check("water: back at the start, visible", player.global_position.distance_to(Vector2(200, 900)) < 5 and not player.frozen and player.sprite.modulate.a > 0.2, [player.global_position, player.sprite.modulate.a])

	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

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
