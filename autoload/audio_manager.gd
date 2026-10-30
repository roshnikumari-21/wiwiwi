extends Node
## Audio buses (Music, SFX, UI) follow the player's on/off settings. "Sound" covers SFX and UI.
## Music playback and the SFX pool are added with the sounds themselves (later in M2).

func _ready() -> void:
	SaveManager.settings_changed.connect(func(_key, _value): apply_settings())
	apply_settings()

func apply_settings() -> void:
	_mute("Music", not SaveManager.get_setting("music_on"))
	var sound_off: bool = not SaveManager.get_setting("sound_on")
	_mute("SFX", sound_off)
	_mute("UI", sound_off)

func _mute(bus_name: String, muted: bool) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus >= 0:
		AudioServer.set_bus_mute(bus, muted)
