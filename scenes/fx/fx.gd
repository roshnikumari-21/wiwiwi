class_name Fx
extends AnimatedSprite2D
## Light one-shot effects: a short 5-frame sprite plays once and removes itself.
## Usage: Fx.spawn(self, &"coin", global_position, 0.5)
## Kept deliberately cheap (no particles, glow or shaders), so many can play on low-end phones.

const DIR := "res://assets/art/fx/fx_%s_%d.png"
## effect name: [sheet row, first frame, frames per second]
const EFFECTS := {
	&"dust": ["dust", 0, 16.0],
	&"coin": ["coin", 0, 15.0],        # coin flips and bursts into sparkles
	&"sparkle": ["coin", 2, 12.0],     # sparkles only (milk energy)
	&"stars": ["stars", 0, 13.0],      # checkpoint
	&"heart": ["heart", 0, 11.0],      # hurt
	&"confetti": ["confetti", 0, 9.0], # level complete
}

static var _frames: SpriteFrames

## Play `effect` at a world position; it's added next to `near` (same parent) and frees itself.
static func spawn(near: Node, effect: StringName, at: Vector2, size := 1.0) -> void:
	var host := near.get_parent()
	if host == null:
		return
	var fx := Fx.new()
	fx.sprite_frames = _get_frames()
	fx.scale = Vector2.ONE * size
	fx.z_index = 10
	host.add_child(fx)
	fx.global_position = at
	fx.animation_finished.connect(fx.queue_free)
	fx.play(effect)

static func _get_frames() -> SpriteFrames:
	if _frames:
		return _frames
	_frames = SpriteFrames.new()
	_frames.remove_animation(&"default")
	for effect in EFFECTS:
		var spec: Array = EFFECTS[effect]
		_frames.add_animation(effect)
		_frames.set_animation_loop(effect, false)
		_frames.set_animation_speed(effect, spec[2])
		for i in range(spec[1], 5):
			_frames.add_frame(effect, load(DIR % [spec[0], i]))
	return _frames
