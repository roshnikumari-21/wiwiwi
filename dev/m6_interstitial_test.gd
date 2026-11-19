extends SceneTree
## Headless check of the between-levels ad (interstitial) with pretend ads (Ads.fake): every 3 finished
## levels, as the player leaves the Level complete! card; not for the first levels of World 1; not right
## after a rewarded ad. Run: godot --headless --path . --script res://dev/m6_interstitial_test.gd

var _fails := 0
var _ads_shown := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var save = root.get_node("SaveManager")
	save.save_path = "user://test_interstitial_save.json"
	save.reset_progress()
	var ads = root.get_node("Ads")
	ads.fake = true
	ads.interstitial_finished.connect(func(): _ads_shown += 1)

	# The first levels of World 1 never count.
	for id in ["w1_01", "w1_02", "w1_03"]:
		await _finish_and_leave(id)
	_check("w1_01..w1_03: no ad", _ads_shown == 0, _ads_shown)
	_check("w1_01..w1_03: not counted", ads._finished_since_ad == 0, ads._finished_since_ad)

	# After that: the 1st and 2nd finish no ad, the 3rd plays one, then the count starts again.
	await _finish_and_leave("w1_04")
	await _finish_and_leave("w1_05")
	_check("2 finishes: no ad yet", _ads_shown == 0, _ads_shown)
	var went_on := await _finish_and_leave("w1_06")
	_check("3rd finish: the ad plays", _ads_shown == 1, _ads_shown)
	_check("3rd finish: then on to the next level", went_on, "")
	_check("after the ad: count back to 0", ads._finished_since_ad == 0, ads._finished_since_ad)
	_check("after the ad: sound back", not AudioServer.is_bus_mute(0), "")
	await _finish_and_leave("w1_07")
	await _finish_and_leave("w1_08")
	await _finish_and_leave("w1_09")
	_check("next 3 finishes: one more ad", _ads_shown == 2, _ads_shown)

	# A rewarded ad just watched (2x coins): the 3rd finish skips the ad, the next finish plays it.
	await _finish_and_leave("w2_01")
	await _finish_and_leave("w2_02")
	var hud = await _finish("w2_03")
	hud.menu.find_child("Double", true, false).pressed.emit()
	await create_timer(1.0).timeout
	await _leave(hud)
	_check("right after a rewarded ad: no between-levels ad", _ads_shown == 2, _ads_shown)
	await _finish_and_leave("w2_04")
	_check("...but it isn't lost: QUIET_AFTER_REWARDED still holds it", _ads_shown == 2, _ads_shown)
	ads._last_rewarded_ms = -10000000   # a couple of minutes later
	await _finish_and_leave("w2_05")
	_check("a while later: the ad plays at the next finish", _ads_shown == 3, _ads_shown)

	# Leaving from the Try again? card (lost) never plays it.
	ads._finished_since_ad = 5
	change_scene_to_file("res://scenes/levels/w2/level_w2_06.tscn")
	await _frames(10)
	hud = current_scene.get_node("Hud/SafeArea/Hud")
	root.get_node("Events").level_failed.emit()
	await _frames(5)
	hud.menu.find_child("RESULT_RETRY", true, false).pressed.emit()
	await _frames(10)
	_check("from Try again?: no ad", _ads_shown == 3, _ads_shown)

	# No ad loaded (phone offline): she goes on straight away.
	ads.fake = false
	ads._finished_since_ad = 5
	went_on = await _finish_and_leave("w2_07")
	_check("no ad loaded: goes on, no ad", went_on and _ads_shown == 3, _ads_shown)

	for path in ["user://test_interstitial_save.json", "user://test_interstitial_save.json.bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

## Opens the level and shows its Level complete! card (13 coins).
func _finish(id: String) -> Node:
	var world := id.substr(1, 1)
	change_scene_to_file("res://scenes/levels/w%s/level_%s.tscn" % [world, id])
	await _frames(10)
	var hud = current_scene.get_node("Hud/SafeArea/Hud")
	root.get_node("Events").level_completed.emit(2, 13, 16, false)
	await _frames(5)
	return hud

## Taps Replay on the card and waits; true once the level was reloaded (she went on).
func _leave(hud: Node) -> bool:
	var before := current_scene
	hud.menu.find_child("RESULT_REPLAY", true, false).pressed.emit()
	await create_timer(1.5).timeout
	await _frames(10)
	return current_scene != before

func _finish_and_leave(id: String) -> bool:
	var hud = await _finish(id)
	return await _leave(hud)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _check(name: String, ok: bool, detail) -> void:
	if not ok:
		_fails += 1
	print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  (%s)" % str(detail)))
