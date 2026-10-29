extends Area2D
## A bowl of milk: refills the cat's energy. She only drinks when she isn't already (nearly) full,
## so walking past at full energy saves the bowl for later. Origin = bottom of the bowl.

const EMPTY := preload("res://assets/art/objects/milk_bowl_empty.png")
const THIRSTY_BELOW := 0.95   ## drinks only when energy is below this

var _empty := false

func _physics_process(_delta: float) -> void:
	if _empty:
		return
	for body in get_overlapping_bodies():
		if body is Player and body.energy < THIRSTY_BELOW:
			_drink(body)
			return

func _drink(cat: Player) -> void:
	_empty = true
	cat.refill_energy()
	Events.milk_drunk.emit()
	$Sprite.texture = EMPTY
	var base: Vector2 = $Sprite.scale
	var pop := create_tween()
	pop.tween_property($Sprite, "scale", base * Vector2(1.15, 0.85), 0.08)
	pop.tween_property($Sprite, "scale", base, 0.25).set_trans(Tween.TRANS_BACK)
