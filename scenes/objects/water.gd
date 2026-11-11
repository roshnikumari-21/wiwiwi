@tool
extends Area2D
## Water filling a pit. Set Width (the gap between the ground pieces) and Depth in the Inspector.
## Origin = top-left of the water line. The waves drift gently; when the cat falls in she splashes,
## and the level takes a heart (Events.player_fell_in_water).

const SURFACE := preload("res://assets/art/tiles/meadow/water_surface.png")
const BODY := preload("res://assets/art/tiles/meadow/water_body.png")
const BODY_FROM := 40.0        # the underwater part starts just under the strip's waves
const CATCH_FROM := 26.0       # the cat counts as "in" a little below the wave tips
const DRIFT_SPEED := 28.0      # px per second the waves slide sideways
## Per theme: the water's colours (null = the meadow's own blue). See water_tint.gdshader.
const TINTS := {
	"meadow": null,
	"town": [Color(0.30, 0.28, 0.52), Color(0.56, 0.54, 0.80), Color(1.0, 0.82, 0.62)],   # dusky canal at sunset
}
const TINT_SHADER := preload("res://scenes/objects/water_tint.gdshader")

@export var width: float = 300.0:
	set(value):
		width = value
		_rebuild()
@export var depth: float = 500.0:
	set(value):
		depth = value
		_rebuild()
@export_enum("meadow", "town") var theme: String = "meadow":
	set(value):
		theme = value
		_rebuild()

var _surface: TextureRect
var _drift := 0.0

func _ready() -> void:
	z_index = 5   # in front of the cat, so she disappears under the water
	collision_layer = 16
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	_rebuild()

func _process(delta: float) -> void:
	if _surface:
		_drift = fposmod(_drift + DRIFT_SPEED * delta, SURFACE.get_width())
		_surface.position.x = -_drift

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var clip := Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.size = Vector2(width, depth)
	add_child(clip)
	var tint = TINTS[theme]
	if tint != null:
		var mat := ShaderMaterial.new()
		mat.shader = TINT_SHADER
		mat.set_shader_parameter("deep", tint[0])
		mat.set_shader_parameter("light", tint[1])
		mat.set_shader_parameter("glint", tint[2])
		clip.material = mat
	clip.add_child(_tile(BODY, Vector2(0, BODY_FROM), Vector2(width, depth - BODY_FROM)))
	_surface = _tile(SURFACE, Vector2.ZERO, Vector2(width + SURFACE.get_width(), SURFACE.get_height()))
	clip.add_child(_surface)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, depth - CATCH_FROM)
	shape.shape = rect
	shape.position = Vector2(width * 0.5, CATCH_FROM + rect.size.y * 0.5)
	add_child(shape)

func _on_body_entered(body: Node2D) -> void:
	if Engine.is_editor_hint() or not body is Player or body.frozen:
		return
	_splash(body.global_position.x - global_position.x)
	AudioManager.play_sfx("sfx_splash")
	Events.player_fell_in_water.emit()

## Droplets jump up where the cat went in.
func _splash(x: float) -> void:
	var drops := CPUParticles2D.new()
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 24
	tex.height = 24
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	g.set_color(1, Color(0.6, 0.86, 1.0, 0.0))
	tex.gradient = g
	drops.texture = tex
	drops.position = Vector2(x, 8)
	drops.amount = 22
	drops.one_shot = true
	drops.explosiveness = 1.0
	drops.lifetime = 0.8
	drops.direction = Vector2.UP
	drops.spread = 40.0
	drops.initial_velocity_min = 280.0
	drops.initial_velocity_max = 520.0
	drops.gravity = Vector2(0, 1400)
	drops.scale_amount_min = 1.2
	drops.scale_amount_max = 2.2
	drops.z_index = 1
	add_child(drops)
	drops.emitting = true
	get_tree().create_timer(1.2).timeout.connect(drops.queue_free)

func _tile(texture: Texture2D, at: Vector2, area: Vector2) -> TextureRect:
	var tile := TextureRect.new()
	tile.texture = texture
	tile.stretch_mode = TextureRect.STRETCH_TILE
	tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.use_parent_material = true   # picks up the theme's tint from the clip area
	tile.position = at
	tile.size = area
	return tile
