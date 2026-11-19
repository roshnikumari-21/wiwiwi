extends SceneTree
## Headless check of "Watch an ad to continue" (rewarded revive) with the PC's pretend ads (Ads.fake).
## Run: godot --headless --path . --script res://dev/m6_revive_test.gd

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var save = root.get_node("SaveManager")
	save.save_path = "user://test_revive_save.json"
	save.reset_progress()
	var ads = root.get_node("Ads")
	var state = root.get_node("GameState")

	# No ad ready (the PC without pretend ads): the card has no revive button, Retry and Map stay.
	ads.fake = false
	var level = await _open_level()
	var hud = level.get_node("Hud/SafeArea/Hud")
	await _lose_all_hearts(level)
	_check("no ad ready: no revive button", hud.menu.find_child("Revive", true, false) == null, "")
	_check("no ad ready: Retry and Map", ["RESULT_RETRY", "RESULT_MAP"].all(func(n): return hud.menu.find_child(n, true, false) != null), "")

	# Ad ready: the button comes first; watching it brings her back with one heart at the flag.
	ads.fake = true
	level = await _open_level()
	hud = level.get_node("Hud/SafeArea/Hud")
	var player = level.get_node("Player")
	await _lose_all_hearts(level)
	var revive = hud.menu.find_child("Revive", true, false)
	_check("ad ready: revive button shows", revive != null, "")
	_check("ad ready: Retry and Map still there", ["RESULT_RETRY", "RESULT_MAP"].all(func(n): return hud.menu.find_child(n, true, false) != null), "")
	_check("before: level over, 0 hearts", level._over and state.hearts == 0, state.hearts)
	revive.pressed.emit()
	await _frames(5)
	_check("while the ad plays: sound muted", AudioServer.is_bus_mute(0), "")
	await create_timer(1.0).timeout
	await _frames(5)
	_check("after the ad: sound back", not AudioServer.is_bus_mute(0), "")
	_check("after the ad: card closed", not hud.menu.visible, "")
	_check("after the ad: one heart back", state.hearts == 1, state.hearts)
	_check("after the ad: playing again", not level._over and not player.frozen, "")
	_check("after the ad: pause button back", hud.get_node("Pause").visible, "")
	_check("after the ad: touch controls back", level.get_node("Hud/SafeArea/TouchControls").visible, "")
	var x: float = player.global_position.x
	Input.action_press("move_right")
	await _frames(30)
	Input.action_release("move_right")
	_check("after the ad: she can run", player.global_position.x > x + 50, player.global_position.x - x)

	# Once per attempt: losing the last heart again shows no revive button.
	await _lose_all_hearts(level)
	_check("second time in the same attempt: no revive button", hud.menu.find_child("Revive", true, false) == null, "")

	# A restart is a fresh attempt: the revive is offered again.
	level = await _open_level()
	hud = level.get_node("Hud/SafeArea/Hud")
	await _lose_all_hearts(level)
	_check("after a restart: revive offered again", hud.menu.find_child("Revive", true, false) != null, "")

	# The ad didn't play to the end: no reward, the button goes, Retry / Map stay.
	ads.fake = false   # has_rewarded() is now false: show_rewarded answers "not earned"
	hud.menu.find_child("Revive", true, false).pressed.emit()
	await _frames(5)
	await _frames(5)
	_check("ad not watched: still out of hearts", level._over and state.hearts == 0, state.hearts)
	_check("ad not watched: revive button gone", hud.menu.find_child("Revive", true, false) == null, "")
	_check("ad not watched: Retry still there", hud.menu.find_child("RESULT_RETRY", true, false) != null, "")

	for path in ["user://test_revive_save.json", "user://test_revive_save.json.bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _open_level() -> Node:
	change_scene_to_file("res://scenes/levels/w1/level_w1_01.tscn")
	await _frames(10)
	return current_scene

## Spikes three times (no waiting for her to reappear in between: hurt() is what the level listens to).
func _lose_all_hearts(level: Node) -> void:
	var state = root.get_node("GameState")
	var events = root.get_node("Events")
	var player = level.get_node("Player")
	while state.hearts > 0:
		player.set("_safe_left", 0.0)
		events.player_hurt.emit()
		await create_timer(0.9).timeout
	await create_timer(1.2).timeout   # the card opens after a short delay
	await _frames(5)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _check(name: String, ok: bool, detail) -> void:
	if not ok:
		_fails += 1
	print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  (%s)" % str(detail)))
