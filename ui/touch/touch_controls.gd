extends Control

# Tick this in the Inspector to see (and click) the buttons on your PC while testing.
@export var show_on_desktop: bool = false

func _ready() -> void:
	# Show the buttons on phones and tablets (Android/iOS), or when testing on PC.
	# (Not "is there a touchscreen?": mouse-to-touch emulation makes every PC say yes.)
	visible = show_on_desktop or OS.has_feature("mobile")
