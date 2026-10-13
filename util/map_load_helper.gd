extends Object

class_name MapLoadHelper

const MAP_TEMPLATE = preload("res://util/map_template.tscn")
const FACTION_SOURCE_ID = 1
const FACTION_COORDS = Vector2i(0, 0)

static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Missing file: %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		push_error("Invalid JSON: %s" % path)
	return parsed

static func create_dir_dialog(title: String, source:Node) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.title = title
	source.add_child(dialog)
	return dialog

static func instantiate_map() -> Node2D:
	return MAP_TEMPLATE.instantiate() as Node2D

static func load_map_data(dir: String) -> Array:
	var map_data = read_json(dir.path_join("mapdata.json"))
	if not (map_data is Array):
		push_error("Map folder is missing or has invalid data: %s" % dir)
		return []
	return map_data

static func apply_map_data(map: Node2D, entries: Array) -> void:
	var terrain: TileMapLayer = map.get_node("Terrain")
	var features: TileMapLayer = map.get_node("Features")
	var important: TileMapLayer = map.get_node("Important")
	var units: TileMapLayer = map.get_node("CombatUnitInit")
	var factions_layer: TileMapLayer = map.get_node("FactionControl")
	for entry in entries:
		var cell := Vector2i(int(entry["x"]), int(entry["y"]))
		terrain.set_cell(cell, 0, Vector2i(int(entry["terrain"]), 0), 0)
		var features_x := int(entry["features"])
		if features_x != -1:
			features.set_cell(cell, 0, Vector2i(features_x, 0), 0)
		if entry["important"]:
			important.set_cell(cell, 0, Vector2i.ZERO, 0)
		var unit := int(entry["unit"])
		if unit != -1:
			units.set_cell(cell, unit, Vector2i.ZERO, 0)
		var faction_alt := int(entry["faction"])
		if faction_alt != -1:
			factions_layer.set_cell(cell, FACTION_SOURCE_ID, FACTION_COORDS, faction_alt)

static func build_map_data(map: Node2D) -> Array:
	var terrain: TileMapLayer = map.get_node("Terrain")
	var features: TileMapLayer = map.get_node("Features")
	var important: TileMapLayer = map.get_node("Important")
	var units: TileMapLayer = map.get_node("CombatUnitInit")
	var factions_layer: TileMapLayer = map.get_node("FactionControl")
	var data := []
	for cell in terrain.get_used_cells():
		data.append({
			"x": cell.x,
			"y": cell.y,
			"terrain": terrain.get_cell_atlas_coords(cell).x,
			"features": features.get_cell_atlas_coords(cell).x if features.get_cell_source_id(cell) != -1 else -1,
			"important": important.get_cell_source_id(cell) != -1,
			"unit": units.get_cell_source_id(cell),
			"faction": factions_layer.get_cell_alternative_tile(cell) if factions_layer.get_cell_source_id(cell) != -1 else -1,
		})
	return data

static func init_faction_tiles(faction_layer: TileMapLayer, factions: Array[Dictionary]) -> void:
	var atlas := faction_layer.tile_set.get_source(FACTION_SOURCE_ID) as TileSetAtlasSource
	var valid_ids: Array[int] = [0]
	for faction in factions:
		var alt_id: int = faction["alt_id"]
		valid_ids.append(alt_id)
		if not atlas.has_alternative_tile(FACTION_COORDS, alt_id):
			atlas.create_alternative_tile(FACTION_COORDS, alt_id)
		var data := atlas.get_tile_data(FACTION_COORDS, alt_id)
		data.modulate = faction["color"]
		data.set_custom_data("factionId", alt_id)

	var stale_ids: Array[int] = []
	for i in atlas.get_alternative_tiles_count(FACTION_COORDS):
		var alt := atlas.get_alternative_tile_id(FACTION_COORDS, i)
		if not valid_ids.has(alt):
			stale_ids.append(alt)
	if stale_ids.is_empty():
		return

	for cell in faction_layer.get_used_cells():
		if faction_layer.get_cell_source_id(cell) == FACTION_SOURCE_ID \
				and faction_layer.get_cell_atlas_coords(cell) == FACTION_COORDS \
				and stale_ids.has(faction_layer.get_cell_alternative_tile(cell)):
			faction_layer.erase_cell(cell)
	for alt in stale_ids:
		atlas.remove_alternative_tile(FACTION_COORDS, alt)

static func parse_faction_data(dir: String) -> Array[Dictionary]:
	var factions: Array[Dictionary] = []
	var faction_data = MapLoadHelper.read_json(dir.path_join("factiondata.json"))
	if not (faction_data is Array):
		push_error("Map folder is missing or has invalid data: %s" % dir)
		return []
	for entry in faction_data:
		var flag_file: String = entry["flag_file"]
		factions.append({
			"name": entry["name"],
			"alt_id": int(entry["id"]),
			"color": Color.html(entry["color"]),
			"flag": dir.path_join("flags").path_join(flag_file) if not flag_file.is_empty() else "",
		})
	return factions

static func create_faction_info_from_faction_data(faction_data: Array[Dictionary]) -> Dictionary[int, Faction]:
	var factionInfo:Dictionary[int, Faction] = {}
	for faction_data_item in faction_data:
		var faction:Faction = Faction.new()
		faction.id = faction_data_item.alt_id
		faction.fullName = faction_data_item.name
		faction.color = faction_data_item.color
		faction.flag = load_flag_texture(faction_data_item.flag)
		factionInfo[faction.id] = faction
	return factionInfo

static func load_flag_texture(path: String) -> Texture2D:
	var texture: Texture2D = null
	if path.begins_with("res://"):
		texture = load(path) as Texture2D
	else:
		var img := Image.load_from_file(path)
		if img != null:
			texture = ImageTexture.create_from_image(img)
	return texture

static func init_highlight_tiles(highlight_layer: TileMapLayer, colors: Array) -> void:
	var atlas := highlight_layer.tile_set.get_source(0) as TileSetAtlasSource
	for i in colors.size():
		var alt_id := i + 1
		if not atlas.has_alternative_tile(Vector2i.ZERO, alt_id):
			atlas.create_alternative_tile(Vector2i.ZERO, alt_id)
		atlas.get_tile_data(Vector2i.ZERO, alt_id).modulate = colors[i]

static func load_special_names(dir: String) -> Dictionary[Vector2i, String]:
	var names: Dictionary[Vector2i, String] = {}
	var path := dir.path_join("specialnames.json")
	if not FileAccess.file_exists(path):
		return names
	var data = read_json(path)
	if not (data is Dictionary):
		return names
	for key in data:
		var split_coords: PackedStringArray = key.split(",")
		var tile_name := str(data[key])
		if split_coords.size() == 2 and not tile_name.is_empty():
			names[Vector2i(split_coords[0].to_int(), split_coords[1].to_int())] = tile_name
	return names

static func build_special_names_data(names: Dictionary[Vector2i, String]) -> Dictionary:
	var data := {}
	for cell in names:
		data["%d,%d" % [cell.x, cell.y]] = names[cell]
	return data
