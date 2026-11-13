extends SceneTree
## Writes the level data files + catalog. Run:
##   godot --headless --path . --script tools/make_level_data.gd
## Add a line to LEVELS when a new level scene exists.

const LEVELS := [
	# id, world, index, scene
	["w1_01", 1, 1, "res://scenes/levels/w1/level_w1_01.tscn"],
	["w1_02", 1, 2, "res://scenes/levels/w1/level_w1_02.tscn"],
	["w1_03", 1, 3, "res://scenes/levels/w1/level_w1_03.tscn"],
	["w1_04", 1, 4, "res://scenes/levels/w1/level_w1_04.tscn"],
	["w1_05", 1, 5, "res://scenes/levels/w1/level_w1_05.tscn"],
	["w1_06", 1, 6, "res://scenes/levels/w1/level_w1_06.tscn"],
	["w1_07", 1, 7, "res://scenes/levels/w1/level_w1_07.tscn"],
	["w1_08", 1, 8, "res://scenes/levels/w1/level_w1_08.tscn"],
	["w1_09", 1, 9, "res://scenes/levels/w1/level_w1_09.tscn"],
	["w1_10", 1, 10, "res://scenes/levels/w1/level_w1_10.tscn"],
	# World 2 "Sunset Town" (tools/levels/build_world2.py)
	["w2_01", 2, 1, "res://scenes/levels/w2/level_w2_01.tscn"],
	["w2_02", 2, 2, "res://scenes/levels/w2/level_w2_02.tscn"],
	["w2_03", 2, 3, "res://scenes/levels/w2/level_w2_03.tscn"],
	["w2_04", 2, 4, "res://scenes/levels/w2/level_w2_04.tscn"],
	["w2_05", 2, 5, "res://scenes/levels/w2/level_w2_05.tscn"],
	["w2_06", 2, 6, "res://scenes/levels/w2/level_w2_06.tscn"],
	["w2_07", 2, 7, "res://scenes/levels/w2/level_w2_07.tscn"],
	["w2_08", 2, 8, "res://scenes/levels/w2/level_w2_08.tscn"],
	["w2_09", 2, 9, "res://scenes/levels/w2/level_w2_09.tscn"],
	["w2_10", 2, 10, "res://scenes/levels/w2/level_w2_10.tscn"],
	# World 3 "Whispering Forest" (tools/levels/build_world3.py)
	["w3_01", 3, 1, "res://scenes/levels/w3/level_w3_01.tscn"],
	["w3_02", 3, 2, "res://scenes/levels/w3/level_w3_02.tscn"],
	["w3_03", 3, 3, "res://scenes/levels/w3/level_w3_03.tscn"],
	["w3_04", 3, 4, "res://scenes/levels/w3/level_w3_04.tscn"],
	["w3_05", 3, 5, "res://scenes/levels/w3/level_w3_05.tscn"],
	["w3_06", 3, 6, "res://scenes/levels/w3/level_w3_06.tscn"],
	["w3_07", 3, 7, "res://scenes/levels/w3/level_w3_07.tscn"],
	["w3_08", 3, 8, "res://scenes/levels/w3/level_w3_08.tscn"],
	["w3_09", 3, 9, "res://scenes/levels/w3/level_w3_09.tscn"],
	["w3_10", 3, 10, "res://scenes/levels/w3/level_w3_10.tscn"],
	# World 4 "Frosty Peaks" (tools/levels/build_world4.py) — added one level at a time
	["w4_01", 4, 1, "res://scenes/levels/w4/level_w4_01.tscn"],
	["w4_02", 4, 2, "res://scenes/levels/w4/level_w4_02.tscn"],
	["w4_03", 4, 3, "res://scenes/levels/w4/level_w4_03.tscn"],
]

func _initialize() -> void:
	var catalog := LevelCatalog.new()
	for row in LEVELS:
		var data := LevelData.new()
		data.id = row[0]
		data.world = row[1]
		data.index = row[2]
		data.title_key = "LEVEL_%s_TITLE" % row[0].to_upper()
		data.scene_path = row[3]
		data.is_reunion = row[2] == 10
		var path := "res://data/levels/%s.tres" % row[0]
		ResourceSaver.save(data, path)
		catalog.levels.append(load(path))
	ResourceSaver.save(catalog, "res://data/levels/level_catalog.tres")
	print("catalog written with %d level(s)" % catalog.levels.size())
	quit()
