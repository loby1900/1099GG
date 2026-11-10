extends Control
## Shows the top-3 saved times for every map, including the new Night
## Circuit (Map3) added alongside Forest (Map1) and Desert (Map2).

const COLUMN_PATHS := {
	"Map1": "MarginContainer/HBoxContainer/VBoxContainer",
	"Map2": "MarginContainer/HBoxContainer/VBoxContainer2",
	"Map3": "MarginContainer/HBoxContainer/VBoxContainer3",
}
const COLUMN_TITLES := {
	"Map1": "Forest",
	"Map2": "Desert",
	"Map3": "Night Circuit",
}


func _ready():
	update_best_lap_display()


func _on_back_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu3D.tscn")


func update_best_lap_display() -> void:
	for map_id in COLUMN_PATHS:
		var column = get_node_or_null(COLUMN_PATHS[map_id])
		if column == null:
			continue
		var best_times = BestLapManager.get_best_times(map_id)
		column.get_node("Inner/Map").text = COLUMN_TITLES[map_id]
		column.get_node("Inner/Map1_").text = "1st: %.2f" % best_times[0]
		column.get_node("Inner/Map2_").text = "2nd: %.2f" % best_times[1]
		column.get_node("Inner/Map3_").text = "3rd: %.2f" % best_times[2]


func _on_clear_pressed():
	BestLapManager.clear_best_times()
	update_best_lap_display()
