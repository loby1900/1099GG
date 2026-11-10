extends Control
## Map picker. Records the chosen map scene path on GameData and moves on
## to the car picker; the actual scene is only loaded once a car has been
## chosen too (see SelectCar.gd).

func _choose(map_path: String) -> void:
	GameData.selected_map = map_path
	get_tree().change_scene_to_file("res://Scenes/select_car.tscn")


func _on_forest_pressed():
	_choose("res://Scenes/world.tscn")


func _on_desert_pressed():
	_choose("res://Scenes/world_2.tscn")


func _on_freeroam_pressed():
	_choose("res://Scenes/world_3.tscn")


func _on_night_circuit_pressed():
	_choose("res://Scenes/world_4.tscn")


func _on_back_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu3D.tscn")
