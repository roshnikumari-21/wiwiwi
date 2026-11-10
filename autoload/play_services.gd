extends Node
## Wrapper around the Google Play Games plugin. Safe no-op on PC and when signed out:
## the rest of the game only talks to this script, never to the plugin directly.
## Achievements and leaderboard scores are worked out from the save and synced automatically.

signal sign_in_changed(signed_in: bool)

## IDs from Play Console → Play Games Services (created 10 Nov 2026). A new world adds its own here
## and a rule in achievement_targets(); published achievements can't be deleted, only hidden.
const LEADERBOARDS := {
	"most_stars": "CgkI8qjHoLMHEAIQAg",
	"coin_collector": "CgkI8qjHoLMHEAIQAw",
}
const ACHIEVEMENTS := {
	"first_steps": "CgkI8qjHoLMHEAIQBA",
	"halfway_home": "CgkI8qjHoLMHEAIQBQ",
	"home_again": "CgkI8qjHoLMHEAIQBg",
	"star_gazer": "CgkI8qjHoLMHEAIQBw",
	"perfect_meadow": "CgkI8qjHoLMHEAIQCA",
	"shiny_find": "CgkI8qjHoLMHEAIQCQ",
	"yarn_master": "CgkI8qjHoLMHEAIQCg",
	"slime_squisher": "CgkI8qjHoLMHEAIQCw",   ## incremental, 25 steps
	"not_a_scratch": "CgkI8qjHoLMHEAIQDA",
	"piggy_bank": "CgkI8qjHoLMHEAIQDQ",       ## incremental, 500 steps
	"new_look": "CgkI8qjHoLMHEAIQDg",
	"cat_collector": "CgkI8qjHoLMHEAIQDw",
}
const STEPS := {"slime_squisher": 25, "piggy_bank": 500}   ## the incremental ones
## Leaderboards / achievements couldn't open: "unavailable" (not Android) or "sign_in_failed".
signal open_failed(reason: String)

## "unavailable" (PC or plugin missing), "checking", "signed_in" or "signed_out".
var status: String = "unavailable"

var _sign_in: PlayGamesSignInClient
var _leaderboards: PlayGamesLeaderboardsClient
var _achievements: PlayGamesAchievementsClient
var _waiting := ""          ## "leaderboards" / "achievements" to open once sign-in finishes
var _asked_sign_in := false ## already showed Google's sign-in for this tap
var _sent := {}             ## what Play Games was last told this session, so only changes are sent

func _ready() -> void:
	SaveManager.progress_changed.connect(sync)
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

## What the save says right now: each achievement → true / false, or its step count for the
## incremental ones. Everything is worked out from the save, so progress made while signed out
## or offline is sent the next time the player is signed in.
func achievement_targets() -> Dictionary:
	var stars := SaveManager.total_stars()
	var yarns := SaveManager.total_yarns()
	var any_done := false
	for level in GameState.catalog.levels:
		any_done = any_done or SaveManager.is_done(level.id)
	var cats := 0
	for skin in CatSkins.ALL:
		cats += int(SaveManager.owns_cat(skin.id))
	return {
		"first_steps": any_done,
		"halfway_home": SaveManager.is_done("w1_05"),
		"home_again": SaveManager.is_done("w1_10"),
		"star_gazer": stars.x >= 15,
		"perfect_meadow": stars.x >= stars.y,
		"shiny_find": yarns.x >= 1,
		"yarn_master": yarns.x >= yarns.y,
		"slime_squisher": mini(SaveManager.stat("slimes"), STEPS.slime_squisher),
		"not_a_scratch": SaveManager.stat("flawless") > 0,
		"piggy_bank": mini(SaveManager.stat("coins_ever"), STEPS.piggy_bank),
		"new_look": cats > 1,
		"cat_collector": cats == CatSkins.ALL.size(),
	}

func leaderboard_scores() -> Dictionary:
	return {"most_stars": SaveManager.total_stars().x, "coin_collector": SaveManager.stat("coins_ever")}

## Sends what changed since last time (only when signed in; Play Games ignores repeats anyway).
func sync() -> void:
	if status != "signed_in":
		return
	var targets := achievement_targets()
	for key in targets:
		var value = targets[key]
		if _sent.get(key) == value or (value is bool and not value) or (value is int and value == 0):
			continue
		if key in STEPS:
			_achievements.set_achievement_steps(ACHIEVEMENTS[key], value)
		else:
			_achievements.unlock_achievement(ACHIEVEMENTS[key])
		_sent[key] = value
	var scores := leaderboard_scores()
	for key in scores:
		if scores[key] > 0 and _sent.get(key) != scores[key]:
			_leaderboards.submit_score(LEADERBOARDS[key], scores[key])
			_sent[key] = scores[key]

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
	sync()   # catch up on anything earned while signed out
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
