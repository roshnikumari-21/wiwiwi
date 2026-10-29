extends Node
## Which level is being played, and the level catalog. The running attempt (hearts, coins…) is added next.

const CATALOG_PATH := "res://data/levels/level_catalog.tres"

var catalog: LevelCatalog = preload(CATALOG_PATH)
var current_level_id: String = ""

func current_level() -> LevelData:
	return catalog.get_level(current_level_id)

## Load a level by id with a fade (e.g. from the level map or "Next level").
func start_level(level_id: String) -> void:
	var level := catalog.get_level(level_id)
	if level == null:
		push_error("Unknown level id: %s" % level_id)
		return
	SceneTransition.change_scene(level.scene_path)
