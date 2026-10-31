extends SceneTree
## Home page Leaderboards / Achievements buttons: on PC (no Play Games) a friendly note opens and
## Android Back closes it; when sign-in fails a "couldn't sign in" note shows; while the launch
## check is still running the tap waits for it, and a silent "no" asks Google's sign-in once.
## Run: godot --headless --path . --script res://dev/m2_play_games_test.gd

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var ps = root.get_node("PlayServices")
	var home = load("res://ui/screens/main_menu.tscn").instantiate()
	root.add_child(home)
	await process_frame
	var menu = home.menu
	_check("on PC Play Games is unavailable", ps.status == "unavailable", ps.status)
	home.achievements.pressed.emit()
	await process_frame
	_check("Achievements on PC: the note opens", menu.visible and menu.current == "notice" and _has_text(menu, "PLAY_GAMES_UNAVAILABLE"), menu.current)
	home._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check("Android Back closes the note", not menu.visible and menu.current == "", menu.current)
	home.leaderboards.pressed.emit()
	await process_frame
	_check("Leaderboards on PC: the note opens", menu.current == "notice", menu.current)
	menu.close()

	# Pretend to be on a phone whose launch check hasn't answered yet (no real plugin: nothing opens).
	ps.status = "checking"
	var failed := []
	ps.open_failed.connect(func(r): failed.append(r))
	ps.show_leaderboards()
	_check("a tap during the launch check waits for it", ps._waiting == "leaderboards" and failed.is_empty(), ps._waiting)
	ps._on_user_authenticated(false)
	_check("silent check said no: Google's sign-in is asked once", ps._waiting == "leaderboards" and ps._asked_sign_in and failed.is_empty(), [ps._waiting, failed])
	ps._on_user_authenticated(false)
	_check("sign-in declined: 'couldn't sign in' note", failed == ["sign_in_failed"] and ps._waiting == "" and menu.current == "notice" and _has_text(menu, "PLAY_GAMES_SIGN_IN_FAILED"), [failed, menu.current])
	menu.close()
	ps.status = "unavailable"
	home.queue_free()
	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _has_text(node: Node, key: String) -> bool:
	for label in node.find_children("*", "Label", true, false):
		if label.text == key:
			return true
	return false

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", name, str(got) if not ok else ""])
