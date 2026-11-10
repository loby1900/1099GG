extends Node

var best_times_file = "user://best_times.cfg"
var config = ConfigFile.new()

func _ready():
	load_best_times()

func load_best_times():
	var error = config.load(best_times_file)
	if error == ERR_FILE_NOT_FOUND:
		initialize_default_best_times()

const KNOWN_MAP_IDS := ["Map1", "Map2", "Map3"]


func initialize_default_best_times():
	# Initialize with default (never-raced) best times for every known map.
	for map_name in KNOWN_MAP_IDS:
		config.set_value(map_name, "times", [9999.0, 9999.0, 9999.0])
	config.save(best_times_file)

func save_best_time(map_name: String, time: float) -> void:
	var error = config.load(best_times_file)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		print("Failed to load best times file: ", best_times_file)
		return

	var times = config.get_value(map_name, "times", [])
	times.append(time)
	times.sort()
	times = times.slice(0, 3)
	
	config.set_value(map_name, "times", times)
	config.save(best_times_file)

func get_best_times(map_name: String) -> Array:
	var error = config.load(best_times_file)
	if error != OK:
		print("Could not load best times, returning default values.")
		return [9999.0, 9999.0, 9999.0]
	return config.get_value(map_name, "times", [9999.0, 9999.0, 9999.0])

func clear_best_times() -> void:
	# Clear every map section actually present in the save file, not just a
	# hardcoded list, so a newly added map's times get cleared too.
	config.load(best_times_file)
	var sections = config.get_sections()
	if sections.is_empty():
		sections = KNOWN_MAP_IDS
	for map_name in sections:
		config.set_value(map_name, "times", [9999.0, 9999.0, 9999.0])
	config.save(best_times_file)
