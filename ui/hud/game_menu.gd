class_name GameMenu
extends Control
## The popups, built from the UI kit: Paused, Level complete!, Try again? and Settings.
## A leafy cream panel with a wooden title sign, the kitten (cheering / sleepy) and pill buttons.
## Works while the game is paused. Emits what the player chose; the HUD/level act on it.

signal resume_pressed
signal restart_pressed
signal next_pressed
signal map_pressed
signal home_pressed
signal settings_closed

const SIZES := {"S": 0.8, "M": 1.0, "L": 1.2}   ## touch-button size choices
const UI := "res://assets/art/ui/menu/"
const PANEL := preload(UI + "panel_leafy.png")
const SIGN := preload(UI + "sign_wood.png")
const STAR_FULL := preload(UI + "level_star_full.png")
const STAR_EMPTY := preload(UI + "level_star_empty.png")
const COIN := preload(UI + "icon_coin.png")
const YARN := preload("res://assets/art/objects/yarn.png")
const CAT := preload("res://assets/art/characters/cat/cat_frames.tres")
const BROWN := Color(0.36, 0.2, 0.1)
const BOLD := preload("res://assets/fonts/Fredoka-Bold.ttf")

var _panel: PanelContainer
var _box: VBoxContainer
var _stars: HBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # usable while the game is paused
	top_level = true                           # covers the whole screen, not just the HUD's safe area
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.08, 0.16, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", -40)   # stars tuck behind the panel's top
	center.add_child(column)
	_stars = HBoxContainer.new()
	_stars.alignment = BoxContainer.ALIGNMENT_CENTER
	_stars.add_theme_constant_override("separation", -10)
	column.add_child(_stars)
	_panel = PanelContainer.new()
	var style := StyleBoxTexture.new()
	style.texture = PANEL
	style.texture_margin_left = 130
	style.texture_margin_right = 130
	style.texture_margin_top = 110
	style.texture_margin_bottom = 70
	style.content_margin_left = 70
	style.content_margin_right = 70
	style.content_margin_top = 30
	style.content_margin_bottom = 50
	_panel.add_theme_stylebox_override("panel", style)
	column.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 22)
	_panel.add_child(_box)

# --- The three popups ---------------------------------------------------------------------------

func show_pause() -> void:
	_clear()
	_title("PAUSE_TITLE")
	_box.add_child(_button("BTN_RESUME", "green", "play", resume_pressed, 640))
	_box.add_child(_button("BTN_RESTART", "yellow", "replay", restart_pressed, 640))
	_box.add_child(_row([_button("RESULT_MAP", "brown", "none", map_pressed, 180),
		_button("SETTINGS_TITLE", "brown", "settings", settings_closed, 300, show_settings.bind(true)),
		_button("BTN_HOME", "red", "home", home_pressed, 240)]))
	_open(0.0)

## Settings: music and sound on/off, touch-button size. Saved at once. `from_pause` puts a Back
## button that returns to the pause menu; otherwise it closes (home page).
func show_settings(from_pause := false) -> void:
	_clear()
	_title("SETTINGS_TITLE")
	_box.add_child(_toggle("SET_MUSIC", "music_on", "music"))
	_box.add_child(_toggle("SET_SOUND", "sound_on", "sound"))
	var size_row := _row([_label("SET_BUTTONS", 270)])
	for key in SIZES:
		var b := _button(key, "yellow" if is_equal_approx(SaveManager.get_setting("controls_size"), SIZES[key]) else "brown",
			"none", settings_closed, 116, _set_controls_size.bind(SIZES[key]))
		size_row.add_child(b)
	_box.add_child(size_row)
	_box.add_child(_button("BTN_BACK" if from_pause else "BTN_DONE", "green", "none", settings_closed, 400,
		show_pause if from_pause else close_settings))
	_open(0.0)

func close_settings() -> void:
	close()
	settings_closed.emit()

func _toggle(key: String, setting: String, icon_name: String) -> Control:
	var on: bool = SaveManager.get_setting(setting)
	var icon := _icon(load(UI + "icon_%s_%s.png" % [icon_name, "on" if on else "off"]), 74, Color.WHITE)
	var button := _button("ON" if on else "OFF", "green" if on else "red", "none", settings_closed, 170,
		func():
			SaveManager.set_setting(setting, not SaveManager.get_setting(setting))
			_refresh_settings())
	button.name = key
	return _row([icon, _label(key, 300), button])

func _set_controls_size(value: float) -> void:
	SaveManager.set_setting("controls_size", value)
	_refresh_settings()

func _refresh_settings() -> void:
	show_settings(_box.find_child("BTN_BACK", true, false) != null)


func show_complete(stars: int, coins: int, coin_total: int, has_yarn: bool, has_next: bool) -> void:
	_clear()
	for i in 3:
		var star := TextureRect.new()
		star.texture = STAR_FULL if i < stars else STAR_EMPTY
		star.custom_minimum_size = Vector2(150, 145) if i == 1 else Vector2(120, 116)
		star.size_flags_vertical = Control.SIZE_SHRINK_END if i != 1 else Control.SIZE_SHRINK_BEGIN
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.pivot_offset = star.custom_minimum_size * 0.5
		star.scale = Vector2.ZERO
		_stars.add_child(star)
		if i < stars:   # earned stars pop in one after another
			var pop := create_tween()
			pop.tween_interval(0.5 + i * 0.25)
			pop.tween_property(star, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			star.scale = Vector2.ONE
	_stars.show()
	_title("RESULT_WIN")
	var middle := _row([_kitten("cheer"), _score(coins, coin_total, has_yarn)])
	middle.add_theme_constant_override("separation", 50)
	_box.add_child(middle)
	var buttons := [_button("RESULT_MAP", "brown", "none", map_pressed, 230),
		_button("RESULT_REPLAY", "yellow", "replay", restart_pressed, 260 if has_next else 380)]
	if has_next:
		buttons.append(_button("RESULT_NEXT", "green", "play", next_pressed, 260))
	_box.add_child(_row(buttons))
	_open(0.6)

func show_fail() -> void:
	_clear()
	_title("RESULT_FAIL")
	_box.add_child(_kitten("sleepy"))
	_box.add_child(_row([_button("RESULT_RETRY", "yellow", "replay", restart_pressed, 330),
		_button("RESULT_MAP", "red", "none", map_pressed, 300)]))
	_open(0.6)

func close() -> void:
	hide()

# --- Pieces -------------------------------------------------------------------------------------

func _clear() -> void:
	for child in _box.get_children() + _stars.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	_stars.hide()

func _title(key: String) -> void:
	var sign := TextureRect.new()
	sign.texture = SIGN
	sign.custom_minimum_size = Vector2(620, 162)
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sign.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sign.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var label := Label.new()
	label.name = "Title"
	label.text = key
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", BOLD)
	label.add_theme_font_size_override("font_size", 64 if tr(key).length() <= 10 else 54)   # long titles fit the sign
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.78))
	label.add_theme_color_override("font_outline_color", BROWN)
	label.add_theme_constant_override("outline_size", 18)
	sign.add_child(label)
	_box.add_child(sign)

## A pill button. It emits `pressed` when tapped, or calls `action` instead when one is given.
func _button(key: String, colour: String, symbol: String, pressed: Signal, width: float, action := Callable()) -> PillButton:
	var b := PillButton.new()
	b.name = key
	b.text = key
	b.colour = colour
	b.symbol = symbol
	b.custom_minimum_size = Vector2(width, 118)
	b.pressed.connect(action if action.is_valid() else pressed.emit)
	return b

func _label(key: String, width: float) -> Label:
	var label := Label.new()
	label.text = key
	label.custom_minimum_size = Vector2(width, 0)
	label.add_theme_font_size_override("font_size", 46)
	label.add_theme_color_override("font_color", BROWN)
	return label

func _row(items: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	for item in items:
		row.add_child(item)
	return row

## The game's own kitten, playing an animation, standing in a small space of its own.
func _kitten(animation: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(300, 220)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var cat := AnimatedSprite2D.new()
	cat.sprite_frames = CAT
	cat.play(animation)
	cat.scale = Vector2(0.78, 0.78)
	cat.offset = Vector2(0, -131)
	cat.position = Vector2(150, 215)
	holder.add_child(cat)
	return holder

func _score(coins: int, coin_total: int, has_yarn: bool) -> Control:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	var coin_row := HBoxContainer.new()
	coin_row.add_theme_constant_override("separation", 14)
	coin_row.add_child(_icon(COIN, 82, Color.WHITE))
	var label := Label.new()
	label.name = "Coins"
	label.text = "%d / %d" % [coins, coin_total]
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", BROWN)
	coin_row.add_child(label)
	column.add_child(coin_row)
	var yarn_row := HBoxContainer.new()
	yarn_row.add_theme_constant_override("separation", 14)
	yarn_row.add_child(_icon(YARN, 82, Color.WHITE if has_yarn else Color(0.25, 0.22, 0.2, 0.35)))
	var yarn_label := Label.new()
	yarn_label.text = "YARN_FOUND" if has_yarn else "YARN_MISSED"
	yarn_label.add_theme_font_size_override("font_size", 40)
	yarn_label.add_theme_color_override("font_color", BROWN if has_yarn else Color(0.55, 0.45, 0.38))
	yarn_row.add_child(yarn_label)
	column.add_child(yarn_row)
	return column

func _icon(texture: Texture2D, size: float, tint: Color) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(size, size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = tint
	return icon

func _open(delay: float) -> void:
	if visible and delay == 0.0:   # switching popups (pause <-> settings): no re-entrance animation
		_panel.scale = Vector2.ONE
		_focus_first.call_deferred()
		return
	modulate.a = 0.0
	show()
	_panel.pivot_offset = _panel.size * 0.5
	var t := create_tween().set_parallel()
	t.tween_property(self, "modulate:a", 1.0, 0.25).set_delay(delay)
	_panel.scale = Vector2(0.85, 0.85)
	t.tween_property(_panel, "scale", Vector2.ONE, 0.3).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_focus_first.call_deferred()

func _focus_first() -> void:
	var first := _box.find_children("*", "PillButton", true, false)
	if not first.is_empty():
		first[0].grab_focus()
