extends SceneTree
## Play Games achievements + leaderboards: worked out from the save, sent only when signed in,
## only what changed, and progress made while signed out is sent at the next sign-in.
## (Fake Play Games clients from fake_play_games.gd record the calls instead of talking to Google.)
## Run: godot --headless --path . --script res://dev/m2_achievements_test.gd

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var save = root.get_node("SaveManager")
	var gs = root.get_node("GameState")
	var events = root.get_node("Events")
	var ps = root.get_node("PlayServices")
	var fakes = load("res://dev/fake_play_games.gd")
	var ach = fakes.FakeAchievements.new()
	var lb = fakes.FakeLeaderboards.new()
	ps._achievements = ach
	ps._leaderboards = lb
	save.save_path = "user://achievements_test.json"
	save.reset_progress()
	var ID: Dictionary = ps.ACHIEVEMENTS

	_check("a fresh save earns nothing", ps.achievement_targets().values().all(func(v): return not v), ps.achievement_targets())
	# Signed out: play level 1-1 perfectly (3 stars, yarn, 20 coins, no heart lost) and squish 3 slimes
	ps.status = "signed_out"
	for i in 3:
		events.enemy_stomped.emit()
	gs.current_level_id = "w1_01"
	gs.hearts = gs.MAX_HEARTS
	events.level_completed.emit(3, 20, 20, true)
	_check("signed out: nothing is sent", ach.calls.is_empty() and lb.calls.is_empty(), ach.calls)
	_check("stats saved: 3 slimes, 20 coins ever, flawless", save.stat("slimes") == 3 and save.stat("coins_ever") == 20 and save.stat("flawless") == 1, [save.stat("slimes"), save.stat("coins_ever")])

	ps._on_user_authenticated(true)   # signs in: catch up
	var unlocked: Array = ach.calls.filter(func(c): return c[0] == "unlock").map(func(c): return c[1])
	_check("at sign-in: First Steps, Shiny Find, Not a Scratch unlocked", unlocked.size() == 3 and ID.first_steps in unlocked and ID.shiny_find in unlocked and ID.not_a_scratch in unlocked, unlocked)
	_check("at sign-in: slime 3/25 and coin 20/500 steps sent", ["steps", ID.slime_squisher, 3] in ach.calls and ["steps", ID.piggy_bank, 20] in ach.calls, ach.calls)
	_check("at sign-in: scores 3 stars, 20 coins", ["score", ps.LEADERBOARDS.most_stars, 3] in lb.calls and ["score", ps.LEADERBOARDS.coin_collector, 20] in lb.calls, lb.calls)

	ach.calls.clear(); lb.calls.clear()
	events.enemy_stomped.emit()
	_check("one more slime: only its steps are sent (4)", ach.calls == [["steps", ID.slime_squisher, 4]] and lb.calls.is_empty(), [ach.calls, lb.calls])

	# Finish levels 2-5 (losing a heart in each), reaching 15 stars and level 1-5
	ach.calls.clear()
	for i in range(2, 6):
		gs.current_level_id = "w1_%02d" % i
		gs.hearts = 2
		events.level_completed.emit(3, 20, 20, false)
	unlocked = ach.calls.filter(func(c): return c[0] == "unlock").map(func(c): return c[1])
	_check("15 stars + level 1-5: Star Gazer and Halfway Home (each once)", unlocked == [ID.star_gazer, ID.halfway_home] or unlocked == [ID.halfway_home, ID.star_gazer], unlocked)

	ach.calls.clear()
	save.add_coins(500)   # purse only, not lifetime coins: no new Piggy Bank steps
	_check("adding to the purse doesn't count as collected coins", not ach.calls.any(func(c): return c[1] == ID.piggy_bank), ach.calls)
	save.buy_cat("snowy")
	_check("buying a cat: New Look", ["unlock", ID.new_look] in ach.calls, ach.calls)
	for skin in ["cocoa", "misty", "tuxedo", "bubblegum"]:
		save.add_coins(800)
		save.buy_cat(skin)
	_check("all 6 cats: Cat Collector", ["unlock", ID.cat_collector] in ach.calls, ach.calls)

	# Old save (before stats existed): the purse counts as coins collected
	var old: Dictionary = save._migrate({"version": 1, "levels": {}, "wallet": {"coins": 120}})
	_check("old save: lifetime coins start from the purse (120)", old.stats.coins_ever == 120 and old.stats.slimes == 0, old.stats)

	ps.status = "unavailable"
	for f in ["", ".bak"]:
		DirAccess.remove_absolute(save.save_path + f)
	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", name, str(got) if not ok else ""])
