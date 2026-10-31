extends SceneTree
## Headless check of the audio rules: right music per screen, one track at a time, home <-> map
## keeps the song, jingles stop the music, pause lowers it, sound limits work, settings mute.
## Run: godot --headless --path . --script res://dev/m2_audio_test.gd

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var audio = root.get_node("AudioManager")
	var save = root.get_node("SaveManager")
	save.save_path = "user://test_audio_save.json"
	save.settings_path = "user://test_audio_settings.cfg"
	save.reset_progress()
	save.load_settings()

	change_scene_to_file("res://ui/screens/main_menu.tscn")
	await _frames(60)
	_check("home: mus_home playing", audio.current_music == "mus_home" and _playing_music(audio) == 1, [audio.current_music, _playing_music(audio)])
	var player_before = audio._music[audio._active]
	var pos_before: float = player_before.get_playback_position()
	change_scene_to_file("res://ui/screens/level_map.tscn")
	await _frames(30)
	_check("map: same song carries on (not restarted)", audio._music[audio._active] == player_before and player_before.get_playback_position() > pos_before, [pos_before, player_before.get_playback_position()])

	change_scene_to_file("res://scenes/levels/w1/level_w1_01.tscn")
	await _seconds(1.5)   # scene fade + 0.8 s crossfade
	_check("level: mus_world1, only one track playing after the crossfade", audio.current_music == "mus_world1" and _playing_music(audio) == 1, [audio.current_music, _playing_music(audio)])
	var hud = current_scene.get_node("Hud/SafeArea/Hud")
	hud.pause()
	await _seconds(0.5)
	_check("pause: music lowered, still playing", audio._music[audio._active].playing and audio._music[audio._active].volume_db < -5.0, audio._music[audio._active].volume_db)
	hud.resume()
	await _seconds(0.5)
	_check("resume: music back to full", audio._music[audio._active].volume_db > -1.0, audio._music[audio._active].volume_db)

	# sound limits: 10 coin sounds in one frame -> at most 3 play
	for i in 10:
		audio._last_played.erase("sfx_coin")
		audio.play_coin()
	var coins := 0
	for v in audio._voices:
		if v.playing and v.stream.resource_path.ends_with("sfx_coin.ogg"):
			coins += 1
	_check("10 coins at once -> at most 3 coin sounds", coins <= 3 and coins >= 1, coins)
	audio._last_played.clear()
	audio.play_sfx("sfx_jump")
	audio.play_sfx("sfx_jump")
	var jumps := 0
	for v in audio._voices:
		if v.playing and v.stream.resource_path.ends_with("sfx_jump.ogg"):
			jumps += 1
	_check("jump sound can't double up", jumps == 1, jumps)

	root.get_node("Events").level_completed.emit(3, 16, 16, true)
	await _seconds(0.6)
	_check("level complete: jingle plays, music faded out", audio._jingle.playing and not audio._music[0].playing and not audio._music[1].playing, [audio._jingle.playing, audio._music[0].playing, audio._music[1].playing])

	save.set_setting("music_on", false)
	_check("Music Off mutes the Music bus", AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "")
	save.set_setting("sound_on", false)
	_check("Sounds Off mutes SFX and UI", AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")) and AudioServer.is_bus_mute(AudioServer.get_bus_index("UI")), "")
	save.set_setting("music_on", true)
	save.set_setting("sound_on", true)

	var button := Button.new()
	current_scene.add_child(button)
	audio._last_played.clear()
	button.pressed.emit()
	var ui_click := false
	for v in audio._voices:
		ui_click = ui_click or (v.playing and v.bus == &"UI")
	_check("every button clicks on the UI bus", ui_click, "")

	for path in ["user://test_audio_save.json", "user://test_audio_save.json.bak", "user://test_audio_settings.cfg"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _playing_music(audio) -> int:
	return int(audio._music[0].playing) + int(audio._music[1].playing)

func _seconds(t: float) -> void:
	await create_timer(t, true).timeout

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", name, str(got) if not ok else ""])
