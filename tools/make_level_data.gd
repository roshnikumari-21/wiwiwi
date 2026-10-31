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
