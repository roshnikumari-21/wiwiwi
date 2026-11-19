extends Node
## Wrapper around the AdMob plugin (addons/AdmobPlugin, godot-admob v7.0, MIT). Safe no-op on PC and
## whenever ads aren't ready: the rest of the game only talks to this script, never to the plugin.
##
## Start-up (Android only): Google's consent check first (the GDPR message "wiwiwi GDPR" made in AdMob
## shows only to players in Europe / UK / Switzerland, once), then the Mobile Ads SDK starts.
## Ad plan (plan.md §13.2): an interstitial every 3 finished levels, rewarded "revive" when out of
## hearts, rewarded "2x coins" on the level-complete card (all done).

signal ready_changed(is_ready: bool)
## A rewarded ad closed: `earned` is true only if it was watched to the end (only then give the reward).
signal rewarded_finished(placement: String, earned: bool)
## The between-levels ad closed (or couldn't show): carry on to wherever the player was going.
signal interstitial_finished

## AdMob ad units (owners, 19 Nov 2026). Release builds only: test (debug) builds always use Google's
## test ad units below, so we never tap our own live ads.
const REAL_UNITS := {
	"interstitial": "ca-app-pub-4636740711495231/9879325523",
	"revive": "ca-app-pub-4636740711495231/7531142592",
	"coins": "ca-app-pub-4636740711495231/5748508825",
}
const TEST_UNITS := {
	"interstitial": "ca-app-pub-3940256099942544/1033173712",   ## Google's sample interstitial
	"revive": "ca-app-pub-3940256099942544/5224354917",         ## Google's sample rewarded
	"coins": "ca-app-pub-3940256099942544/5224354917",
}

## "unavailable" (PC or plugin missing), "consent" (asking), "starting", "ready", or "failed".
var status: String = "unavailable"

## PC test mode (debug builds, started with  -- --fake-ads , or set by tests): every ad is "ready" and
## a rewarded ad "plays" for a moment and is earned, so the buttons can be tried without a phone.
var fake := false

const REWARDED := ["revive", "coins"]   ## rewarded placements, kept loaded one at a time
const RETRY_LOAD := 30.0                 ## s to wait before trying again when an ad didn't load

var _admob: Admob
var _rewarded := {}        ## placement -> loaded ad id
var _loading := ""         ## rewarded placement being loaded right now ("" = none)
var _showing := ""         ## rewarded placement on screen right now
var _earned := false

## Between-levels ad (owners, 19 Nov 2026): after every 3 finished levels, when the player leaves the
## Level complete! card. Never in the first levels of World 1 (they don't count), and not within a couple
## of minutes of a rewarded ad (the player just watched one: it waits for the next finish instead).
const INTERSTITIAL_EVERY := 3
const NO_ADS_LEVELS := ["w1_01", "w1_02", "w1_03"]
const QUIET_AFTER_REWARDED := 120.0   ## s
var _finished_since_ad := 0
var _last_rewarded_ms := -10000000
var _interstitial := ""                ## loaded interstitial ad id ("" = none)
var _interstitial_loading := false
var _interstitial_showing := false

func _ready() -> void:
	if OS.is_debug_build() and "--fake-ads" in OS.get_cmdline_user_args():
		fake = true
	if not OS.has_feature("android") or not Engine.has_singleton("AdmobPlugin"):
		return
	_admob = Admob.new()
	_admob.name = "Admob"
	_admob.is_real = not OS.is_debug_build()
	_admob.max_ad_content_rating = AdmobConfig.ContentRating.G   # family-friendly ads only
	add_child(_admob)
	_admob.consent_info_updated.connect(_on_consent_info_updated)
	_admob.consent_info_update_failed.connect(func(_e): _start())    # no consent info: start anyway
	_admob.consent_form_loaded.connect(func(): _admob.show_consent_form())
	_admob.consent_form_failed_to_load.connect(func(_e): _start())
	_admob.consent_form_dismissed.connect(func(_e): _start())
	_admob.initialization_completed.connect(_on_initialized)
	_admob.interstitial_ad_loaded.connect(_on_interstitial_loaded)
	_admob.interstitial_ad_failed_to_load.connect(_on_interstitial_failed_to_load)
	_admob.interstitial_ad_dismissed_full_screen_content.connect(func(_i): _finish_interstitial())
	_admob.interstitial_ad_failed_to_show_full_screen_content.connect(func(_i, _e): _finish_interstitial())
	_admob.rewarded_ad_loaded.connect(_on_rewarded_loaded)
	_admob.rewarded_ad_failed_to_load.connect(_on_rewarded_failed_to_load)
	_admob.rewarded_ad_user_earned_reward.connect(func(_i, _r): _earned = true)
	_admob.rewarded_ad_dismissed_full_screen_content.connect(func(_i): _finish_rewarded(_earned))
	_admob.rewarded_ad_failed_to_show_full_screen_content.connect(func(_i, _e): _finish_rewarded(false))
	status = "consent"
	_admob.update_consent_info()

## The ad unit for a placement ("interstitial", "revive", "coins"): test units in test builds.
func unit_id(placement: String) -> String:
	return (TEST_UNITS if OS.is_debug_build() else REAL_UNITS)[placement]

func is_ready() -> bool:
	return status == "ready"

## True if a rewarded ad for this placement ("revive", "coins") is loaded and can be shown now.
func has_rewarded(placement: String) -> bool:
	return fake or (status == "ready" and _rewarded.has(placement) and _showing == "")

## Shows the rewarded ad; listen to `rewarded_finished` for the result. Sound is muted while it plays.
func show_rewarded(placement: String) -> void:
	if not has_rewarded(placement):
		rewarded_finished.emit.call_deferred(placement, false)
		return
	_showing = placement
	_earned = false
	AudioServer.set_bus_mute(0, true)
	if fake:
		get_tree().create_timer(0.6, true, false, true).timeout.connect(_finish_rewarded.bind(true))
		return
	_admob.show_rewarded_ad(_rewarded[placement])

## A level was finished (the Level complete! card is up): counts towards the next between-levels ad.
func count_finished_level(level_id: String) -> void:
	if level_id not in NO_ADS_LEVELS:
		_finished_since_ad += 1

## True when the between-levels ad should play as the player leaves the Level complete! card.
func interstitial_due() -> bool:
	if _finished_since_ad < INTERSTITIAL_EVERY or _interstitial_showing or _showing != "":
		return false
	if Time.get_ticks_msec() - _last_rewarded_ms < QUIET_AFTER_REWARDED * 1000.0:
		return false
	return fake or (status == "ready" and _interstitial != "")

## Plays the between-levels ad; await `interstitial_finished`. The count starts again after it.
func show_interstitial() -> void:
	if not interstitial_due():
		interstitial_finished.emit.call_deferred()
		return
	_interstitial_showing = true
	AudioServer.set_bus_mute(0, true)
	if fake:
		get_tree().create_timer(0.4, true, false, true).timeout.connect(_finish_interstitial)
		return
	_admob.show_interstitial_ad(_interstitial)

## True where Google's consent form applies (Europe / UK / Switzerland): Settings then shows a
## "Privacy choices" button. Elsewhere (e.g. India) the consent status is NOT_REQUIRED: no button.
func privacy_choices_needed() -> bool:
	if fake:
		return true
	if _admob == null or status == "unavailable":
		return false
	var consent := _admob.get_consent_status()
	return consent != null and consent.status in [UserConsent.Status.REQUIRED, UserConsent.Status.OBTAINED]

## Settings → "Privacy choices": reopens Google's consent form (players in Europe must be able to
## change their answer). Does nothing where the form isn't needed.
func show_privacy_choices() -> void:
	if _admob and _admob.is_consent_form_available():
		_admob.load_consent_form()

func _on_consent_info_updated() -> void:
	var consent := _admob.get_consent_status()
	if consent and consent.status == UserConsent.Status.REQUIRED and _admob.is_consent_form_available():
		_admob.load_consent_form()   # shown once loaded; the SDK starts after it's closed
	else:
		_start()

func _start() -> void:
	if status == "starting" or status == "ready":
		return
	status = "starting"
	_admob.initialize()

func _on_initialized(_status) -> void:
	status = "ready"
	ready_changed.emit(true)
	_load_next_rewarded()
	_load_interstitial()

func _load_interstitial() -> void:
	if _interstitial != "" or _interstitial_loading or status != "ready":
		return
	_interstitial_loading = true
	_admob.load_interstitial_ad(_admob.create_interstitial_ad_request().set_ad_unit_id(unit_id("interstitial")))

func _on_interstitial_loaded(ad_info: AdInfo, _response) -> void:
	_interstitial = ad_info.get_ad_id()
	_interstitial_loading = false

func _on_interstitial_failed_to_load(_ad_info, _error) -> void:
	_interstitial_loading = false
	get_tree().create_timer(RETRY_LOAD, true, false, true).timeout.connect(_load_interstitial)

func _finish_interstitial() -> void:
	if not _interstitial_showing:
		return
	_interstitial_showing = false
	_interstitial = ""
	_finished_since_ad = 0
	AudioServer.set_bus_mute(0, false)
	interstitial_finished.emit()
	if not fake:
		_load_interstitial()

## Loads the next missing rewarded ad (one at a time: in test builds both placements share one unit id,
## so the plugin's answer can only be matched to the placement we asked for).
func _load_next_rewarded() -> void:
	if _loading != "" or status != "ready":
		return
	for placement in REWARDED:
		if not _rewarded.has(placement) and placement != _showing:
			_loading = placement
			_admob.load_rewarded_ad(_admob.create_rewarded_ad_request().set_ad_unit_id(unit_id(placement)))
			return

func _on_rewarded_loaded(ad_info: AdInfo, _response) -> void:
	if _loading != "":
		_rewarded[_loading] = ad_info.get_ad_id()
	_loading = ""
	_load_next_rewarded()

func _on_rewarded_failed_to_load(_ad_info, _error) -> void:
	_loading = ""
	get_tree().create_timer(RETRY_LOAD, true, false, true).timeout.connect(_load_next_rewarded)

func _finish_rewarded(earned: bool) -> void:
	var placement := _showing
	if placement == "":
		return
	_showing = ""
	_last_rewarded_ms = Time.get_ticks_msec()
	_rewarded.erase(placement)   # a rewarded ad can be shown only once
	AudioServer.set_bus_mute(0, false)
	rewarded_finished.emit(placement, earned)
	if not fake:
		_load_next_rewarded()   # get the next one ready
