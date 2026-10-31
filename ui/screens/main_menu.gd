extends Control
## Home page: the cottage porch. The kitten lies on her cushion, breathing and blinking now and then,
## the wooden-sign logo sways gently, and the big Play button opens the level map.
## The round button opens Settings. Trophy / achievements buttons join with Play Games (no dead buttons).

const STAGE_SIZE := Vector2(1774, 887)     ## size of the porch picture; Stage children use its pixels
const KITTEN_OPEN := preload("res://assets/art/ui/home/kitten_lying.png")
const KITTEN_BLINK := preload("res://assets/art/ui/home/kitten_lying_blink.png")

@onready var stage: Control = $Stage
@onready var kitten: Sprite2D = $Stage/Kitten
@onready var logo: Sprite2D = $Stage/Logo
@onready var play: TextureButton = $Stage/Play
@onready var settings: TextureButton = $Stage/Settings
var menu: GameMenu

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
	play.grab_focus.call_deferred()
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

func _on_play() -> void:
	play.disabled = true   # one tap is enough
	SceneTransition.change_scene("res://ui/screens/level_map.tscn")
