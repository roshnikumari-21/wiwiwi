class_name ArchedLabel
extends Control
## Text drawn letter by letter along a gentle arch (middle higher than the ends), e.g. to follow the
## curved top of a wooden sign. Fills its parent; the text is centred in it.

@export var text: String = "":
	set(value):
		text = value
		queue_redraw()
@export var font: Font
@export var font_size: int = 52
@export var color: Color = Color(1, 0.95, 0.78)
@export var outline_color: Color = Color(0.36, 0.2, 0.1)
@export var outline_size: int = 16
@export var arch: float = 14.0   ## px the middle letters sit higher than the first and last
@export var lift: float = 0.0    ## move the whole line up (px)
@export var max_width: float = 0.72   ## share of the width the text may use (long text shrinks)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _draw() -> void:
	if text == "" or font == null:
		return
	var parent := get_parent() as Control
	if parent and size != parent.size:   # follow the board (it may be laid out after us)
		size = parent.size
	var shown := tr(text)
	var fs := font_size
	var widths: Array[float] = []
	var total := INF
	while total > size.x * max_width and fs > 20:   # long names get a smaller size so they fit
		widths.clear()
		total = 0.0
		for ch in shown:
			var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			widths.append(w)
			total += w
		if total > size.x * max_width:
			fs -= 2
	var baseline := (size.y + font.get_ascent(fs) - font.get_descent(fs)) * 0.5 - lift
	var x := (size.x - total) * 0.5
	var half := maxf(total * 0.5, 1.0)
	for i in shown.length():
		var mid := x + widths[i] * 0.5
		var t := (mid - size.x * 0.5) / half            # -1 at the left end, 0 middle, 1 right end
		var y := baseline - arch * (1.0 - t * t)        # a parabola: highest in the middle
		var angle := atan(2.0 * arch * t / half)        # tilt each letter along the curve
		draw_set_transform(Vector2(mid, y), angle, Vector2.ONE)
		var at := Vector2(-widths[i] * 0.5, 0)
		draw_string_outline(font, at, shown[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline_size, outline_color)
		draw_string(font, at, shown[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
		x += widths[i]
	draw_set_transform(Vector2.ZERO)
