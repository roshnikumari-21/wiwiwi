extends Area2D

# How much energy one bowl gives back.
@export var refill_amount: float = 50.0

var has_milk: bool = true

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or not has_milk:
		return
	# Not thirsty yet (90% or more)? Leave the milk for later.
	# (Energy drains every frame, so it's almost never exactly full.)
	if body.energy >= body.max_energy * 0.9:
		return
	body.drink_milk(refill_amount)
	has_milk = false
	$Milk.hide()
	$RefillTimer.start()  # the bowl fills up again when the timer runs out

# Called by the RefillTimer's "timeout" signal.
func _on_refill_timer_timeout() -> void:
	has_milk = true
	$Milk.show()
