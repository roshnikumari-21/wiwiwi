extends CPUParticles2D
## World 5's sandstorm (level 5-9): streaks of golden sand blowing sideways across the whole screen.
## Lives in a CanvasLayer in front of the background and behind the cat and ground (like the snowfall),
## plus a few faster, fainter gusts in front of everything (see Level._sandstorm).

@export var gust: bool = false   ## the faint fast streaks drawn over the level

func _ready() -> void:
	var grain := GradientTexture2D.new()   # a soft streak, longer than tall
	grain.width = 40
	grain.height = 8
	grain.fill = GradientTexture2D.FILL_RADIAL
	grain.fill_from = Vector2(0.5, 0.5)
	grain.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	grain.gradient = g
	texture = grain
	amount = 90 if gust else 300
	lifetime = 2.2 if gust else 4.0
	preprocess = lifetime   # already blowing when the level appears
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	direction = Vector2(-1.0, 0.12)
	spread = 6.0
	gravity = Vector2(0, 10)
	initial_velocity_min = 900.0 if gust else 420.0
	initial_velocity_max = 1300.0 if gust else 700.0
	scale_amount_min = 1.0
	scale_amount_max = 2.6 if gust else 2.2
	color = Color(1.0, 0.9, 0.66, 0.45 if gust else 0.9)
	get_viewport().size_changed.connect(_fit)
	_fit()

## Blow in from a strip just past the right edge of the screen, the whole height.
func _fit() -> void:
	var screen := get_viewport().get_visible_rect().size
	position = Vector2(screen.x + 40.0, screen.y * 0.5)
	emission_rect_extents = Vector2(20.0, screen.y * 0.6)
