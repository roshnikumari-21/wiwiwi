extends Control
## World 1 level map: the meadow picture with 10 level spots along its path. Each spot shows the level
## number and its best stars, or a lock. The kitten waits on the next level to play. Tap an open
## level to play it. Spots past the last built level stay locked ("coming soon").

const MAP_SIZE := Vector2(1672, 941)        ## size of the map picture; spots below are in its pixels
## Level spots: the round pads painted along the map's path.
const SPOTS: Array[Vector2] = [
	Vector2(132, 358), Vector2(318, 380), Vector2(470, 473), Vector2(690, 545), Vector2(858, 578),
	Vector2(1000, 652), Vector2(1142, 684), Vector2(1295, 708), Vector2(1440, 698), Vector2(1560, 640),
]
const OPEN := preload("res://assets/art/ui/menu/level_open.png")
const LOCKED := preload("res://assets/art/ui/menu/level_locked.png")
const STAR_FULL := preload("res://assets/art/ui/menu/level_star_full.png")
const STAR_EMPTY := preload("res://assets/art/ui/menu/level_star_empty.png")
const CAT := preload("res://assets/art/characters/cat/cat_frames.tres")
const GIRL := preload("res://assets/art/characters/girl/girl_wait.png")
const GIRL_SPOT := Vector2(1615, 585)       ## where she waits, just past the last level
const BUTTON_WIDTH := 150.0                 ## in map pixels
const STAR_SIZE := 40.0
const PATH_WIDTH := 1640.0                  ## map pixels that must stay on screen: level 1 to the girl

@onready var map: Control = $Map
@onready var backdrop: TextureRect = $Backdrop
@onready var back: TextureButton = $UI/SafeArea/Back

var _buttons: Array[TextureButton] = []

func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()
	AudioManager.play_music("mus_home")   # same song as the home page: it carries on
	var levels: Array = GameState.catalog.levels
	var next_id: String = GameState.next_level_to_play().id
	for i in SPOTS.size():
		var level: LevelData = levels[i] if i < levels.size() else null
		_add_spot(i, level, level != null and level.id == next_id)
	_place_girl()
	back.pressed.connect(_go_home)

## The picture covers the whole screen (wider phones crop a little top and bottom). On squarer
## screens (tablets, 4:3 / 16:10) covering would cut off level 1 and the girl, so the map shrinks
## until the whole path fits, and a dimmed copy behind it fills the strips above and below.
func _fit() -> void:
	var screen := get_viewport_rect().size
	var cover := maxf(screen.x / MAP_SIZE.x, screen.y / MAP_SIZE.y)
	var s := minf(cover, screen.x / PATH_WIDTH)
	map.scale = Vector2(s, s)
	map.position = (screen - MAP_SIZE * s) * 0.5
	backdrop.scale = Vector2(cover, cover)
	backdrop.position = (screen - MAP_SIZE * cover) * 0.5
	backdrop.visible = s < cover
	($Map/Picture.material as ShaderMaterial).set_shader_parameter("fade", 0.07 if s < cover else 0.0)

func _add_spot(i: int, level: LevelData, is_next: bool) -> void:
	var unlocked := level != null and SaveManager.is_unlocked(level.id)
	var tex: Texture2D = OPEN if unlocked else LOCKED
	var button := TextureButton.new()
	button.name = "Level%d" % (i + 1)
	button.texture_normal = tex
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var size := Vector2(BUTTON_WIDTH, BUTTON_WIDTH * tex.get_height() / tex.get_width())
	button.size = size
	button.position = SPOTS[i] - size * 0.5
	button.pivot_offset = size * 0.5
	map.add_child(button)
	_buttons.append(button)
	if not unlocked:
		button.pressed.connect(_wobble.bind(button))
		return
	button.pressed.connect(_play.bind(level.id))

	var number := Label.new()
	number.text = str(i + 1)
	number.add_theme_font_size_override("font_size", 58)
	number.add_theme_color_override("font_color", Color.WHITE)
	number.add_theme_color_override("font_outline_color", Color(0.6, 0.33, 0.08))
	number.add_theme_constant_override("outline_size", 16)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.size = Vector2(size.x * 0.8, size.y * 0.8)
	number.position = Vector2(size.x * 0.12, 0)
	button.add_child(number)

	var earned := SaveManager.stars(level.id)
	for s in 3:
		var star := TextureRect.new()
		star.texture = STAR_FULL if s < earned else STAR_EMPTY
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.size = Vector2(STAR_SIZE, STAR_SIZE)
		star.position = Vector2(size.x * 0.5 + (s - 1) * (STAR_SIZE - 2) - STAR_SIZE * 0.5, size.y - 18 - (6 if s == 1 else 0))
		button.add_child(star)

	if is_next:
		_place_kitten(SPOTS[i])
		var pulse := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		pulse.tween_property(button, "scale", Vector2(1.08, 1.08), 0.7)
		pulse.tween_property(button, "scale", Vector2.ONE, 0.7)
		button.grab_focus.call_deferred()

## The kitten stands just above the level she'll play next, hopping now and then.
func _place_kitten(spot: Vector2) -> void:
	var cat := AnimatedSprite2D.new()
	cat.name = "Kitten"
	cat.sprite_frames = CAT
	cat.play("idle")
	cat.scale = Vector2(0.42, 0.42)
	cat.offset = Vector2(0, -131)
	cat.position = spot + Vector2(0, -48)
	CatSkins.apply(cat)
	map.add_child(cat)
	var hop := create_tween().set_loops()
	hop.tween_interval(2.0)
	hop.tween_property(cat, "position:y", cat.position.y - 26, 0.18).set_ease(Tween.EASE_OUT)
	hop.tween_property(cat, "position:y", cat.position.y, 0.22).set_ease(Tween.EASE_IN)

## The girl waits at the end of the path: where the kitten's journey leads.
func _place_girl() -> void:
	var girl := Sprite2D.new()
	girl.name = "Girl"
	girl.texture = GIRL
	girl.scale = Vector2(0.2, 0.2)
	girl.offset = Vector2(0, -GIRL.get_height() * 0.5 + 10)   # her shoe on the spot
	girl.position = GIRL_SPOT
	map.add_child(girl)
	map.move_child(girl, 1)   # behind the level buttons
	var breathe := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	breathe.tween_property(girl, "scale:y", 0.204, 1.3)
	breathe.tween_property(girl, "scale:y", 0.2, 1.3)

func _play(level_id: String) -> void:
	for b in _buttons:
		b.disabled = true   # one tap is enough
	GameState.start_level(level_id)

## A locked level shakes "no".
func _wobble(button: TextureButton) -> void:
	var t := create_tween()
	for x in [-10.0, 10.0, -6.0, 0.0]:
		t.tween_property(button, "rotation_degrees", x, 0.06)

## Android Back: to the home page.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_home()

func _go_home() -> void:
	SceneTransition.change_scene("res://ui/screens/main_menu.tscn")
