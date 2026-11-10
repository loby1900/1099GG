extends Control
## Car picker. Used to jump straight into one of 24 pre-baked "this car on
## this map" scenes; now it just records the chosen car_type on GameData
## and loads the single map scene the player already picked, which reads
## GameData.selected_car at runtime and configures the shared Car.tscn
## accordingly (see car.gd). Adding a new car now only means adding one
## entry to car.gd's dictionaries - no new scenes.

func _choose(car_type: String) -> void:
	GameData.selected_car = car_type
	if GameData.selected_map != "":
		LoadingScreen.load_scene(GameData.selected_map)
	else:
		# Defensive fallback in case this screen is ever reached directly.
		get_tree().change_scene_to_file("res://Scenes/select_map.tscn")


func _on_porsche_pressed():
	_choose("Porsche")


func _on_dodge_pressed():
	_choose("Dodge")


func _on_supra_pressed():
	_choose("Supra")


func _on_rx7_pressed():
	_choose("RX7")


func _on_mercedes_pressed():
	_choose("Mercedes")


func _on_evo_pressed():
	_choose("EVO")


func _on_nsx_pressed():
	_choose("NSX")


func _on_f1_pressed():
	_choose("F1")


func _on_bmw330i_pressed():
	_choose("BMW330i")


func _on_bmwm4gt3_pressed():
	_choose("BMWM4GT3")


func _on_back_pressed():
	get_tree().change_scene_to_file("res://Scenes/select_map.tscn")
