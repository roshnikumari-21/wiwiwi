extends Control
## Level map: one picture per world with 10 level spots along its path. Each spot shows the level
## number and its best stars, or a lock. The kitten waits on the next level to play. Tap an open
## level to play it. Spots past the last built level stay locked ("coming soon").
## ◀ ▶ switch worlds; the map opens on the world of the next level to play. A world's first level
## opens when the previous world's last level is done (SaveManager.is_unlocked).

const MAP_SIZE := Vector2(1672, 941)        ## size of every map picture; spots below are in its pixels
## Per world: the map picture, the 10 round pads painted along its path, where the girl waits
## (just past the last level), and the world's name. Add a world = add an entry.
const WORLDS: Array[Dictionary] = [
	{
		"picture": preload("res://assets/art/backgrounds/map/map_w1.png"),
		"spots": [
			Vector2(132, 358), Vector2(318, 380), Vector2(470, 473), Vector2(690, 545), Vector2(858, 578),
			Vector2(1000, 652), Vector2(1142, 684), Vector2(1295, 708), Vector2(1440, 698), Vector2(1560, 640),
		],
		"girl": Vector2(1615, 585), "name": "WORLD_1_NAME",
	},
	{
		"picture": preload("res://assets/art/backgrounds/map/map_w2.png"),
		"spots": [   # measured from the pads' tops (+6 px for their thickness)
			Vector2(118, 453), Vector2(272, 520), Vector2(446, 521), Vector2(596, 449), Vector2(764, 474),
			Vector2(908, 549), Vector2(1063, 500), Vector2(1219, 481), Vector2(1370, 448), Vector2(1519, 419),
		],
		"girl": Vector2(1615, 410), "name": "WORLD_2_NAME",   # by the red-door house at the path's end
	},
	{
		"picture": preload("res://assets/art/backgrounds/map/map_w3.png"),
		"spots": [   # measured from the pads (+6 px for their thickness)
			Vector2(113, 506), Vector2(279, 572), Vector2(442, 506), Vector2(593, 448), Vector2(738, 519),
			Vector2(892, 600), Vector2(1064, 546), Vector2(1210, 481), Vector2(1374, 527), Vector2(1536, 458),
		],
		"girl": Vector2(1625, 445), "name": "WORLD_3_NAME",   # past the last pad, by the cottage
	},
]
const OPEN := preload("res://assets/art/ui/menu/level_open.png")
const LOCKED := preload("res://assets/art/ui/menu/level_locked.png")
const STAR_FULL := preload("res://assets/art/ui/menu/level_star_full.png")
const STAR_EMPTY := preload("res://assets/art/ui/menu/level_star_empty.png")
const CAT := preload("res://assets/art/characters/cat/cat_frames.tres")
const GIRL := preload("res://assets/art/characters/girl/girl_wait.png")
const SIGN := preload("res://assets/art/ui/menu/sign_wood.png")
const ROUND := preload("res://assets/art/ui/menu/round_brown_plain.png")
const ARROW := preload("res://assets/art/ui/menu/icon_next.png")
const BOLD := preload("res://assets/fonts/Fredoka-Bold.ttf")
const HEART := preload("res://assets/art/objects/heart_full.png")
const KITTEN_SCALE := Vector2(0.42, 0.42)
const KITTEN_LIFT := Vector2(0, -48)        ## the kitten stands this far above a pad's centre
const HOP_LENGTH := 80.0                    ## map px per little hop when she walks on
const GIRL_SIDE := Vector2(-70, 40)         ## where she stops next to the girl (from the girl's spot)
const BUTTON_WIDTH := 150.0                 ## in map pixels
const STAR_SIZE := 40.0
const PATH_WIDTH := 1640.0                  ## map pixels that must stay on screen: level 1 to the girl

@onready var map: Control = $Map
@onready var backdrop: TextureRect = $Backdrop
@onready var back: TextureButton = $UI/SafeArea/Back

var world := 1   ## the world shown (1-based)
var menu: GameMenu
var last_played := ""   ## the level a spot or the walk started (tests read it)
var _buttons: Array[TextureButton] = []
var _world_label: Label
var _prev: TextureButton
var _next: TextureButton
var _busy := false   ## an animation is playing: level spots and arrows don't react

func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()
	AudioManager.play_music("mus_home")   # same song as the home page: it carries on
	_add_world_switch()
	menu = GameMenu.new()
	menu.name = "Menu"
	$UI.add_child(menu)
	back.pressed.connect(_go_home)
	# A level just finished for the first time: show the kitten walking on to what it opened.
	var from := GameState.catalog.get_level(GameState.map_walk_from)
	var to := GameState.catalog.next_after(GameState.map_walk_from) if from else null
	var auto := GameState.map_auto_play
	GameState.map_walk_from = ""
	GameState.map_auto_play = false
	if from and to:
		_walk_on(from, to, auto)
	else:
		show_world(clampi(GameState.next_level_to_play().world, 1, WORLDS.size()))

## Shows one world: its picture, its level spots and the girl. `hold` = a level id drawn still
## locked, with no kitten (the walk animation opens it).
func show_world(number: int, hold := "") -> void:
	world = number
	var info: Dictionary = WORLDS[world - 1]
	for node in map.get_children():
		if node.name != "Picture":
			map.remove_child(node)
			node.queue_free()
	_buttons.clear()
	$Map/Picture.texture = info.picture
	backdrop.texture = info.picture
	var levels: Array = GameState.catalog.levels.filter(func(l): return l.world == world)
	var next_id: String = GameState.next_level_to_play().id
	var spots: Array = info.spots
	for i in spots.size():
		var level: LevelData = levels[i] if i < levels.size() else null
		var held := level != null and level.id == hold
		_add_spot(i, level, level != null and level.id == next_id and not held, held)
	_place_girl(info.girl)
	_world_label.text = tr("WORLD_N") % world + "  ·  " + tr(info.name)
	_prev.visible = world > 1 and not _busy
	_next.visible = world < WORLDS.size() and not _busy

# --- Walking on after a first finish -----------------------------------------------------------

## The kitten hops along the path from the level she finished to the one it opened, whose lock pops
## open. After a world's last level she walks to the girl, "World N unlocked!" shows, and the map
## moves on to the new world. `auto`: the player tapped Next, so the new level starts afterwards.
func _walk_on(from: LevelData, to: LevelData, auto: bool) -> void:
	_busy = true
	show_world(from.world, to.id)
	var spots: Array = WORLDS[from.world - 1].spots
	var cat := _place_kitten(spots[from.index - 1], false)
	if to.world == from.world:
		await _hop_along(cat, spots[from.index - 1], spots[to.index - 1])
	elif to.world <= WORLDS.size():
		await _hop_along(cat, spots[from.index - 1], WORLDS[from.world - 1].girl + GIRL_SIDE)
		for i in 4:
			_float_heart(cat.position + Vector2(randf_range(-40.0, 60.0), -150.0), i * 0.2)
		AudioManager.play_sfx("sfx_meow_happy")
		await get_tree().create_timer(1.2).timeout
		AudioManager.play_sfx("sfx_confetti")
		menu.show_world_unlocked(to.world, WORLDS[to.world - 1].name)
		await menu.next_pressed
		menu.close()
		var fade := create_tween()
		fade.tween_property(self, "modulate:a", 0.0, 0.3)
		await fade.finished
		show_world(to.world, to.id)
		var new_spots: Array = WORLDS[to.world - 1].spots
		cat = _place_kitten(new_spots[0], false)
		cat.scale = Vector2.ZERO
		fade = create_tween()
		fade.tween_property(self, "modulate:a", 1.0, 0.3)
		fade.tween_property(cat, "scale", KITTEN_SCALE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await fade.finished
	await get_tree().create_timer(0.15).timeout
	_busy = false
	show_world(to.world)   # the new level now drawn open, the kitten waiting on it
	var button: TextureButton = map.get_node_or_null("Level%d" % to.index)
	if button:
		AudioManager.play_sfx("sfx_star")
		button.scale = Vector2(0.4, 0.4)
		var pop := button.create_tween()
		pop.tween_property(button, "scale", Vector2(1.25, 1.25), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(button, "scale", Vector2.ONE, 0.18)
		await pop.finished
	if auto:
		await get_tree().create_timer(0.6).timeout
		_play(to.id)

## Little hops from one spot to another (spots are where a kitten stands on a level pad).
func _hop_along(cat: AnimatedSprite2D, from: Vector2, to: Vector2) -> void:
	var hops := maxi(2, roundi(from.distance_to(to) / HOP_LENGTH))
	cat.flip_h = to.x < from.x
	cat.play("walk")
	AudioManager.play_sfx("sfx_jump")
	for k in hops:
		var a := from.lerp(to, float(k) / hops) + KITTEN_LIFT
		var b := from.lerp(to, float(k + 1) / hops) + KITTEN_LIFT
		var t := cat.create_tween()
		t.tween_property(cat, "position", (a + b) * 0.5 + Vector2(0, -26), 0.13).set_ease(Tween.EASE_OUT)
		t.tween_property(cat, "position", b, 0.13).set_ease(Tween.EASE_IN)
		await t.finished
	cat.flip_h = false
	cat.play("idle")

func _float_heart(at: Vector2, delay: float) -> void:
	var heart := Sprite2D.new()
	heart.texture = HEART
	heart.scale = Vector2(0.14, 0.14)
	heart.position = at
	heart.modulate.a = 0.0
	map.add_child(heart)
	var t := heart.create_tween().set_parallel()
	t.tween_property(heart, "modulate:a", 1.0, 0.2).set_delay(delay)
	t.tween_property(heart, "position:y", at.y - 120.0, 1.2).set_delay(delay).set_ease(Tween.EASE_OUT)
	t.tween_property(heart, "modulate:a", 0.0, 0.4).set_delay(delay + 0.8)
	t.chain().tween_callback(heart.queue_free)

## A wooden sign with the world's name at the top, with ◀ ▶ on either side of it (the sky is empty
## there on every map, so they never cover a level, the kitten or the girl).
func _add_world_switch() -> void:
	var holder := Control.new()
	holder.name = "WorldSwitch"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI/SafeArea.add_child(holder)
	_prev = _arrow(holder, -1)
	_next = _arrow(holder, 1)
	var sign := TextureRect.new()
	sign.texture = SIGN
	sign.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sign.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.custom_minimum_size = Vector2(560, 120)
	sign.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	sign.offset_left = -280
	sign.offset_right = 280
	sign.offset_bottom = 120
	holder.add_child(sign)
	_world_label = Label.new()
	_world_label.name = "WorldName"
	_world_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_world_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_world_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_world_label.add_theme_font_override("font", BOLD)
	_world_label.add_theme_font_size_override("font_size", 40)
	_world_label.add_theme_color_override("font_color", Color(1, 0.95, 0.78))
	_world_label.add_theme_color_override("font_outline_color", Color(0.36, 0.2, 0.1))
	_world_label.add_theme_constant_override("outline_size", 14)
	sign.add_child(_world_label)

func _arrow(holder: Control, step: int) -> TextureButton:
	var b := TextureButton.new()
	b.name = "NextWorld" if step > 0 else "PreviousWorld"
	b.texture_normal = ROUND
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	b.custom_minimum_size = Vector2(110, 110)
	b.offset_top = 5
	b.offset_bottom = 115
	b.offset_left = 300 if step > 0 else -410   # just right / left of the 560 px sign
	b.offset_right = b.offset_left + 110
	var icon := TextureRect.new()
	icon.texture = ARROW
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 32
	icon.offset_right = -32
	icon.offset_top = 30
	icon.offset_bottom = -34
	icon.flip_h = step < 0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	b.pressed.connect(func(): show_world(world + step))
	holder.add_child(b)
	return b

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

func _add_spot(i: int, level: LevelData, is_next: bool, held := false) -> void:
	var unlocked := level != null and SaveManager.is_unlocked(level.id) and not held
	var tex: Texture2D = OPEN if unlocked else LOCKED
	var button := TextureButton.new()
	button.name = "Level%d" % (i + 1)
	button.texture_normal = tex
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var size := Vector2(BUTTON_WIDTH, BUTTON_WIDTH * tex.get_height() / tex.get_width())
	button.size = size
	var spot: Vector2 = WORLDS[world - 1].spots[i]
	button.position = spot - size * 0.5
	button.pivot_offset = size * 0.5
	button.disabled = _busy
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
		_place_kitten(spot)
		# Tweens belong to the node they move, so they stop when show_world() clears the map.
		var pulse := button.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		pulse.tween_property(button, "scale", Vector2(1.08, 1.08), 0.7)
		pulse.tween_property(button, "scale", Vector2.ONE, 0.7)
		button.grab_focus.call_deferred()

## The kitten stands just above the level she'll play next, hopping now and then (`idle`).
func _place_kitten(spot: Vector2, idle := true) -> AnimatedSprite2D:
	var cat := AnimatedSprite2D.new()
	cat.name = "Kitten"
	cat.sprite_frames = CAT
	cat.play("idle")
	cat.scale = KITTEN_SCALE
	cat.offset = Vector2(0, -131)
	cat.position = spot + KITTEN_LIFT
	CatSkins.apply(cat)
	map.add_child(cat)
	if not idle:
		return cat
	var hop := cat.create_tween().set_loops()
	hop.tween_interval(2.0)
	hop.tween_property(cat, "position:y", cat.position.y - 26, 0.18).set_ease(Tween.EASE_OUT)
	hop.tween_property(cat, "position:y", cat.position.y, 0.22).set_ease(Tween.EASE_IN)
	return cat

## The girl waits at the end of the path: where the kitten's journey leads.
func _place_girl(spot: Vector2) -> void:
	var girl := Sprite2D.new()
	girl.name = "Girl"
	girl.texture = GIRL
	girl.scale = Vector2(0.2, 0.2)
	girl.offset = Vector2(0, -GIRL.get_height() * 0.5 + 10)   # her shoe on the spot
	girl.position = spot
	map.add_child(girl)
	map.move_child(girl, 1)   # behind the level buttons
	var breathe := girl.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	breathe.tween_property(girl, "scale:y", 0.204, 1.3)
	breathe.tween_property(girl, "scale:y", 0.2, 1.3)

func _play(level_id: String) -> void:
	for b in _buttons:
		b.disabled = true   # one tap is enough
	last_played = level_id
	GameState.start_level(level_id)

## A locked level shakes "no".
func _wobble(button: TextureButton) -> void:
	var t := create_tween()
	for x in [-10.0, 10.0, -6.0, 0.0]:
		t.tween_property(button, "rotation_degrees", x, 0.06)

## Android Back: answers the "World unlocked" card if it's open, otherwise to the home page.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not (menu and menu.go_back()):
		_go_home()

func _go_home() -> void:
	SceneTransition.change_scene("res://ui/screens/main_menu.tscn")
