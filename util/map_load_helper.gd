extends Object

class_name MapLoadHelper

const MAP_TEMPLATE = preload("res://util/map_template.tscn")
const COMMON_DATA_DIR = "res://common_data"
const UNIT_TEXTURE_DIR = COMMON_DATA_DIR + "/assets/units"
const FACTION_SOURCE_ID = 1
const FACTION_COORDS = Vector2i(0, 0)
const UNIT_COORDS = Vector2i(0, 0)
const MAP_UNIT_TEXTURE_FOLDER = "units"
const FALLBACK_TEXTURE = "res://icon.svg"

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
		faction.flag = load_texture(faction_data_item.flag)
		factionInfo[faction.id] = faction
	return factionInfo

static func load_texture(path: String) -> Texture2D:
	var texture: Texture2D = null
	if path.is_empty():
		return null
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

# Each unit definition: { "id": int, "name": String, "ui_name": String, "hp": int, "movement": int,
#   "texture": String (full path), "advantage_ids": Array[int] }
# "id" is the unit's tile source id on the CombatUnitInit layer, which is what mapdata.json stores.

# Loads the map's units.json, falling back to the default unit definitions in common_data
static func load_unit_definitions(dir: String) -> Array[Dictionary]:
	var path := dir.path_join("units.json")
	if dir.is_empty() or not FileAccess.file_exists(path):
		print("No units file in map folder. Using default units.")
		return default_unit_definitions()
	return parse_unit_data(read_json(path), dir.path_join(MAP_UNIT_TEXTURE_FOLDER))

static func default_unit_definitions() -> Array[Dictionary]:
	return parse_unit_data(read_json(COMMON_DATA_DIR.path_join("units.json")), UNIT_TEXTURE_DIR)

static func parse_unit_data(data: Variant, texture_dir: String) -> Array[Dictionary]:
	var units: Array[Dictionary] = []
	if not (data is Dictionary):
		push_error("Invalid unit data")
		return units
	# Units without an id get one after the highest existing id, in file order
	var next_id := 0
	for key in data:
		next_id = maxi(next_id, int(data[key].get("id", -1)) + 1)
	var ids_by_name := {}
	for key in data:
		var entry: Dictionary = data[key]
		var id: int
		if entry.has("id"):
			id = int(entry["id"])
		else:
			id = next_id
			next_id += 1
		ids_by_name[key] = id
		var texture_file: String = entry.get("texture", "")
		units.append({
			"id": id,
			"name": key,
			"ui_name": entry.get("uiName", key),
			"hp": int(entry.get("hp", 100)),
			"movement": int(entry.get("movement", 1)),
			"texture": texture_dir.path_join(texture_file) if not texture_file.is_empty() else "",
			"advantage_ids": [] as Array[int],
		})
	for unit in units:
		for other_name in data[unit["name"]].get("advantageVersus", []):
			if ids_by_name.has(other_name):
				unit["advantage_ids"].append(ids_by_name[other_name])
	# JSON object order isn't preserved through saving, so keep units in id order
	units.sort_custom(func(a, b): return a["id"] < b["id"])
	return units

# Builds the units.json contents. texture_files maps unit id -> file name inside the map's units folder.
static func build_unit_data(units: Array[Dictionary], texture_files: Dictionary) -> Dictionary:
	var names_by_id := {}
	for unit in units:
		names_by_id[unit["id"]] = unit["name"]
	var data := {}
	for unit in units:
		var advantage_versus := []
		for other_id in unit["advantage_ids"]:
			if names_by_id.has(other_id):
				advantage_versus.append(names_by_id[other_id])
		data[unit["name"]] = {
			"id": unit["id"],
			"uiName": unit["ui_name"],
			"movement": unit["movement"],
			"texture": texture_files.get(unit["id"], ""),
			"hp": unit["hp"],
			"advantageVersus": advantage_versus,
		}
	return data

static func create_unit_types(units: Array[Dictionary]) -> Dictionary[String, UnitType]:
	var names_by_id := {}
	for unit in units:
		names_by_id[unit["id"]] = unit["name"]
	var unit_types: Dictionary[String, UnitType] = {}
	for unit in units:
		var advantage_versus: Array[String] = []
		for other_id in unit["advantage_ids"]:
			if names_by_id.has(other_id):
				advantage_versus.append(names_by_id[other_id])
		unit_types[unit["name"]] = UnitType.new(load_unit_texture(unit["texture"]), unit["name"], unit["hp"], advantage_versus, unit["movement"], unit["ui_name"])
	return unit_types

static func load_unit_texture(path: String) -> Texture2D:
	var texture := load_texture(path)
	return texture if texture != null else load(FALLBACK_TEXTURE) as Texture2D

# Rebuilds the unit layer's tile set so there is one atlas source per unit, using the unit id as the source id.
# Cells using a source that no longer has a unit are erased.
static func init_unit_tiles(unit_layer: TileMapLayer, units: Array[Dictionary]) -> void:
	var tile_set := unit_layer.tile_set
	var valid_ids := {}
	for unit in units:
		var id: int = unit["id"]
		valid_ids[id] = true
		var texture := load_unit_texture(unit["texture"])
		var atlas: TileSetAtlasSource
		if tile_set.has_source(id):
			atlas = tile_set.get_source(id) as TileSetAtlasSource
		else:
			atlas = TileSetAtlasSource.new()
			tile_set.add_source(atlas, id)
		atlas.texture_region_size = Vector2i(texture.get_size())
		atlas.texture = texture
		if not atlas.has_tile(UNIT_COORDS):
			atlas.create_tile(UNIT_COORDS)
		atlas.get_tile_data(UNIT_COORDS, 0).set_custom_data("type", unit["name"])

	var stale_ids: Array[int] = []
	for i in tile_set.get_source_count():
		var source_id := tile_set.get_source_id(i)
		if not valid_ids.has(source_id):
			stale_ids.append(source_id)
	if stale_ids.is_empty():
		return
	for cell in unit_layer.get_used_cells():
		if stale_ids.has(unit_layer.get_cell_source_id(cell)):
			unit_layer.erase_cell(cell)
	for source_id in stale_ids:
		tile_set.remove_source(source_id)

# Copies each source image into dest_dir and returns {id: file_name}.
# sources maps an id (faction alt id, unit id) -> image path; empty paths are skipped.
static func copy_image_files(sources: Dictionary, dest_dir: String) -> Dictionary:
	var files := {}
	var used_names := {}
	for id in sources:
		var src: String = sources[id]
		if src.is_empty():
			continue
		var file_name := src.get_file()
		if used_names.has(file_name):
			file_name = "%d.png" % id
		used_names[file_name] = true
		var copied := _copy_image_file(src, dest_dir, file_name, id)
		if not copied.is_empty():
			files[id] = copied
	return files

static func _copy_image_file(src: String, dest_dir: String, file_name: String, id: int) -> String:
	var dest := dest_dir.path_join(file_name)
	var src_abs := ProjectSettings.globalize_path(src)
	if src_abs.simplify_path() == dest.simplify_path():
		return file_name
	if FileAccess.file_exists(src) and DirAccess.copy_absolute(src_abs, dest) == OK:
		return file_name
	# res:// files may only exist as imported resources in exported builds, so re-save them from the loaded image
	var fallback_name := "%d.png" % id
	var image := _load_image(src)
	if image == null or image.save_png(dest_dir.path_join(fallback_name)) != OK:
		push_error("Could not save image %d from %s" % [id, src])
		return ""
	return fallback_name

static func _load_image(src: String) -> Image:
	if src.begins_with("res://"):
		var texture := load(src) as Texture2D
		return texture.get_image() if texture != null else null
	return Image.load_from_file(src)
