extends Node2D

# Announces "the cat made it home!" so the UI can show the finish message.
signal finished

# preload loads the picture once, when the game starts.
const HEART_TEXTURE := preload("res://owner/heart.svg")

var has_finished: bool = false

# The cat walked into the area in front of the girl: that's the finishing point.
func _on_finish_zone_body_entered(body: Node2D) -> void:
	if has_finished or not body.is_in_group("player"):
		return
	has_finished = true

	body.start_hug($HugSpot.global_position)  # the cat leaps into her arms
	$ArmsOpen.hide()
	$ArmsHug.show()                          # these arms are drawn in front of the cat
	$Confetti.emitting = true                # one big burst
	$CheerSound.play()
	spawn_hearts()
	finished.emit()

# Three hearts float up and fade, one after another.
func spawn_hearts() -> void:
	for i in 3:
		var heart := Sprite2D.new()
		heart.texture = HEART_TEXTURE
		heart.position = Vector2(-22 + i * 22, -120)
		heart.modulate.a = 0.0
		add_child(heart)
		var tween := create_tween()
		tween.tween_interval(i * 0.25)  # wait a little before each heart
		tween.tween_property(heart, "modulate:a", 1.0, 0.15)
		tween.tween_property(heart, "position:y", heart.position.y - 70, 1.2)
		tween.parallel().tween_property(heart, "modulate:a", 0.0, 1.2)
		tween.tween_callback(heart.queue_free)
