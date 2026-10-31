extends SceneTree
## Pet the kitten on the home page: a tap closes her eyes, starts the purr and sends hearts up;
## more pats keep her happy; she opens her eyes and the purr fades a moment after the last pat.
## Run: godot --headless --path . --script res://dev/m2_pet_test.gd

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var audio = root.get_node("AudioManager")
	var home = load("res://ui/screens/main_menu.tscn").instantiate()
	root.add_child(home)
	await process_frame
	var area: Control = home.find_child("PetArea", true, false)
	var open: Texture2D = home.KITTEN_OPEN
	_check("there is a touch area over the kitten", area != null and Rect2(area.position, area.size).has_point(home.kitten.position + home.kitten.offset * home.kitten.scale), "")
	var hearts_before := _hearts(home)
	area.gui_input.emit(_tap())
	await process_frame
	_check("a pat: eyes closed, purring, hearts", home.kitten.texture == home.KITTEN_BLINK and audio._purr.playing and _hearts(home) > hearts_before, [audio._purr.playing, _hearts(home)])
	await create_timer(1.0).timeout
	area.gui_input.emit(_tap())
	await create_timer(1.0).timeout   # 2.0 s after the first pat, 1.0 s after the second
	_check("another pat keeps her happy", home.kitten.texture == home.KITTEN_BLINK and home._petting, "")
	await create_timer(1.0).timeout
	_check("after the last pat she opens her eyes", home.kitten.texture == open and not home._petting, "")
	await create_timer(1.0).timeout
	_check("the purr faded out", not audio._purr.playing, "")
	area.gui_input.emit(_tap())
	await process_frame
	home.queue_free()
	await create_timer(1.0).timeout
	_check("leaving the home page mid-pat stops the purr", not audio._purr.playing, "")
	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _tap() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev

func _hearts(home) -> int:
	return home.stage.get_children().filter(func(n): return n is Sprite2D and n.texture == home.HEART).size()

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", name, str(got) if not ok else ""])
