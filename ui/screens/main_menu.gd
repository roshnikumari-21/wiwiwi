extends Control
## Home page: the cottage porch. The kitten lies on her cushion, breathing and blinking now and then,
## the wooden-sign logo sways gently, and the big Play button opens the level map.
## Round buttons beside Play: Achievements (trophy), Settings, Leaderboards and the Cat Shop (paw).
## The Play Games ones sign in first if needed and explain kindly when Play Games isn't there (PC).
## Top-right: stars, Golden Yarns and the coin purse.

const STAGE_SIZE := Vector2(1774, 887)     ## size of the porch picture; Stage children use its pixels
const KITTEN_OPEN := preload("res://assets/art/ui/home/kitten_lying.png")
const KITTEN_BLINK := preload("res://assets/art/ui/home/kitten_lying_blink.png")
const STAR := preload("res://assets/art/ui/menu/level_star_full.png")
const YARN := preload("res://assets/art/objects/yarn.png")
const COIN := preload("res://assets/art/objects/coin_0.png")

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

func _on_play_games_failed(reason: String) -> void:
	menu.show_notice("PLAY_GAMES_TITLE", "PLAY_GAMES_UNAVAILABLE" if reason == "unavailable" else "PLAY_GAMES_SIGN_IN_FAILED")

func _on_play() -> void:
	play.disabled = true   # one tap is enough
	SceneTransition.change_scene("res://ui/screens/level_map.tscn")
