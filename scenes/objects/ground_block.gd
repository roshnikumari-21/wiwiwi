@tool
class_name GroundBlock
extends StaticBody2D
## A piece of ground. Set Size in the Inspector; the collision and the art follow.
## Origin = top-left corner of the walkable surface, so blocks snap neatly to a grid.
## Each side looks at the blocks next to it: a flush neighbour at the same height or higher hides
## that side (the ground continues); a lower neighbour gets an end cap and a side outline that
## stops where the lower ground begins. One-way blocks use the thin floating-platform art.
## Theme picks the art kit: "meadow" (World 1), "town" (World 2, cobbles + bricks) or "forest"
## (World 3, moss + earth), "snow" (World 4) or "ice" (World 4's slippery ground).

const MEADOW := "res://assets/art/tiles/meadow/"
const TOWN := "res://assets/art/tiles/town/"
const FOREST := "res://assets/art/tiles/forest/"
const SNOW := "res://assets/art/tiles/snow/"
# Each kit's pieces and where the walkable line sits in them (printed by make_ground.py / make_town.py).
const KITS := {
	"meadow": {
		"top": preload(MEADOW + "ground_top.png"), "fill": preload(MEADOW + "ground_fill.png"),
		"cap_left": preload(MEADOW + "ground_cap_left.png"), "cap_right": preload(MEADOW + "ground_cap_right.png"),
		"thin_left": preload(MEADOW + "thin_left.png"), "thin_mid": preload(MEADOW + "thin_mid.png"),
		"thin_right": preload(MEADOW + "thin_right.png"),
		"decos": [
			preload(MEADOW + "deco_flower_white.png"), preload(MEADOW + "deco_flower_pink.png"),
			preload(MEADOW + "deco_flower_yellow.png"), preload(MEADOW + "deco_tuft_big.png"),
			preload(MEADOW + "deco_tuft_small.png"), preload(MEADOW + "deco_rock.png"),
		],
		"top_surface": 59, "cap_surface": 52,
		"cap_inset_left": 32, "cap_inset_right": 40,   # the cap's grass hangs this far past the dirt side
		"thin_side_surface": 37, "thin_mid_surface": 24,
		"fill_from": 120,   # the fill starts this far down; the top tile fades into it
		"deco_gap": Vector2(300, 560), "deco_sink": 10,
	},
	"town": {
		"top": preload(TOWN + "ground_top.png"), "fill": preload(TOWN + "ground_fill.png"),
		"cap_left": preload(TOWN + "ground_cap_left.png"), "cap_right": preload(TOWN + "ground_cap_right.png"),
		"thin_left": preload(TOWN + "thin_left.png"), "thin_mid": preload(TOWN + "thin_mid.png"),
		"thin_right": preload(TOWN + "thin_right.png"),
		# No crates or barrel here: they look solid, so they're kept for real steps in the levels.
		"decos": [
			preload(TOWN + "deco_lamp.png"), preload(TOWN + "deco_planter.png"), preload(TOWN + "deco_bench.png"),
			preload(TOWN + "deco_pot.png"), preload(TOWN + "deco_bush.png"), preload(TOWN + "deco_post.png"),
		],
		"top_surface": 54, "cap_surface": 2,
		"cap_inset_left": 6, "cap_inset_right": 8,
		"thin_side_surface": 1, "thin_mid_surface": 0,
		"fill_from": 60,
		"deco_gap": Vector2(420, 820), "deco_sink": 4,   # bigger props, so fewer of them
	},
	"forest": {
		"top": preload(FOREST + "ground_top.png"), "fill": preload(FOREST + "ground_fill.png"),
		"cap_left": preload(FOREST + "ground_cap_left.png"), "cap_right": preload(FOREST + "ground_cap_right.png"),
		"thin_left": preload(FOREST + "thin_left.png"), "thin_mid": preload(FOREST + "thin_mid.png"),
		"thin_right": preload(FOREST + "thin_right.png"),
		# The signpost isn't scattered (it points the way at level starts).
		"decos": [
			preload(FOREST + "deco_fern.png"), preload(FOREST + "deco_flowers.png"), preload(FOREST + "deco_mushrooms.png"),
			preload(FOREST + "deco_rock.png"), preload(FOREST + "deco_berries.png"), preload(FOREST + "deco_dandelion.png"),
			preload(FOREST + "deco_leaves.png"),
		],
		"top_surface": 57, "cap_surface": 20,
		"cap_inset_left": 17, "cap_inset_right": 23,
		"thin_side_surface": 3, "thin_mid_surface": 3,
		"fill_from": 45,
		"deco_gap": Vector2(300, 600), "deco_sink": 6,
	},
	"snow": {
		"top": preload(SNOW + "ground_top.png"), "fill": preload(SNOW + "ground_fill.png"),
		"cap_left": preload(SNOW + "ground_cap_left.png"), "cap_right": preload(SNOW + "ground_cap_right.png"),
		"thin_left": preload(SNOW + "thin_left.png"), "thin_mid": preload(SNOW + "thin_mid.png"),
		"thin_right": preload(SNOW + "thin_right.png"),
		# Icicles hang under ledges and the signpost points the way (both placed by the level builder).
		"decos": [
			preload(SNOW + "deco_snowman.png"), preload(SNOW + "deco_sapling.png"), preload(SNOW + "deco_rock.png"),
			preload(SNOW + "deco_lantern.png"), preload(SNOW + "deco_berries.png"), preload(SNOW + "deco_snowballs.png"),
		],
		"top_surface": 62, "cap_surface": 9,
		"cap_inset_left": 17, "cap_inset_right": 26,
		"thin_side_surface": 5, "thin_mid_surface": 5,
		"fill_from": 44,
		"deco_gap": Vector2(380, 760), "deco_sink": 6,
	},
	"ice": {   # World 4's slippery ground: glossy ice, snow caps at its ends, no decorations
		"top": preload(SNOW + "ice_top.png"), "fill": preload(SNOW + "ice_fill.png"),
		"cap_left": preload(SNOW + "ground_cap_left.png"), "cap_right": preload(SNOW + "ground_cap_right.png"),
		"thin_left": preload(SNOW + "thin_left.png"), "thin_mid": preload(SNOW + "thin_mid.png"),
		"thin_right": preload(SNOW + "thin_right.png"),
		"decos": [],
		"top_surface": 84, "cap_surface": 9,
		"cap_inset_left": 17, "cap_inset_right": 26,
		"thin_side_surface": 5, "thin_mid_surface": 5,
		"fill_from": 22,
		"deco_gap": Vector2(300, 600), "deco_sink": 0,
	},
}
const OUTLINE_FROM := 40
const OUTLINE_WIDTH := 6.0
const OUTLINE_COLOR := Color(0.33, 0.2, 0.12)

@export var size: Vector2 = Vector2(512, 128):
	set(value):
		size = value
		_rebuild()
@export var one_way: bool = false:   ## you can jump up through it and land on top
	set(value):
		one_way = value
		_rebuild()
@export var decorate: bool = true:   ## scatter decorations on top (flowers / street props)
	set(value):
		decorate = value
		_rebuild()
@export_enum("meadow", "town", "forest", "snow", "ice") var theme: String = "meadow":
	set(value):
		theme = value
		_rebuild()

var _kit: Dictionary

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	_kit = KITS[theme]
	var shape_node: CollisionShape2D = get_node_or_null("Shape")
	if shape_node == null:
		return
	var rect := RectangleShape2D.new()
	rect.size = size
	shape_node.shape = rect
	shape_node.position = size / 2.0
	shape_node.one_way_collision = one_way

	var old := get_node_or_null("Art")
	if old:
		remove_child(old)
		old.queue_free()
	var art := Node2D.new()
	art.name = "Art"
	add_child(art)
	move_child(art, 0)
	if one_way:
		_build_thin(art)
	else:
		_build_ground(art)

func _build_ground(art: Node2D) -> void:
	var top: Texture2D = _kit.top
	var top_surface: float = _kit.top_surface
	_tiled(art, _kit.fill, Vector2(0, _kit.fill_from), Vector2(size.x, size.y - _kit.fill_from))
	_tiled(art, top, Vector2(0, -top_surface), Vector2(size.x, minf(top.get_height(), size.y + top_surface)))
	var half := size.x * 0.5
	for side in [-1, 1]:
		var below := _open_depth(side)   # how much of this side is open to the air (0 = covered)
		if below <= 0.0:
			continue
		var x := 0.0 if side < 0 else size.x - OUTLINE_WIDTH
		var line := ColorRect.new()
		line.color = OUTLINE_COLOR
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.position = Vector2(x, OUTLINE_FROM)
		line.size = Vector2(OUTLINE_WIDTH, maxf(below - OUTLINE_FROM, 0.0))
		art.add_child(line)
		# End cap, cropped to half the block on narrow pieces (walls, small steps).
		var cap := Sprite2D.new()
		cap.centered = false
		cap.region_enabled = true
		var tex: Texture2D = _kit.cap_left if side < 0 else _kit.cap_right
		var inset: float = _kit.cap_inset_left if side < 0 else _kit.cap_inset_right
		var w := minf(tex.get_width(), half + inset)
		cap.texture = tex
		if side < 0:
			cap.region_rect = Rect2(0, 0, w, tex.get_height())
			cap.position = Vector2(-inset, -_kit.cap_surface)
		else:
			cap.region_rect = Rect2(tex.get_width() - w, 0, w, tex.get_height())
			cap.position = Vector2(size.x + inset - w, -_kit.cap_surface)
		art.add_child(cap)
	if decorate:
		_scatter_decorations(art)

func _build_thin(art: Node2D) -> void:
	var thin_left: Texture2D = _kit.thin_left
	var thin_mid: Texture2D = _kit.thin_mid
	var half := minf(thin_left.get_width(), size.x * 0.5)
	if size.x > half * 2.0:
		_tiled(art, thin_mid, Vector2(half, -_kit.thin_mid_surface), Vector2(size.x - half * 2.0, thin_mid.get_height()))
	for side in [-1, 1]:
		var piece := Sprite2D.new()
		piece.centered = false
		piece.region_enabled = true
		piece.texture = _kit.thin_left if side < 0 else _kit.thin_right
		var tw := float(piece.texture.get_width())
		piece.region_rect = Rect2(0 if side < 0 else tw - half, 0, half, piece.texture.get_height())
		piece.position = Vector2(0 if side < 0 else size.x - half, -_kit.thin_side_surface)
		art.add_child(piece)

## How far down this side is exposed: full height with no neighbour, down to a lower neighbour's
## surface (plus a little, so the outline tucks behind its grass), or 0 if a neighbour covers it.
func _open_depth(side: int) -> float:
	var edge := global_position.x + (size.x if side > 0 else 0.0)
	var top := global_position.y
	var depth := size.y
	if get_parent() == null:
		return depth
	for other in get_parent().get_children():
		if other == self or not other is GroundBlock or other.one_way:
			continue
		var b := other as GroundBlock
		var b_edge := b.global_position.x + (0.0 if side > 0 else b.size.x)
		var overlaps := b.global_position.y < top + size.y and b.global_position.y + b.size.y > top
		if absf(b_edge - edge) > 2.0 or not overlaps:
			continue
		if b.global_position.y <= top + 2.0:
			return 0.0
		depth = minf(depth, b.global_position.y - top + OUTLINE_FROM)
	return depth

## Decorations along the top; the same block always gets the same pattern.
func _scatter_decorations(art: Node2D) -> void:
	if size.x < 320.0 or (_kit.decos as Array).is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(global_position))
	var x := rng.randf_range(140.0, 260.0)
	var decos: Array = _kit.decos
	var gap: Vector2 = _kit.deco_gap
	while x < size.x - 140.0:
		var deco := Sprite2D.new()
		deco.texture = decos[rng.randi() % decos.size()]
		deco.offset = Vector2(0, -deco.texture.get_height() * 0.5)
		deco.position = Vector2(x, _kit.deco_sink)
		deco.flip_h = rng.randf() < 0.5
		art.add_child(deco)
		x += rng.randf_range(gap.x, gap.y)

func _tiled(art: Node2D, texture: Texture2D, at: Vector2, area: Vector2) -> void:
	if area.x <= 0.0 or area.y <= 0.0:
		return
	var tile := TextureRect.new()
	tile.texture = texture
	tile.stretch_mode = TextureRect.STRETCH_TILE
	tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # otherwise it can't be narrower than the texture
	tile.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.position = at
	tile.size = area
	art.add_child(tile)
