extends Area2D

# Same idea as the coin: Godot calls this when a body enters the spikes.
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# We know exactly who to talk to, so we call the cat's function directly.
		# Spikes are serious: sad meow, then the whole level starts over.
		body.hit_spikes()
