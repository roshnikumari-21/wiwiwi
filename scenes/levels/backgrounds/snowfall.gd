extends CPUParticles2D
## Gentle snowfall across the whole screen (World 4). Lives in a CanvasLayer between the background
## and the level, so flakes drift in front of the mountains and trees but behind the cat and ground.
## `heavy` makes more, faster flakes (e.g. the last levels, under the aurora).

@export var heavy: bool = false

func _ready() -> void:
	var flake := GradientTexture2D.new()   # a soft white dot
	flake.width = 16
	flake.height = 16
	flake.fill = GradientTexture2D.FILL_RADIAL
	flake.fill_from = Vector2(0.5, 0.5)
	flake.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	flake.gradient = g
	texture = flake
	amount = 180 if heavy else 90
	lifetime = 14.0
	preprocess = 14.0   # already snowing when the level appears
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	direction = Vector2(-0.25, 1.0)
	spread = 18.0
	gravity = Vector2(0, 8)
	initial_velocity_min = 50.0 if not heavy else 90.0
	initial_velocity_max = 110.0 if not heavy else 170.0
	scale_amount_min = 0.35
	scale_amount_max = 1.0
	color = Color(1, 1, 1, 0.85)
	get_viewport().size_changed.connect(_fit)
	_fit()

## Cover the screen (wide phones and tablets too): emit from a strip a little above its top.
func _fit() -> void:
	var screen := get_viewport().get_visible_rect().size
	position = Vector2(screen.x * 0.5, -40.0)
	emission_rect_extents = Vector2(screen.x * 0.7, 20.0)
