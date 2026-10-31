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
signal quit_pressed

## Which popup is showing: "", "pause", "settings", "complete", "fail", "quit", "notice", "shop".
var current := ""
var _settings_from_pause := false
var _shop_index := 0   ## which cat the shop is showing

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
	current = "pause"
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
	current = "settings"
	_settings_from_pause = from_pause
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
	_box.add_child(_row([_button("CREDITS_TITLE", "brown", "none", settings_closed, 260, show_credits),
		_button("BTN_BACK" if from_pause else "BTN_DONE", "green", "none", settings_closed, 300,
		show_pause if from_pause else close_settings)]))
	_open(0.0)

## Credits and the licence texts the game must ship (Godot MIT + its third-party parts, Fredoka OFL,
## the Play Games plugin MIT). Godot's own texts come from the engine, so they always match the
## version the game was built with. Scrolls with a finger; Back returns to Settings.
func show_credits() -> void:
	current = "credits"
	_clear()
	_title("CREDITS_TITLE")
	var scroll := ScrollContainer.new()
	scroll.name = "CreditsScroll"
	scroll.custom_minimum_size = Vector2(1100, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 14)
	scroll.add_child(text)
	_credit(text, "CREDITS_MADE_BY", "", 44)
	_credit(text, "", "CREDITS_THANKS", 30)
	_credit(text, "CREDITS_ART_AUDIO", "CREDITS_ART_AUDIO_TEXT", 30)
	_credit(text, "Godot Engine", Engine.get_license_text(), 22)
	_credit(text, "Fredoka", _read("res://assets/fonts/licenses/Fredoka-OFL.txt"), 22)
	_credit(text, "Godot Play Game Services", _read("res://addons/GodotPlayGameServices/LICENSE"), 22)
	var parts := ""
	for part in Engine.get_copyright_info():
		parts += "%s
" % part["name"]
		for c in part["parts"]:
			parts += "  © %s (%s)
" % [", ".join(c["copyright"]), c["license"]]
	_credit(text, "CREDITS_ENGINE_PARTS", parts, 20)
	var licenses := Engine.get_license_info()
	for name in licenses:
		_credit(text, name, licenses[name], 18)
	_box.add_child(scroll)
	_box.add_child(_button("BTN_BACK", "green", "none", settings_closed, 300, show_settings.bind(_settings_from_pause)))
	_open(0.0)

func _credit(into: VBoxContainer, heading: String, body: String, size: int) -> void:
	if heading != "":
		var h := Label.new()
		h.text = heading
		h.add_theme_font_override("font", BOLD)
		h.add_theme_font_size_override("font_size", maxi(size + 6, 30))
		h.add_theme_color_override("font_color", BROWN)
		into.add_child(h)
	if body != "":
		var b := Label.new()
		b.text = body
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(1040, 0)
		b.add_theme_font_size_override("font_size", size)
		b.add_theme_color_override("font_color", Color(0.4, 0.3, 0.24))
		into.add_child(b)

func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""

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
	show_settings(_settings_from_pause)


func show_complete(stars: int, coins: int, coin_total: int, has_yarn: bool, has_next: bool) -> void:
	current = "complete"
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
			pop.tween_callback(AudioManager.play_sfx.bind("sfx_star", 1.0 + i * 0.12))   # each star a little higher
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

## After the world's last level: total stars for the whole world, then home or map.
func show_world_complete(world: int, total_stars: int, max_stars: int) -> void:
	current = "complete"
	_clear()
	_title("WORLD%d_DONE" % world)
	var tagline := _label("HOME_SWEET", 0)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(tagline)
	var star_row := _row([_kitten("cheer"), _icon(STAR_FULL, 110, Color.WHITE)])
	var count := Label.new()
	count.name = "WorldStars"
	count.text = "%d / %d" % [total_stars, max_stars]
	count.add_theme_font_override("font", BOLD)
	count.add_theme_font_size_override("font_size", 72)
	count.add_theme_color_override("font_color", BROWN)
	star_row.add_child(count)
	_box.add_child(star_row)
	_box.add_child(_row([_button("RESULT_MAP", "brown", "none", map_pressed, 260),
		_button("BTN_HOME", "green", "home", home_pressed, 320)]))
	_open(0.6)

func show_fail() -> void:
	current = "fail"
	_clear()
	_title("RESULT_FAIL")
	_box.add_child(_kitten("sleepy"))
	_box.add_child(_row([_button("RESULT_RETRY", "yellow", "replay", restart_pressed, 330),
		_button("RESULT_MAP", "red", "none", map_pressed, 300)]))
	_open(0.6)

## Android Back on the home page: ask before leaving the game.
func show_quit() -> void:
	current = "quit"
	_clear()
	_title("QUIT_TITLE")
	_box.add_child(_kitten("sleepy"))
	_box.add_child(_row([_button("BTN_STAY", "green", "none", settings_closed, 300, close),
		_button("BTN_LEAVE", "red", "none", quit_pressed, 300)]))
	_open(0.0)

## A short message with an OK button (e.g. "Play Games isn't available").
func show_notice(title_key: String, text_key: String) -> void:
	current = "notice"
	_clear()
	_title(title_key)
	_box.add_child(_kitten("idle"))
	var text := _label(text_key, 640)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(text)
	_box.add_child(_row([_button("BTN_OK", "green", "none", settings_closed, 300, close)]))
	_open(0.0)

## Cat Shop: one big cat at a time, arrows to look through them, and Buy / Choose below.
func show_cat_shop(index := -1) -> void:
	current = "shop"
	if index < 0:   # opening: start at the chosen cat
		index = CatSkins.ALL.find(CatSkins.find(SaveManager.chosen_cat()))
	_shop_index = posmod(index, CatSkins.ALL.size())
	var skin: Dictionary = CatSkins.ALL[_shop_index]
	_clear()
	_title("SHOP_TITLE")
	var purse := StatPill.new(COIN)
	purse.name = "Purse"
	purse.set_text(str(SaveManager.purse()))
	purse.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(purse)
	var cat := _kitten("cheer" if SaveManager.owns_cat(skin.id) else "idle")
	cat.custom_minimum_size = Vector2(400, 300)   # the star of this popup: bigger than usual
	var sprite: AnimatedSprite2D = cat.get_child(0)
	sprite.scale = Vector2(1.1, 1.1)
	sprite.position = Vector2(200, 295)
	CatSkins.apply(sprite, skin.id)
	var name_label := _label(skin.name, 0)
	name_label.name = "CatName"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", BOLD)
	var middle := VBoxContainer.new()
	middle.add_child(cat)
	middle.add_child(name_label)
	_box.add_child(_row([_arrow(-1), middle, _arrow(1)]))
	var main: PillButton
	if skin.id == SaveManager.chosen_cat():
		main = _button("BTN_CHOSEN", "green", "none", settings_closed, 330, func(): pass)
		main.disabled = true
	elif SaveManager.owns_cat(skin.id):
		main = _button("BTN_CHOOSE", "yellow", "none", settings_closed, 330, func():
			SaveManager.choose_cat(skin.id)
			show_cat_shop(_shop_index))
	elif SaveManager.purse() >= skin.price:
		main = _button(str(skin.price), "green", "coin", settings_closed, 330, func():
			SaveManager.buy_cat(skin.id)
			AudioManager.play_sfx("sfx_confetti")
			AudioManager.play_sfx("sfx_meow_happy")
			show_cat_shop(_shop_index))
	else:
		main = _button(tr("SHOP_NEED") % skin.price, "brown", "coin", settings_closed, 330, func(): pass)
		main.disabled = true
	main.name = "ShopMain"
	_box.add_child(_row([main, _button("BTN_DONE", "brown", "none", settings_closed, 260, close)]))
	_open(0.0)

func _arrow(step: int) -> TextureButton:
	var b := TextureButton.new()
	b.name = "Next" if step > 0 else "Previous"
	b.texture_normal = preload(UI + "round_brown_plain.png")
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(110, 110)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon := _icon(preload(UI + "icon_next.png"), 0, Color.WHITE)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 28; icon.offset_right = -28; icon.offset_top = 26; icon.offset_bottom = -30
	icon.flip_h = step < 0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	b.pressed.connect(func(): show_cat_shop(_shop_index + step))
	return b

func close() -> void:
	current = ""
	hide()

## Android Back while a popup is open. Returns false when nothing was open (the screen handles it).
func go_back() -> bool:
	match current:
		"pause": resume_pressed.emit()
		"settings":
			if _settings_from_pause:
				show_pause()
			else:
				close_settings()
		"quit", "notice", "shop": close()
		"credits": show_settings(_settings_from_pause)
		"complete", "fail": map_pressed.emit()
		_: return false
	return true

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
	CatSkins.apply(cat)
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
