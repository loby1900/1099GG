extends CanvasLayer

var paused = false  # This variable will keep track of the pause state.


func _ready():
	# Set the node to process even when the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	hide()  # Initially hide the pause menu


func _process(_delta):
	if Input.is_action_just_pressed("pause"):
		toggle_pause()


func toggle_pause() -> void:
	paused = !paused
	get_tree().paused = paused
	visible = paused


func _on_continue_pressed():
	paused = false
	get_tree().paused = false
	hide()


func _on_quit_pressed():
	get_tree().paused = false  # Unpause before changing the scene
	LoadingScreen.load_scene("res://Scenes/MainMenu3D.tscn")
