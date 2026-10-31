extends Node
## All game audio. Buses: Music (tracks + jingles), SFX (gameplay), UI (button taps); the player's
## Music / Sounds settings mute them. Built so sounds never pile up:
##  - one music track at a time; changing track crossfades, the same track keeps playing across
##    scenes (home <-> map doesn't restart the song)
##  - jingles fade the music out first; pausing lowers the music
##  - each sound has a cooldown and a limit on copies playing at once; quick coin pickups climb in
##    pitch instead of stacking into noise
## Files come from tools/audio_pipeline/make_audio.py (already loudness-matched).

const MUSIC_DIR := "res://assets/audio/music/%s.ogg"
const SFX_DIR := "res://assets/audio/sfx/%s.ogg"
const CROSSFADE := 0.8
const PAUSED_MUSIC_DB := -10.0
const SILENT_DB := -60.0
const SFX_VOICES := 10

## sound: [cooldown seconds, max copies at once, random pitch +/-]
const SFX_RULES := {
	"sfx_coin": [0.04, 3, 0.0],
	"sfx_jump": [0.08, 1, 0.06],
	"sfx_land": [0.15, 1, 0.08],
	"sfx_stomp": [0.08, 2, 0.05],
	"sfx_boing": [0.1, 1, 0.04],
	"sfx_hurt": [0.4, 1, 0.0],
	"sfx_splash": [0.3, 1, 0.05],
	"sfx_checkpoint": [0.3, 1, 0.0],
	"sfx_yarn": [0.3, 1, 0.0],
	"sfx_star": [0.05, 3, 0.0],
	"sfx_meow_happy": [0.5, 1, 0.03],
	"sfx_confetti": [0.1, 2, 0.06],
	"sfx_button": [0.05, 2, 0.0],
}
const COIN_STREAK_TIME := 0.7   ## coins picked this close together climb in pitch
const COIN_STREAK_STEP := 0.04
const COIN_STREAK_MAX := 6

var current_music := ""
var _music: Array[AudioStreamPlayer] = []   # two players, for crossfades
var _active := 0
var _music_tween: Tween
var _jingle: AudioStreamPlayer
var _purr: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _last_played := {}          # sound -> time
var _coin_streak := 0
var _last_coin := -10.0
var _cache := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # music keeps playing (softly) while the game is paused
	for i in 2:
		_music.append(_player("Music"))
	_jingle = _player("Music")
	_purr = _player("SFX")
	for i in SFX_VOICES:
		_voices.append(_player("SFX"))
	SaveManager.settings_changed.connect(func(_key, _value): apply_settings())
	apply_settings()
	get_tree().node_added.connect(_on_node_added)

func apply_settings() -> void:
	_mute("Music", not SaveManager.get_setting("music_on"))
	var sound_off: bool = not SaveManager.get_setting("sound_on")
	_mute("SFX", sound_off)
	_mute("UI", sound_off)

# --- Music --------------------------------------------------------------------------------------

## Play a looping track. The same track carries on (and comes back to full volume if it was lowered).
func play_music(track: String) -> void:
	var now := _music[_active]
	if track == current_music and now.playing:
		_fade(now, 0.0, CROSSFADE)
		return
	current_music = track
	var old := now
	_active = 1 - _active
	var new := _music[_active]
	new.stream = _load(MUSIC_DIR % track, true)
	new.volume_db = SILENT_DB
	new.play()
	_kill_music_tween()
	_music_tween = create_tween().set_parallel()
	_music_tween.tween_property(new, "volume_db", 0.0, CROSSFADE).set_trans(Tween.TRANS_SINE)
	if old.playing:
		_music_tween.tween_property(old, "volume_db", SILENT_DB, CROSSFADE).set_trans(Tween.TRANS_SINE)
		_music_tween.chain().tween_callback(old.stop)

## Fade the music out and stop it (before a jingle or a quiet moment).
func stop_music(time := 0.5) -> void:
	current_music = ""
	var now := _music[_active]
	if not now.playing:
		return
	_kill_music_tween()
	_music_tween = create_tween()
	_music_tween.tween_property(now, "volume_db", SILENT_DB, time)
	_music_tween.tween_callback(now.stop)

## Lower the music (pause menu) or bring it back.
func set_music_lowered(lowered: bool) -> void:
	_fade(_music[_active], PAUSED_MUSIC_DB if lowered else 0.0, 0.3)

## A short piece over everything (level complete, try again). The music fades out under it.
func play_jingle(name: String) -> void:
	stop_music(0.3)
	_jingle.stream = _load(MUSIC_DIR % name, false)
	_jingle.play()

# --- Sound effects ------------------------------------------------------------------------------

func play_sfx(name: String, pitch := 1.0, bus := "SFX") -> void:
	var rule: Array = SFX_RULES.get(name, [0.05, 2, 0.0])
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(name, -10.0)) < rule[0]:
		return
	var stream := _load(SFX_DIR % name, false)
	var copies := 0
	for v in _voices:
		if v.playing and v.stream == stream:
			copies += 1
	if copies >= rule[1]:
		return
	_last_played[name] = now
	var voice := _free_voice()
	voice.stream = stream
	voice.bus = bus
	voice.pitch_scale = pitch * (1.0 + randf_range(-rule[2], rule[2]))
	voice.play()

## Coins: a quick run of pickups climbs in pitch (a tiny reward that never turns into noise).
func play_coin() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_coin_streak = mini(_coin_streak + 1, COIN_STREAK_MAX) if now - _last_coin < COIN_STREAK_TIME else 0
	_last_coin = now
	play_sfx("sfx_coin", 1.0 + _coin_streak * COIN_STREAK_STEP)

func play_ui() -> void:
	play_sfx("sfx_button", 1.0, "UI")

## Soft looping purr during the hug.
func start_purr() -> void:
	_purr.stream = _load(SFX_DIR % "sfx_purr", true)
	_purr.volume_db = SILENT_DB
	_purr.play()
	_fade(_purr, 0.0, 0.6)

func stop_purr() -> void:
	if _purr.playing:
		var t := create_tween()
		t.tween_property(_purr, "volume_db", SILENT_DB, 0.8)
		t.tween_callback(_purr.stop)

# --- Helpers ------------------------------------------------------------------------------------

## Every button in the game clicks (touch-control buttons are not Buttons, so they stay silent).
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(play_ui)

func _free_voice() -> AudioStreamPlayer:
	for v in _voices:
		if not v.playing:
			return v
	var oldest: AudioStreamPlayer = _voices.pop_front()   # all busy: reuse the one that started first
	_voices.append(oldest)
	return oldest

func _load(path: String, loop: bool) -> AudioStream:
	if not _cache.has(path):
		var stream: AudioStream = load(path)
		if stream is AudioStreamOggVorbis:
			stream.loop = loop
		_cache[path] = stream
	return _cache[path]

func _player(bus_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus_name
	add_child(p)
	return p

func _fade(player: AudioStreamPlayer, to_db: float, time: float) -> void:
	if not player.playing:
		return
	_kill_music_tween()
	_music_tween = create_tween()
	_music_tween.tween_property(player, "volume_db", to_db, time)

func _kill_music_tween() -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()

func _mute(bus_name: String, muted: bool) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus >= 0:
		AudioServer.set_bus_mute(bus, muted)
