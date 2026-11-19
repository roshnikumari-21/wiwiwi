extends SceneTree
## Headless check of "Watch an ad: 2x coins" on the Level complete! card, with pretend ads (Ads.fake).
## The bonus goes into the purse only; the lifetime count (leaderboard, Piggy Bank) stays what she picked up.
## Run: godot --headless --path . --script res://dev/m6_double_coins_test.gd

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var save = root.get_node("SaveManager")
	save.save_path = "user://test_double_save.json"
	save.reset_progress()
	var ads = root.get_node("Ads")
	var events = root.get_node("Events")

	# No ad ready: no button.
	ads.fake = false
	var hud = await _open_level()
	events.level_completed.emit(2, 13, 16, false)
	await _frames(5)
	_check("no ad ready: no 2x button", hud.menu.find_child("Double", true, false) == null, "")
	_check("no ad ready: Map / Replay / Next", ["RESULT_MAP", "RESULT_REPLAY", "RESULT_NEXT"].all(func(n): return hud.menu.find_child(n, true, false) != null), "")

	# No coins picked up: nothing to double, no button.
	ads.fake = true
	hud = await _open_level()
	events.level_completed.emit(1, 0, 16, false)
	await _frames(5)
	_check("0 coins: no 2x button", hud.menu.find_child("Double", true, false) == null, "")

	# Ad ready and 13 coins: watched to the end -> purse +13 more, lifetime count unchanged.
	hud = await _open_level()
	var purse_before: int = save.purse()
	var ever_before: int = save.stat("coins_ever")
	events.level_completed.emit(2, 13, 16, false)
	await _frames(5)
	_check("finish: purse +13", save.purse() == purse_before + 13, save.purse() - purse_before)
	_check("finish: lifetime +13", save.stat("coins_ever") == ever_before + 13, save.stat("coins_ever") - ever_before)
	var double = hud.menu.find_child("Double", true, false)
	_check("ad ready: 2x button shows", double != null, "")
	_check("ad ready: Map / Replay / Next still there", ["RESULT_MAP", "RESULT_REPLAY", "RESULT_NEXT"].all(func(n): return hud.menu.find_child(n, true, false) != null), "")
	double.pressed.emit()
	await create_timer(1.0).timeout
	await _frames(5)
	_check("after the ad: purse doubled (+26 in all)", save.purse() == purse_before + 26, save.purse() - purse_before)
	_check("after the ad: lifetime count still +13 (leaderboard fair)", save.stat("coins_ever") == ever_before + 13, save.stat("coins_ever") - ever_before)
	_check("after the ad: button gone", hud.menu.find_child("Double", true, false) == null, "")
	var bonus = hud.menu.find_child("Bonus", true, false)
	_check("after the ad: '+13 bonus coins!'", bonus != null and "13" in bonus.text, bonus.text if bonus else "none")
	_check("after the ad: card still open", hud.menu.visible and hud.menu.current == "complete", hud.menu.current)

	# The ad didn't play to the end: no bonus, the button just goes.
	hud = await _open_level()
	purse_before = save.purse()
	events.level_completed.emit(3, 10, 16, false)
	await _frames(5)
	ads.fake = false   # has_rewarded() is now false: show_rewarded answers "not earned"
	hud.menu.find_child("Double", true, false).pressed.emit()
	await _frames(10)
	_check("ad not watched: only the normal +10", save.purse() == purse_before + 10, save.purse() - purse_before)
	_check("ad not watched: button gone, no bonus text", hud.menu.find_child("Double", true, false) == null and hud.menu.find_child("Bonus", true, false) == null, "")
	_check("ad not watched: Next still there", hud.menu.find_child("RESULT_NEXT", true, false) != null, "")

	for path in ["user://test_double_save.json", "user://test_double_save.json.bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _open_level() -> Node:
	change_scene_to_file("res://scenes/levels/w1/level_w1_01.tscn")
	await _frames(10)
	return current_scene.get_node("Hud/SafeArea/Hud")

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _check(name: String, ok: bool, detail) -> void:
	if not ok:
		_fails += 1
	print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  (%s)" % str(detail)))
