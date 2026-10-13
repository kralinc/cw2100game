extends Object

class_name MapLoadHelper

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