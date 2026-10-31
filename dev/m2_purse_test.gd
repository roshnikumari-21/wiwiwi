extends SceneTree
## Coin purse + home top bar: coins from finished levels add up (replays too), spending can't go
## below zero, the purse survives a reload, and the home page shows stars / yarns / coins.
## Run: godot --headless --path . --script res://dev/m2_purse_test.gd

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var save = root.get_node("SaveManager")
	var gs = root.get_node("GameState")
	var events = root.get_node("Events")
	save.save_path = "user://purse_test.json"
	save.reset_progress()
	_check("a new game starts with an empty purse", save.purse() == 0, save.purse())
	gs.current_level_id = "w1_01"
	events.level_completed.emit(2, 18, 20, false)
	_check("finishing a level puts its coins in the purse", save.purse() == 18, save.purse())
	events.level_completed.emit(3, 20, 20, true)
	_check("a replay earns its coins again", save.purse() == 38, save.purse())
	_check("best result kept: 3 stars, yarn found", save.stars("w1_01") == 3 and save.has_yarn("w1_01"), "")
	_check("can't spend more than the purse holds", not save.spend_coins(50) and save.purse() == 38, save.purse())
	_check("spending takes the coins", save.spend_coins(30) and save.purse() == 8, save.purse())
	save.load_game()
	_check("the purse is still there after a reload", save.purse() == 8, save.purse())
	_check("totals: 3 / 30 stars, 1 / 10 yarns", save.total_stars() == Vector2i(3, 30) and save.total_yarns() == Vector2i(1, 10), [save.total_stars(), save.total_yarns()])

	var home = load("res://ui/screens/main_menu.tscn").instantiate()
	root.add_child(home)
	await process_frame
	var texts := []
	for label in home.find_child("TopBar", true, false).find_children("*", "Label", true, false):
		texts.append(label.text)
	_check("home top bar shows stars, yarns, coins", texts == ["3 / 30", "1 / 10", "8"], texts)
	save.add_coins(100)
	await process_frame
	_check("the coin pill updates when the purse changes", home.find_child("TopBar", true, false).find_children("*", "Label", true, false)[2].text == "108", "")
	home.queue_free()

	for f in ["", ".bak"]:
		DirAccess.remove_absolute(save.save_path + f)
	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", name, str(got) if not ok else ""])
