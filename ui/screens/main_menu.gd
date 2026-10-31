extends Control
## Home page: the cottage porch. The kitten lies on her cushion, breathing and blinking now and then,
## the wooden-sign logo sways gently, and the big Play button opens the level map.
## Round buttons beside Play: Achievements (trophy), Settings, Leaderboards and the Cat Shop (paw).
## The Play Games ones sign in first if needed and explain kindly when Play Games isn't there (PC).
## Top-right: stars, Golden Yarns and the coin purse. Tap the kitten to pet her: she closes her
## eyes, purrs and little hearts float up; she opens her eyes again a moment after the last pat.

const STAGE_SIZE := Vector2(1774, 887)     ## size of the porch picture; Stage children use its pixels
const KITTEN_OPEN := preload("res://assets/art/ui/home/kitten_lying.png")
const KITTEN_BLINK := preload("res://assets/art/ui/home/kitten_lying_blink.png")
const STAR := preload("res://assets/art/ui/menu/level_star_full.png")
const YARN := preload("res://assets/art/objects/yarn.png")
const COIN := preload("res://assets/art/objects/coin_0.png")
const HEART := preload("res://assets/art/objects/heart_full.png")
const PET_AREA := Rect2(769, 470, 290, 230)   ## the kitten on her cushion, in Stage pixels
const PET_TIME := 1.6                         ## seconds she stays happy after the last pat

@onready var stage: Control = $Stage
@onready var kitten: Sprite2D = $Stage/Kitten
@onready var logo: Sprite2D = $Stage/Logo
@onready var play: TextureButton = $Stage/Play
@onready var settings: TextureButton = $Stage/Settings
@onready var achievements: TextureButton = $Stage/Achievements
@onready var leaderboards: TextureButton = $Stage/Leaderboards
@onready var cat_shop: TextureButton = $Stage/CatShop
var menu: GameMenu
var _stars := StatPill.new(STAR)
var _yarns := StatPill.new(YARN)
var _coins := StatPill.new(COIN)
var _petting := false
var _pats := 0   ## counts pats, so only the last one's timer wakes her

func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()
	AudioManager.play_music("mus_home")
	play.pressed.connect(_on_play)
	menu = GameMenu.new()
	menu.name = "Menu"
	$UI.add_child(menu)
	settings.pressed.connect(menu.show_settings)
	menu.quit_pressed.connect(func(): get_tree().quit())
	achievements.pressed.connect(PlayServices.show_achievements)
	leaderboards.pressed.connect(PlayServices.show_leaderboards)
	cat_shop.pressed.connect(menu.show_cat_shop)
	PlayServices.open_failed.connect(_on_play_games_failed)
	play.grab_focus.call_deferred()
	_add_top_bar()
	_add_pet_area()
	_breathe()
	_blink_later()
	var sway := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	sway.tween_property(logo, "rotation_degrees", 1.2, 1.8)
	sway.tween_property(logo, "rotation_degrees", -1.2, 1.8)

## The porch always covers the whole screen (very wide or tall screens crop its edges a little).
func _fit() -> void:
	var screen := get_viewport_rect().size
	var s := maxf(screen.x / STAGE_SIZE.x, screen.y / STAGE_SIZE.y)
	stage.scale = Vector2(s, s)
	stage.position = (screen - STAGE_SIZE * s) * 0.5

## Top-right: stars won, Golden Yarns found and the coin purse.
func _add_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "TopBar"
	bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bar.add_theme_constant_override("separation", 16)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pill in [_stars, _yarns, _coins]:
		bar.add_child(pill)
	$UI/SafeArea.add_child(bar)
	_show_progress()
	SaveManager.progress_changed.connect(_show_progress)

func _show_progress() -> void:
	var stars := SaveManager.total_stars()
	var yarns := SaveManager.total_yarns()
	_stars.set_text("%d / %d" % [stars.x, stars.y])
	_yarns.set_text("%d / %d" % [yarns.x, yarns.y])
	_coins.set_text(str(SaveManager.purse()))
	CatSkins.apply(kitten)   # the cushion kitten wears the colour chosen in the Cat Shop

func _breathe() -> void:
	var base := kitten.scale
	var t := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	t.tween_property(kitten, "scale", base * Vector2(1.0, 1.02), 1.4)
	t.tween_property(kitten, "scale", base, 1.4)

## Blink every few seconds, sometimes twice.
func _blink_later() -> void:
	await get_tree().create_timer(randf_range(2.5, 5.0)).timeout
	for i in (2 if randf() < 0.25 else 1):
		if _petting:   # her eyes are already closed with joy
			break
		kitten.texture = KITTEN_BLINK
		await get_tree().create_timer(0.14).timeout
		kitten.texture = KITTEN_OPEN
		await get_tree().create_timer(0.16).timeout
	if is_inside_tree():
		_blink_later()

## Android Back: close Settings, otherwise ask "Leave wiwiwi?" (no quit button on Android).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and menu and not menu.go_back():
		menu.show_quit()

## An invisible touch area over the kitten (not a Button, so it doesn't make the button click).
func _add_pet_area() -> void:
	var area := Control.new()
	area.name = "PetArea"
	area.position = PET_AREA.position
	area.size = PET_AREA.size
	area.gui_input.connect(func(event: InputEvent):
		if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
			pet())
	stage.add_child(area)

func pet() -> void:
	_pats += 1
	var pat := _pats
	if not _petting:
		_petting = true
		kitten.texture = KITTEN_BLINK
		AudioManager.start_purr()
		if randf() < 0.5:
			AudioManager.play_sfx("sfx_meow_happy")
	var nudge := create_tween().set_trans(Tween.TRANS_SINE)   # a happy little wiggle down and up
	nudge.tween_property(kitten, "position:y", 694.0, 0.08)
	nudge.tween_property(kitten, "position:y", 688.0, 0.18)
	for i in 2:
		_float_heart(Vector2(914.0 + randf_range(-90.0, 90.0), 470.0), i * 0.18)
	await get_tree().create_timer(PET_TIME).timeout
	if pat == _pats and is_inside_tree():   # no newer pat: wake up
		_petting = false
		kitten.texture = KITTEN_OPEN
		AudioManager.stop_purr()

func _float_heart(from: Vector2, delay: float) -> void:
	var heart := Sprite2D.new()
	heart.texture = HEART
	heart.scale = Vector2(0.16, 0.16)
	heart.position = from
	heart.modulate.a = 0.0
	stage.add_child(heart)
	var t := create_tween().set_parallel()
	t.tween_property(heart, "modulate:a", 1.0, 0.2).set_delay(delay)
	t.tween_property(heart, "position:y", from.y - 150.0, 1.2).set_delay(delay).set_ease(Tween.EASE_OUT)
	t.tween_property(heart, "modulate:a", 0.0, 0.4).set_delay(delay + 0.8)
	t.chain().tween_callback(heart.queue_free)

func _exit_tree() -> void:
	if _petting:
		AudioManager.stop_purr()

func _on_play_games_failed(reason: String) -> void:
	menu.show_notice("PLAY_GAMES_TITLE", "PLAY_GAMES_UNAVAILABLE" if reason == "unavailable" else "PLAY_GAMES_SIGN_IN_FAILED")

func _on_play() -> void:
	play.disabled = true   # one tap is enough
	SceneTransition.change_scene("res://ui/screens/level_map.tscn")
