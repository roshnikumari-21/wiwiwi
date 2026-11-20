class_name CatSkins
extends RefCounted
## The Cat Shop's cats. v1 = colours of our kitten: her orange patches are repainted by
## cat_recolor.gdshader, so every pose and animation stays exactly as drawn. Ginger is free.
## A new breed with its own drawings could join later with its own SpriteFrames.

const DEFAULT := "ginger"
const SHADER := preload("res://scenes/actors/player/cat_recolor.gdshader")
## Where the kitten sits inside the girl's hug pictures (UV x, y, width, height).
const HUG_REGION := Vector4(0.0, 0.45, 0.42, 0.45)

## Prices doubled and each cat locked behind a world (owners, 20 Nov 2026): "world" = finish that world
## (its level 10) before the cat can be bought. 0 = no lock. Cats already bought stay owned.
const ALL: Array[Dictionary] = [
	{"id": "ginger", "name": "CAT_GINGER", "price": 0, "world": 0, "patch": null},
	{"id": "snowy", "name": "CAT_SNOWY", "price": 300, "world": 1, "patch": Color(0.97, 0.95, 0.9)},
	{"id": "cocoa", "name": "CAT_COCOA", "price": 500, "world": 2, "patch": Color(0.55, 0.36, 0.24)},
	{"id": "misty", "name": "CAT_MISTY", "price": 800, "world": 3, "patch": Color(0.58, 0.6, 0.66)},
	{"id": "tuxedo", "name": "CAT_TUXEDO", "price": 1200, "world": 4, "patch": Color(0.2, 0.19, 0.23)},
	{"id": "bubblegum", "name": "CAT_BUBBLEGUM", "price": 1600, "world": 5, "patch": Color(0.97, 0.62, 0.75)},
]

## True once the world this cat needs is finished (its last level done), or it needs none.
static func world_open(skin: Dictionary) -> bool:
	var world: int = skin.get("world", 0)
	return world == 0 or SaveManager.is_done("w%d_10" % world)

static func find(id: String) -> Dictionary:
	for skin in ALL:
		if skin.id == id:
			return skin
	return ALL[0]

## Paints `item` as cat `id` (default: the player's chosen cat). `region` limits it to part of
## the picture (the hug art). Ginger needs no shader, so the drawings show untouched.
static func apply(item: CanvasItem, id := "", region := Vector4(0.0, 0.0, 1.0, 1.0)) -> void:
	if id == "":
		id = SaveManager.chosen_cat()
	var skin := find(id)
	if skin.patch == null:
		item.material = null
		return
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("patch_color", skin.patch)
	mat.set_shader_parameter("region", region)
	item.material = mat
