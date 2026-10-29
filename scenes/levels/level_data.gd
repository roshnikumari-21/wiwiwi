class_name LevelData
extends Resource
## Facts about one level. Menus, unlocks and stars read from these, never from the level scene itself.

@export var id: String = ""            ## e.g. "w1_01"
@export var world: int = 1
@export var index: int = 1             ## position inside its world (1-10)
@export var title_key: String = ""     ## translation key for the level's name
@export_file("*.tscn") var scene_path: String = ""
@export var hint_key: String = ""      ## optional pre-level hint (translation key)
@export var is_reunion: bool = false   ## the world's last level, with the owner hug
