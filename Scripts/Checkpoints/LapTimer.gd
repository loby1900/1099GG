extends Node3D
## Sector/lap timer. One instance per circuit map; replaces the old
## Checkpoint.gd / Checkpoint2.gd pair (identical code duplicated per map,
## differing only in which save-slot they wrote to) with a single script
## parameterized by map_id, so adding a new timed map needs no new script.

@export var map_id: String = "Map1"

var sector_1_time = 0.0
var sector_2_time = 0.0
var sector_3_time = 0.0
var best_lap_time = 9999.0

var sector_1_start_time = 0
var sector_2_start_time = 0
var sector_3_start_time = 0

@onready var lap_time_last_label = $LapTimes/MarginContainer/VBoxContainer/Last
@onready var lap_time_label = $LapTimes/MarginContainer/VBoxContainer/Lap
@onready var sector_1_time_label = $LapTimes/MarginContainer/VBoxContainer/Sector1
@onready var sector_2_time_label = $LapTimes/MarginContainer/VBoxContainer/Sector2
@onready var sector_3_time_label = $LapTimes/MarginContainer/VBoxContainer/Sector3

var race_started = false
var first_pass_finish = true


func _on_checkpoint_sector_1_body_entered(body: Node) -> void:
	if body.name == "Car" and race_started:
		sector_1_time = (Time.get_ticks_msec() - sector_1_start_time) / 1000.0
		sector_1_time_label.text = "Sector 1 Time: %.2f" % sector_1_time
		sector_2_start_time = Time.get_ticks_msec()


func _on_checkpoint_sector_2_body_entered(body: Node) -> void:
	if body.name == "Car" and race_started:
		sector_2_time = (Time.get_ticks_msec() - sector_2_start_time) / 1000.0
		sector_2_time_label.text = "Sector 2 Time: %.2f" % sector_2_time
		sector_3_start_time = Time.get_ticks_msec()


func _on_checkpoint_sector_3_body_entered(body: Node) -> void:
	if body.name != "Car":
		return
	if not first_pass_finish:
		sector_3_time = (Time.get_ticks_msec() - sector_3_start_time) / 1000.0
		sector_3_time_label.text = "Sector 3 Time: %.2f" % sector_3_time
		calculate_and_display_lap_time()
		sector_1_start_time = Time.get_ticks_msec()
	else:
		first_pass_finish = false
		race_started = true
		sector_1_start_time = Time.get_ticks_msec()


func calculate_and_display_lap_time():
	var lap_time = sector_1_time + sector_2_time + sector_3_time

	BestLapManager.save_best_time(map_id, lap_time)

	lap_time_label.text = "Lap Completed: %.2f" % lap_time

	if lap_time < best_lap_time:
		best_lap_time = lap_time
		lap_time_last_label.text = "Best Lap: %.2f" % best_lap_time

	sector_1_time = 0.0
	sector_2_time = 0.0
	sector_3_time = 0.0

	sector_1_time_label.text = "Sector 1 Time: --"
	sector_2_time_label.text = "Sector 2 Time: --"
	sector_3_time_label.text = "Sector 3 Time: --"
