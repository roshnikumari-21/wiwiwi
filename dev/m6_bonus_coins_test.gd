extends SceneTree
## Headless check of the home page "Watch ad: +25" free coins (pretend ads): 25 coins each, 5 a day,
## a new day resets it, the purse only (not the lifetime count), no button when no ad is loaded.
## Run: godot --headless --path . --script res://dev/m6_bonus_coins_test.gd

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var save = root.get_node("SaveManager")
	save.save_path = "user://test_bonus_save.json"
	save.reset_progress()
	var ads = root.get_node("Ads")

	ads.fake = false
	change_scene_to_file("res://ui/screens/main_menu.tscn")
	await _frames(20)
	var button = current_scene.find_child("BonusButton", true, false)
	_check("no ad loaded: no button", button != null and not button.visible, "")

	ads.fake = true
	await create_timer(1.2).timeout   # the page checks once a second
	_check("ad ready: button shows, 5 left", button.visible and save.bonus_ads_left() == 5, save.bonus_ads_left())
	var ever: int = save.stat("coins_ever")
	button.pressed.emit()
	await create_timer(1.0).timeout
	_check("one ad: +25 coins", save.purse() == 25, save.purse())
	_check("one ad: 4 left", save.bonus_ads_left() == 4, save.bonus_ads_left())
	_check("lifetime count unchanged (leaderboard fair)", save.stat("coins_ever") == ever, save.stat("coins_ever"))
	for i in 4:
		button.pressed.emit()
		await create_timer(1.0).timeout
	_check("five ads: 125 coins, none left", save.purse() == 125 and save.bonus_ads_left() == 0, [save.purse(), save.bonus_ads_left()])
	await _frames(5)
	_check("none left: button hidden", not button.visible, "")
	var note = current_scene.find_child("BonusNote", true, false)
	_check("none left: 'tomorrow' note", note.visible and "tomorrow" in note.text, note.text)
	save.claim_bonus_ad()   # a 6th claim can't go past the limit
	_check("can't go past 5 a day", save.bonus_ads_left() == 0, save.bonus_ads_left())

	save._data["daily"]["date"] = "2000-01-01"   # it's a new day
	_check("new day: 5 again", save.bonus_ads_left() == 5, save.bonus_ads_left())
	save.save_game()
	save.load_game()
	_check("saved and loaded: still counts", save.bonus_ads_left() == 5 and save.purse() >= 125, save.purse())

	for path in ["user://test_bonus_save.json", "user://test_bonus_save.json.bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _check(name: String, ok: bool, detail) -> void:
	if not ok:
		_fails += 1
	print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  (%s)" % str(detail)))
