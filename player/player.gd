extends CharacterBody2D

# Tells the UI the new energy level. Signals can carry values, like function arguments.
signal energy_changed(current: float, maximum: float)

# How fast the cat runs sideways (pixels per second).
@export var speed: float = 220.0
# Upward push when jumping. Negative because in Godot, up is -Y.
@export var jump_velocity: float = -500.0
# Energy: full is max_energy; it drains by energy_drain every second.
@export var max_energy: float = 100.0
@export var energy_drain: float = 2.0

var energy: float

# Remembers if we were on the floor last frame, so we can detect landing.
var was_on_floor: bool = true
var squash_tween: Tween
# Where the cat goes back to after touching a hazard.
var spawn_position: Vector2

func _ready() -> void:
	# Remember wherever the cat was placed in the level as its starting point.
	spawn_position = global_position
	energy = max_energy

# Runs every physics frame (60 times per second).
func _physics_process(delta: float) -> void:
	# Energy slowly runs out. At zero, the cat is too sleepy and naps (respawns).
	energy -= energy_drain * delta
	energy_changed.emit(energy, max_energy)
	if energy <= 0:
		die()
		return

	# Gravity: while in the air, keep pulling the cat down a little more each frame.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump only when standing on something, so you can't jump in mid-air.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		squash(Vector2(0.8, 1.2))  # stretch tall and thin on take-off

	# get_axis gives -1 (left), 0 (nothing), or 1 (right).
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * speed

	# Face the way we're running.
	if direction != 0:
		$Sprite2D.flip_h = direction < 0

	# Move using velocity, sliding along floors and walls instead of passing through.
	move_and_slide()

	# Just landed? (on the floor now, but not last frame)
	if is_on_floor() and not was_on_floor:
		squash(Vector2(1.2, 0.8))  # squish short and wide on landing
	was_on_floor = is_on_floor()

# Quickly change the sprite's shape, then bounce back to normal.
func squash(target_scale: Vector2) -> void:
	if squash_tween:
		squash_tween.kill()  # stop any squash already playing
	squash_tween = create_tween()
	squash_tween.tween_property($Sprite2D, "scale", target_scale, 0.08)
	squash_tween.tween_property($Sprite2D, "scale", Vector2.ONE, 0.15)

# Called by an enemy we stomped: a small hop upward.
func bounce() -> void:
	velocity.y = jump_velocity * 0.7
	squash(Vector2(0.8, 1.2))

# Called by a milk bowl. min() stops energy going above the maximum.
func drink_milk(amount: float) -> void:
	energy = min(energy + amount, max_energy)
	energy_changed.emit(energy, max_energy)
	squash(Vector2(1.15, 0.85))  # a happy little wiggle

# Called by hazards, enemies, or running out of energy. Sends the cat back to the start, rested.
func die() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	energy = max_energy
	energy_changed.emit(energy, max_energy)
	$Camera2D.reset_smoothing()  # jump the camera straight there instead of sliding across the level
	# Blink 3 times so it's clear something happened.
	var blink := create_tween().set_loops(3)
	blink.tween_property($Sprite2D, "modulate:a", 0.2, 0.08)
	blink.tween_property($Sprite2D, "modulate:a", 1.0, 0.08)
