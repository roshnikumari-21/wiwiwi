extends Area2D

# Our own custom signal: "I just got picked up!"
# Other nodes (like the score label in step 4) can listen for it.
signal collected

func _ready() -> void:
	# Make the coin gently bob up and down forever.
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tween.tween_property($Sprite2D, "position:y", -4.0, 0.6)
	tween.tween_property($Sprite2D, "position:y", 4.0, 0.6)

# Connected to Area2D's built-in "body_entered" signal (see the Node tab).
# Godot calls this whenever a physics body walks into the coin.
func _on_body_entered(body: Node2D) -> void:
	# Only the cat can collect coins, not platforms or other things.
	if body.is_in_group("player"):
		collected.emit()
		# Hide the coin and stop it detecting, but keep it alive so the sound can finish.
		hide()
		set_deferred("monitoring", false)
		$PickupSound.play()
		await $PickupSound.finished  # pause this function until the sound ends
		queue_free()  # now remove the coin from the game
