@tool
class_name GroundBlock
extends StaticBody2D
## A piece of meadow ground. Set Size in the Inspector; the collision and the art follow.
## Origin = top-left corner of the walkable surface, so blocks snap neatly to a grid.
## Each side looks at the blocks next to it: a flush neighbour at the same height or higher hides
## that side (the ground continues); a lower neighbour gets a grass corner and a side outline that
## stops where the lower ground begins. One-way blocks use the thin floating-platform art.

const KIT := "res://assets/art/tiles/meadow/"
const TOP := preload(KIT + "ground_top.png")
const FILL := preload(KIT + "ground_fill.png")
const CAP_LEFT := preload(KIT + "ground_cap_left.png")
const CAP_RIGHT := preload(KIT + "ground_cap_right.png")
const THIN_LEFT := preload(KIT + "thin_left.png")
const THIN_MID := preload(KIT + "thin_mid.png")
const THIN_RIGHT := preload(KIT + "thin_right.png")
const DECOS: Array[Texture2D] = [
	preload(KIT + "deco_flower_white.png"), preload(KIT + "deco_flower_pink.png"),
	preload(KIT + "deco_flower_yellow.png"), preload(KIT + "deco_tuft_big.png"),
	preload(KIT + "deco_tuft_small.png"), preload(KIT + "deco_rock.png"),
]

# Where the walkable grass line sits in each piece (printed by tools/art_pipeline/make_ground.py).
const TOP_SURFACE := 59
const CAP_SURFACE := 52
const CAP_INSET_LEFT := 32    # the cap's grass hangs this far past the dirt side
const CAP_INSET_RIGHT := 40
const THIN_SIDE_SURFACE := 37
const THIN_MID_SURFACE := 24
const FILL_FROM := 120        # the dirt fill starts this far down; the top tile fades into it
const OUTLINE_FROM := 40
const OUTLINE_WIDTH := 6.0
const OUTLINE_COLOR := Color(0.33, 0.2, 0.12)
const DECO_GAP := Vector2(300, 560)   ## random spacing between decorations

@export var size: Vector2 = Vector2(512, 128):
	set(value):
		size = value
		_rebuild()
@export var one_way: bool = false:   ## you can jump up through it and land on top
	set(value):
		one_way = value
		_rebuild()
@export var decorate: bool = true:   ## scatter flowers and tufts on top
	set(value):
		decorate = value
		_rebuild()

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
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
	_tiled(art, FILL, Vector2(0, FILL_FROM), Vector2(size.x, size.y - FILL_FROM))
	_tiled(art, TOP, Vector2(0, -TOP_SURFACE), Vector2(size.x, minf(TOP.get_height(), size.y + TOP_SURFACE)))
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
		# Grass corner, cropped to half the block on narrow pieces (walls, small steps).
		var cap := Sprite2D.new()
		cap.centered = false
		cap.region_enabled = true
		var tex: Texture2D = CAP_LEFT if side < 0 else CAP_RIGHT
		var inset: float = CAP_INSET_LEFT if side < 0 else CAP_INSET_RIGHT
		var w := minf(tex.get_width(), half + inset)
		cap.texture = tex
		if side < 0:
			cap.region_rect = Rect2(0, 0, w, tex.get_height())
			cap.position = Vector2(-inset, -CAP_SURFACE)
		else:
			cap.region_rect = Rect2(tex.get_width() - w, 0, w, tex.get_height())
			cap.position = Vector2(size.x + inset - w, -CAP_SURFACE)
		art.add_child(cap)
	if decorate:
		_scatter_decorations(art)

func _build_thin(art: Node2D) -> void:
	var half := minf(THIN_LEFT.get_width(), size.x * 0.5)
	if size.x > half * 2.0:
		_tiled(art, THIN_MID, Vector2(half, -THIN_MID_SURFACE), Vector2(size.x - half * 2.0, THIN_MID.get_height()))
	for side in [-1, 1]:
		var piece := Sprite2D.new()
		piece.centered = false
		piece.region_enabled = true
		piece.texture = THIN_LEFT if side < 0 else THIN_RIGHT
		var tw := float(piece.texture.get_width())
		piece.region_rect = Rect2(0 if side < 0 else tw - half, 0, half, piece.texture.get_height())
		piece.position = Vector2(0 if side < 0 else size.x - half, -THIN_SIDE_SURFACE)
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

## Flowers, tufts and a rock along the top; the same block always gets the same pattern.
func _scatter_decorations(art: Node2D) -> void:
	if size.x < 320.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(global_position))
	var x := rng.randf_range(140.0, 260.0)
	while x < size.x - 140.0:
		var deco := Sprite2D.new()
		deco.texture = DECOS[rng.randi() % DECOS.size()]
		deco.offset = Vector2(0, -deco.texture.get_height() * 0.5)
		deco.position = Vector2(x, 10)
		deco.flip_h = rng.randf() < 0.5
		art.add_child(deco)
		x += rng.randf_range(DECO_GAP.x, DECO_GAP.y)

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
