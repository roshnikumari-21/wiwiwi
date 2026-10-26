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
# How long the sad meow plays before the level restarts (it fades out at the end).
@export var sad_meow_length: float = 1.0

var energy: float
# True once the cat reaches her owner: no more moving or getting tired.
var is_hugging: bool = false
# True while the "ouch" meow plays before the level restarts.
var is_restarting: bool = false

# Remembers if we were on the floor last frame, so we can detect landing.
var was_on_floor: bool = true
var squash_tween: Tween
# Where the cat goes back to after touching a hazard.
var spawn_position: Vector2

func _ready() -> void:
	# Remember wherever the cat was placed in the level as its starting point.
	spawn_position = global_position
	energy = max_energy
	$HappyMeow.play()  # "Hello!" at the start of every level (and after a restart)

# Runs every physics frame (60 times per second).
func _physics_process(delta: float) -> void:
	if is_hugging or is_restarting:
		return  # frozen: no controls, gravity or energy drain

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

	# Fell into a pit (far below the screen)? Back to the start.
	if global_position.y > 900:
		die()
		return

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

# Called by the owner at the finish: leap into her arms.
func start_hug(hug_spot: Vector2) -> void:
	is_hugging = true
	velocity = Vector2.ZERO
	$Sprite2D.flip_h = hug_spot.x < global_position.x  # face the owner
	squash(Vector2(0.8, 1.2))
	$HappyMeow.play()
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", hug_spot, 0.35)

# Called by a milk bowl. min() stops energy going above the maximum.
func drink_milk(amount: float) -> void:
	energy = min(energy + amount, max_energy)
	energy_changed.emit(energy, max_energy)
	squash(Vector2(1.15, 0.85))  # a happy little wiggle

# Called by spikes: "meow!", then the whole level starts fresh (coins, energy, everything).
func hit_spikes() -> void:
	if is_restarting or is_hugging:
		return  # already restarting; ignore extra spike touches
	is_restarting = true
	velocity = Vector2.ZERO
	squash(Vector2(1.3, 0.7))
	$Sprite2D.modulate = Color(1, 0.55, 0.55)  # flash red: ouch!
	$SadMeow.play()
	# Fade the meow out during its last 0.25 s, so cutting it short sounds smooth.
	var fade := create_tween()
	fade.tween_interval(max(sad_meow_length - 0.25, 0.0))
	fade.tween_property($SadMeow, "volume_db", -40.0, 0.25)
	await fade.finished
	get_tree().reload_current_scene()

# Called by enemies, pits, or running out of energy. Sends the cat back to the start, rested.
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
