extends CanvasLayer
## Layered background that follows the camera: far layers move slowly, near ones faster, for depth.
## Each layer is a TextureRect child whose texture repeats sideways. Its placement is set for the
## "reference" camera height (cat standing on normal ground) and nudged as the camera moves up/down.

## Camera centre height (world y) the layer placements below were set for.
@export var reference_camera_y: float = 740.0

## Per layer (child name): [sideways speed, up/down speed, top y on screen at the reference height].
@export var layers := {
	"Far": [0.1, 0.05, -140.0],
	"Mid": [0.3, 0.15, 210.0],
	"Near": [0.55, 0.4, 600.0],
}

func _ready() -> void:
	layer = -10
	for child in get_children():
		if child is TextureRect:
			child.stretch_mode = TextureRect.STRETCH_TILE
			child.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			child.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var centre := camera.get_screen_center_position()
	var screen := get_viewport().get_visible_rect().size
	$Sky.size = screen
	for layer_name in layers:
		var rect: TextureRect = get_node(String(layer_name))
		var speed: Array = layers[layer_name]
		var tile_w := float(rect.texture.get_width())
		rect.size = Vector2(screen.x + tile_w, rect.texture.get_height())
		rect.position = Vector2(
			-fposmod(centre.x * speed[0], tile_w),
			speed[2] - (centre.y - reference_camera_y) * speed[1])
