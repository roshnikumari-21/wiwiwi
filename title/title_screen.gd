extends Control

const FIRST_LEVEL := "res://level_1.tscn"

func _ready() -> void:
	# Focus the Start button so pressing Enter or Space starts the game.
	$Menu/StartButton.grab_focus()

	# On phones: apps don't have a Quit button, and there's no keyboard.
	if OS.has_feature("mobile"):
		$Menu/QuitButton.hide()
		$Menu/Hint.text = "Tap the arrows to move and the paw to jump"

	# The cat gently bobs up and down while you wait.
	var cat: TextureRect = $Menu/Pictures/CatHolder/CatPic
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tween.tween_property(cat, "position:y", -8.0, 0.7)
	tween.tween_property(cat, "position:y", 0.0, 0.7)

# Connected to the StartButton's "pressed" signal.
func _on_start_button_pressed() -> void:
	# Swap the whole screen for Level 1.
	get_tree().change_scene_to_file(FIRST_LEVEL)

# Connected to the QuitButton's "pressed" signal.
func _on_quit_button_pressed() -> void:
	get_tree().quit()
