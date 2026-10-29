extends SceneTree
## Headless check of energy + milk in level 1-1: drain, tired speed, sleepy idle, HUD bar, milk bowl.
## Run: godot --headless --path . --script res://dev/m1_energy_test.gd

const LEVEL := "res://scenes/levels/w1/level_w1_01.tscn"
const BOWL_AT := Vector2(2250, 900)

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var level = load(LEVEL).instantiate()
	root.add_child(level)
	var player = level.get_node("Player")
	var bar = level.get_node("Hud/SafeArea/Hud/Energy/Bar")
	var bowl_sprite = level.get_node("Objects/MilkBowl/Sprite")
	await _frames(3)
	_check("starts at 40 %", is_equal_approx(player.energy, 0.4), player.energy)
	_check("HUD bar shows it", is_equal_approx(bar.value, 0.4), bar.value)

	await _frames(60)
	_check("standing still costs nothing", is_equal_approx(player.energy, 0.4), player.energy)

	Input.action_press("move_right")
	await _frames(60)
	Input.action_release("move_right")
	var used: float = 0.4 - player.energy
	_check("1 s of running uses about 1/35", used > 0.022 and used < 0.032, used)

	# Out of energy: slower, slower legs, sleepy when standing.
	player.global_position = Vector2(300, 900)
	player.energy = 0.0
	await _frames(20)
	_check("HUD bar orange when low", bar.modulate != Color.WHITE, bar.modulate)
	Input.action_press("move_right")
	var top := 0.0
	for i in 40:
		await physics_frame
		top = max(top, player.velocity.x)
	_check("tired: top speed 65 %", abs(top - 520.0 * 0.65) < 5.0, top)
	_check("tired: slower walk animation", player.sprite.animation == "walk" and is_equal_approx(player.sprite.speed_scale, 0.65), [player.sprite.animation, player.sprite.speed_scale])
	Input.action_release("move_right")
	await _frames(30)
	_check("tired: sleepy when standing", player.sprite.animation == "sleepy", player.sprite.animation)

	# Milk bowl: not drunk at full energy, drunk when thirsty, then empty.
	player.energy = 1.0
	await _place(player, BOWL_AT)
	_check("full cat leaves the bowl", bowl_sprite.texture.resource_path.ends_with("milk_bowl_full.png"), bowl_sprite.texture.resource_path)
	player.energy = 0.3
	await _frames(4)
	_check("thirsty cat drinks: full energy", is_equal_approx(player.energy, 1.0), player.energy)
	_check("bowl is now empty", bowl_sprite.texture.resource_path.ends_with("milk_bowl_empty.png"), bowl_sprite.texture.resource_path)
	_check("HUD bar full and white", is_equal_approx(bar.value, 1.0) and bar.modulate == Color.WHITE, [bar.value, bar.modulate])
	player.energy = 0.3
	await _place(player, BOWL_AT)
	_check("empty bowl gives nothing", is_equal_approx(player.energy, 0.3), player.energy)

	# Never a fail: a tired cat still clears the widest gap (the 300 px drop after the flag).
	player.energy = 0.0
	await _place(player, Vector2(2900, 760))
	Input.action_press("move_right")
	while player.global_position.x < 3190.0:
		await physics_frame
	Input.action_press("jump")
	await _frames(70)
	Input.action_release("jump")
	Input.action_release("move_right")
	_check("tired cat clears the 300 px gap", player.is_on_floor() and player.global_position.x > 3500.0 and player.global_position.y < 910.0, player.global_position)

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
