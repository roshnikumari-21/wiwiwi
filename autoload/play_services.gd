extends Node
## Wrapper around the Google Play Games plugin. Safe no-op on PC and when signed out:
## the rest of the game only talks to this script, never to the plugin directly.

signal sign_in_changed(signed_in: bool)

## "unavailable" (PC or plugin missing), "checking", "signed_in" or "signed_out".
var status: String = "unavailable"

var _sign_in: PlayGamesSignInClient

func _ready() -> void:
	if not OS.has_feature("android"):
		return
	if GodotPlayGameServices.initialize() != GodotPlayGameServices.PlayGamesPluginError.OK:
		return
	_sign_in = PlayGamesSignInClient.new()
	add_child(_sign_in)
	_sign_in.user_authenticated.connect(_on_user_authenticated)
	status = "checking"
	_sign_in.is_authenticated()  # Play Games signs in automatically at launch; this asks for the result.

func is_signed_in() -> bool:
	return status == "signed_in"

## For a manual "Sign in" button, if automatic sign-in failed or was declined.
func sign_in() -> void:
	if _sign_in:
		status = "checking"
		_sign_in.sign_in()

func _on_user_authenticated(signed_in: bool) -> void:
	status = "signed_in" if signed_in else "signed_out"
	sign_in_changed.emit(signed_in)
