extends SceneTree
## Headless check of Settings: toggles save and mute the audio buses; button size changes the touch
## buttons live; reachable from the home page and from the pause menu (and Back returns to pause).
## Run: godot --headless --path . --script res://dev/m2_settings_test.gd

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var save = root.get_node("SaveManager")
	save.settings_path = "user://test_settings_ui.cfg"
	save.load_settings()

	change_scene_to_file("res://ui/screens/main_menu.tscn")
	await _frames(10)
	var home = current_scene
	home.get_node("Stage/Settings").pressed.emit()
	await _frames(5)
	var menu = home.menu
	_check("home: Settings opens", menu.visible and menu.find_child("SET_MUSIC", true, false) != null, "")
	menu.find_child("SET_MUSIC", true, false).pressed.emit()
	await _frames(2)
	_check("music off: saved", save.get_setting("music_on") == false, save.get_setting("music_on"))
	_check("music off: Music bus muted", AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "")
	_check("button now says Off", menu.find_child("SET_MUSIC", true, false).text == "OFF", menu.find_child("SET_MUSIC", true, false).text)
	menu.find_child("SET_SOUND", true, false).pressed.emit()
	await _frames(2)
	_check("sound off: SFX and UI buses muted", AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")) and AudioServer.is_bus_mute(AudioServer.get_bus_index("UI")), "")
	menu.find_child("L", true, false).pressed.emit()
	await _frames(2)
	_check("size L saved", is_equal_approx(save.get_setting("controls_size"), 1.2), save.get_setting("controls_size"))
	menu.find_child("CREDITS_TITLE", true, false).pressed.emit()
	await _frames(3)
	var credits_text := ""
	for l in menu.find_children("*", "Label", true, false):
		credits_text += l.text
	_check("Credits: DigiCraft, Godot licence, Fredoka OFL, Play Games plugin licence",
		menu.current == "credits" and "CREDITS_MADE_BY" in credits_text and "Godot Engine contributors" in credits_text
		and "SIL Open Font License" in credits_text and "Jacob Ib" in credits_text, menu.current)
	menu.go_back()
	await _frames(3)
	_check("Back from Credits returns to Settings", menu.current == "settings", menu.current)
	menu.find_child("BTN_DONE", true, false).pressed.emit()
	await _frames(2)
	_check("Done closes Settings", not menu.visible, "")

	change_scene_to_file("res://scenes/levels/w1/level_w1_01.tscn")
	await _frames(10)
	var level = current_scene
	var jump = level.get_node("Hud/SafeArea/TouchControls").find_child("Jump", true, false)
	_check("touch buttons use size L", is_equal_approx(jump.scale.x, 0.55 * 1.2), jump.scale.x)
	var hud = level.get_node("Hud/SafeArea/Hud")
	hud.pause()
	await _frames(3)
	hud.menu.find_child("SETTINGS_TITLE", true, false).pressed.emit()
	await _frames(3)
	_check("pause: Settings opens, still paused", paused and hud.menu.find_child("BTN_BACK", true, false) != null, "")
	hud.menu.find_child("S", true, false).pressed.emit()
	await _frames(2)
	_check("size S applies to touch buttons at once", is_equal_approx(jump.scale.x, 0.55 * 0.8), jump.scale.x)
	hud.menu.find_child("BTN_BACK", true, false).pressed.emit()
	await _frames(3)
	_check("Back returns to the pause menu", hud.menu.find_child("BTN_RESUME", true, false) != null and paused, "")
	hud.resume()

	save.set_setting("music_on", true)
	save.set_setting("sound_on", true)
	_check("music back on: unmuted", not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "")
	if FileAccess.file_exists("user://test_settings_ui.cfg"):
		DirAccess.remove_absolute("user://test_settings_ui.cfg")
	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", name, str(got) if not ok else ""])
