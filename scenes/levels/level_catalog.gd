class_name LevelCatalog
extends Resource
## Every level, in play order. Add a level here and menus/unlocks pick it up automatically.

@export var levels: Array[LevelData] = []

func get_level(level_id: String) -> LevelData:
	for level in levels:
		if level.id == level_id:
			return level
	return null

func next_after(level_id: String) -> LevelData:
	for i in levels.size() - 1:
		if levels[i].id == level_id:
			return levels[i + 1]
	return null

func in_world(world: int) -> Array[LevelData]:
	var result: Array[LevelData] = []
	for level in levels:
		if level.world == world:
			result.append(level)
	return result
