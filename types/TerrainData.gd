extends Resource

class_name TerrainData

# Declare member variables
var terrain_data_name: String
var in_game_name: String
var movement_cost: int

# Constructor to initialize the terrain data
func _init(data_name: String, game_name: String, cost: int) -> void:
	terrain_data_name = data_name
	in_game_name = game_name
	movement_cost = cost
