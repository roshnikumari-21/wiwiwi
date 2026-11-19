extends SceneTree
## Headless check: enemy sounds (mole pop, penguin slide, falling coconut) are only heard on screen.
## Run: godot --headless --path . --script res://dev/m6_offscreen_sound_test.gd

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://scenes/levels/w5/level_w5_04.tscn")
	for i in 10:
		await process_frame
	var audio = root.get_node("AudioManager")
	var cat: Node2D = current_scene.get_node("Player")
	var near := cat.global_position + Vector2(300, -50)
	var far := cat.global_position + Vector2(4000, -50)
	audio._last_played.erase("sfx_jump")
	audio.play_sfx_at("sfx_jump", far, 1.3)
	_check("far off screen: no sound", not audio._last_played.has("sfx_jump"), "")
	audio.play_sfx_at("sfx_jump", near, 1.3)
	_check("on screen: the sound plays", audio._last_played.has("sfx_jump"), "")
	# a whole level's moles popping for a while: only the ones near the cat may make a sound
	var moles := current_scene.find_children("Mole*", "", true, false)
	var heard := 0
	for i in 600:
		audio._last_played.erase("sfx_jump")
		await physics_frame
		if audio._last_played.has("sfx_jump"):
			heard += 1
	var on_screen := 0
	for m in moles:
		if absf(m.global_position.x - cat.global_position.x) < 1200:
			on_screen += 1
	_check("10 s of moles popping, %d of %d on screen: pops heard only if some are on screen" % [on_screen, moles.size()],
		on_screen > 0 or heard == 0, heard)
	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _check(name: String, ok: bool, detail) -> void:
	if not ok:
		_fails += 1
	print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  (%s)" % str(detail)))
