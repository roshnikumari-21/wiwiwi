extends Node
## Wrapper around the AdMob plugin (addons/AdmobPlugin, godot-admob v7.0, MIT). Safe no-op on PC and
## whenever ads aren't ready: the rest of the game only talks to this script, never to the plugin.
##
## Start-up (Android only): Google's consent check first (the GDPR message "wiwiwi GDPR" made in AdMob
## shows only to players in Europe / UK / Switzerland, once), then the Mobile Ads SDK starts.
## Ad plan (plan.md §13.2): an interstitial every 3 finished levels, rewarded "revive" when out of
## hearts, rewarded "2x coins" on the level-complete card. Those come in the next steps.

signal ready_changed(is_ready: bool)

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

var _admob: Admob

func _ready() -> void:
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
	status = "consent"
	_admob.update_consent_info()

## The ad unit for a placement ("interstitial", "revive", "coins"): test units in test builds.
func unit_id(placement: String) -> String:
	return (TEST_UNITS if OS.is_debug_build() else REAL_UNITS)[placement]

func is_ready() -> bool:
	return status == "ready"

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
