extends SceneTree
## Bump crates, played like a player: jumping into one from below pops out a coin that counts as
## picked up (and the crate turns plain when empty); a 3-coin crate needs 3 bumps; a milk crate puts a
## bowl of milk on top; the cat can stand on a crate; running into its side gives nothing; and the
## level's coin total includes the crates' coins.
## Run: godot --headless --path . --script res://dev/m3_crate_test.gd

const GROUND := 900.0          # level 1-1's first ground (x 0-1400; its spikes at x 950 are removed)
const CRATE_BOTTOM := 700.0    # 200 px above the ground: a jump reaches it, walking under it is fine

var _fails := 0
var _coins := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.get_node("Events").coin_collected.connect(func(): _coins += 1)
	var gs = root.get_node("GameState")

	# Coin totals include crates (counted when the level starts)
	var level = load("res://scenes/levels/w1/level_w1_01.tscn").instantiate()
	level.get_node("Objects/Spikes").free()
	var plain_coins: int = level.get_node("Objects").get_children().filter(func(n): return n.is_in_group("coins")).size()
	var one = _crate(level, Vector2(400, CRATE_BOTTOM), 1, false)
	var three = _crate(level, Vector2(800, CRATE_BOTTOM), 3, false)
	var milky = _crate(level, Vector2(1150, CRATE_BOTTOM), 0, true)
	root.add_child(level)
	await _frames(80)
	_check("the level's coin total includes the crates' 4 coins", gs.coin_total == plain_coins + 4, [gs.coin_total, plain_coins])
	var cat = level.get_node("Player")

	# One-coin crate
	_coins = 0
	await _jump_under(cat, 400.0)
	_check("jumping into a crate from below pops out a coin (counted)", _coins == 1, _coins)
	_check("then it's empty: the plain crate", one.is_empty() and one.sprite.texture == one.USED, one.is_empty())
	await _jump_under(cat, 400.0)
	_check("bumping an empty crate gives nothing", _coins == 1, _coins)

	# Three-coin crate
	_coins = 0
	for i in 3:
		await _jump_under(cat, 800.0)
	_check("a 3-coin crate: 3 bumps, 3 coins, then empty", _coins == 3 and three.is_empty(), [_coins, three.is_empty()])

	# Milk crate
	await _jump_under(cat, 1150.0)
	var bowl = milky.find_children("*", "Area2D", true, false)
	_check("a milk crate puts a bowl of milk on top", bowl.size() == 1 and milky.is_empty(), bowl.size())

	# Standing on top
	await _place(cat, Vector2(800, CRATE_BOTTOM - 150))
	for i in 60:
		await physics_frame
		if cat.is_on_floor():
			break
	_check("the cat can stand on a crate", cat.is_on_floor() and absf(cat.global_position.y - (CRATE_BOTTOM - three.SIZE.y)) < 6.0, cat.global_position)

	# Running into a crate's side on the ground gives nothing (a crate standing on the ground)
	var side = _crate(level, Vector2(250, GROUND), 2, false)
	await _frames(2)
	_coins = 0
	await _place(cat, Vector2(80, GROUND - 5))
	Input.action_press("move_right")
	await _frames(60)
	Input.action_release("move_right")
	_check("running into a crate's side gives nothing", _coins == 0 and not side.is_empty(), _coins)
	level.queue_free()

	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _crate(level, at: Vector2, coins: int, milk: bool):
	var c = load("res://scenes/objects/bump_crate.tscn").instantiate()
	c.position = at
	c.coins = coins
	c.milk = milk
	level.get_node("Objects").add_child(c)
	return c

## Stand under the crate at x, jump straight up into it, land again.
func _jump_under(cat, x: float) -> void:
	await _place(cat, Vector2(x, GROUND - 5))
	await _frames(6)
	Input.action_press("jump")
	await _frames(20)
	Input.action_release("jump")
	for i in 90:
		await physics_frame
		if cat.is_on_floor() and cat.global_position.y > GROUND - 10.0:
			break
	await _frames(4)

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
