extends Node
## Wrapper around the Google Play Games plugin. Safe no-op on PC and when signed out:
## the rest of the game only talks to this script, never to the plugin directly.

signal sign_in_changed(signed_in: bool)
## Leaderboards / achievements couldn't open: "unavailable" (not Android) or "sign_in_failed".
signal open_failed(reason: String)

## "unavailable" (PC or plugin missing), "checking", "signed_in" or "signed_out".
var status: String = "unavailable"

var _sign_in: PlayGamesSignInClient
var _leaderboards: PlayGamesLeaderboardsClient
var _achievements: PlayGamesAchievementsClient
var _waiting := ""          ## "leaderboards" / "achievements" to open once sign-in finishes
var _asked_sign_in := false ## already showed Google's sign-in for this tap

func _ready() -> void:
	if not OS.has_feature("android"):
		return
	if GodotPlayGameServices.initialize() != GodotPlayGameServices.PlayGamesPluginError.OK:
		return
	_sign_in = PlayGamesSignInClient.new()
	add_child(_sign_in)
	_sign_in.user_authenticated.connect(_on_user_authenticated)
	_leaderboards = PlayGamesLeaderboardsClient.new()
	add_child(_leaderboards)
	_achievements = PlayGamesAchievementsClient.new()
	add_child(_achievements)
	status = "checking"
	_sign_in.is_authenticated()  # Play Games signs in automatically at launch; this asks for the result.

func is_signed_in() -> bool:
	return status == "signed_in"

## For a manual "Sign in" button, if automatic sign-in failed or was declined.
func sign_in() -> void:
	if _sign_in:
		status = "checking"
		_sign_in.sign_in()

## Opens Google's leaderboards / achievements screen; signs in first if needed.
func show_leaderboards() -> void:
	_open("leaderboards")

func show_achievements() -> void:
	_open("achievements")

func _open(screen: String) -> void:
	match status:
		"unavailable":
			open_failed.emit("unavailable")
		"signed_in":
			_show(screen)
		"signed_out":
			_waiting = screen
			_asked_sign_in = true
			sign_in()
		"checking":   # the launch check hasn't answered yet: open when it does
			_waiting = screen
			_asked_sign_in = false

func _show(screen: String) -> void:
	if screen == "leaderboards":
		_leaderboards.show_all_leaderboards()
	else:
		_achievements.show_achievements()

func _on_user_authenticated(signed_in: bool) -> void:
	status = "signed_in" if signed_in else "signed_out"
	sign_in_changed.emit(signed_in)
	if _waiting == "":
		return
	if signed_in:
		_show(_waiting)
	elif not _asked_sign_in:   # the silent launch check said no: show Google's sign-in once
		_asked_sign_in = true
		sign_in()
		return
	else:
		open_failed.emit("sign_in_failed")
	_waiting = ""
