extends Control

const PAINTABLE_LAYERS = ["Terrain", "Features", "FactionControl", "CombatUnitInit", "Important"]
const NAME_TILES_MODE = "Name Tiles"
const HIGHLIGHT_HOVER_ALT = 0
const HIGHLIGHT_SELECTED_ALT = 2
const HIGHLIGHT_NAMED_ALT = 3

@onready var map: Node2D = $Map
@onready var layer_select: OptionButton = $UI/Panel/VBox/LayerSelect
@onready var tile_list: VBoxContainer = $UI/Panel/VBox/Scroll/TileList
@onready var back_confirm_container: MarginContainer = $UI/BackConfirmContainer
@onready var camera: CameraController = $Camera2D
@onready var faction_screen = $UI/FactionManagementScreen
@onready var save_button: Button = $UI/TopPanel/HBox/SaveButton
@onready var load_button: Button = $UI/TopPanel/HBox/LoadButton
@onready var map_title_input:LineEdit = $UI/TopPanel/HBox/MapTitleInput
@onready var animation_player:AnimationPlayer = $AnimationPlayer
@onready var highlight_layer: TileMapLayer = $Map/Highlight

var current_layer: TileMapLayer
var button_group := ButtonGroup.new()
var selected_source: int = -1
var selected_coords: Vector2i = Vector2i.ZERO
var selected_alt: int = 0
var painting: bool = false
# Each entry: { "name": String, "color": Color, "alt_id": int, "flag": String }
var factions: Array[Dictionary] = []
var save_path: String = ""
var dirty: bool = false
var save_dialog: FileDialog
var load_dialog: FileDialog
var hoveredCell:Vector2i
var naming_mode: bool = false
var special_names: Dictionary[Vector2i, String] = {}
var name_cell = null # Vector2i of the tile being named, or null
var name_input: LineEdit


func _ready() -> void:
	_init_default_factions()
	MapLoadHelper.init_highlight_tiles(highlight_layer, Global.cellHighlightColors)
	for layer_name in PAINTABLE_LAYERS:
		layer_select.add_item(layer_name)
	layer_select.add_item(NAME_TILES_MODE)
	layer_select.item_selected.connect(_on_layer_selected)
	layer_select.select(0)
	_on_layer_selected(0)
	$Camera2D.position = Vector2(600, 400)
	faction_screen.factions_saved.connect(_on_factions_saved)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	save_dialog = MapLoadHelper.create_dir_dialog("Choose save location", self)
	save_dialog.dir_selected.connect(_on_save_dir_selected)
	load_dialog = MapLoadHelper.create_dir_dialog("Open map folder", self)
	load_dialog.dir_selected.connect(_load_from)

func _redraw_highlights() -> void:
	highlight_layer.clear()
	if naming_mode:
		for cell in special_names:
			_refresh_highlight(cell)
		if name_cell != null:
			_refresh_highlight(name_cell)
	_refresh_highlight(hoveredCell)


# Redraws a single cell's highlight. Priority: selected > hovered > named.
func _refresh_highlight(cell: Vector2i) -> void:
	var alt := -1
	if naming_mode and name_cell != null and cell == name_cell:
		alt = HIGHLIGHT_SELECTED_ALT
	elif cell == hoveredCell:
		alt = HIGHLIGHT_HOVER_ALT
	elif naming_mode and special_names.has(cell):
		alt = HIGHLIGHT_NAMED_ALT
	if alt == -1:
		highlight_layer.erase_cell(cell)
	else:
		highlight_layer.set_cell(cell, 0, Vector2i.ZERO, alt)

func _init_default_factions() -> void:
	factions = [
		{"name": "RED", "color": Color.RED, "alt_id": 1, "flag": ""},
		{"name": "BLU", "color": Color.BLUE, "alt_id": 2, "flag": ""},
	]
	_init_faction_tiles()


func _init_faction_tiles() -> void:
	MapLoadHelper.init_faction_tiles(map.get_node("FactionControl"), factions)


func _get_faction_by_alt(alt_id: int) -> Dictionary:
	for faction in factions:
		if faction["alt_id"] == alt_id:
			return faction
	return {}


func _on_faction_setup_button_pressed() -> void:
	faction_screen.open(factions)
	camera.disable_camera = true
	painting = false


func _on_factions_saved(new_factions: Array[Dictionary]) -> void:
	factions = new_factions
	camera.disable_camera = false
	_init_faction_tiles()
	if current_layer == map.get_node("FactionControl"):
		_build_tile_list(current_layer)
	_set_dirty(true)


func _on_layer_selected(index: int) -> void:
	painting = false
	naming_mode = index >= PAINTABLE_LAYERS.size()
	if naming_mode:
		current_layer = null
		_build_name_editor()
	else:
		current_layer = map.get_node(PAINTABLE_LAYERS[index])
		_build_tile_list(current_layer)
	_redraw_highlights()


func _clear_tile_list() -> void:
	for child in tile_list.get_children():
		tile_list.remove_child(child)
		child.queue_free()
	name_input = null


func _build_name_editor() -> void:
	_clear_tile_list()
	name_input = LineEdit.new()
	name_input.placeholder_text = "Write name here"
	name_input.text_changed.connect(_on_name_changed)
	name_input.text_submitted.connect(func(_text): name_input.release_focus())
	tile_list.add_child(name_input)
	_update_name_input()


func _update_name_input() -> void:
	if name_input == null:
		return
	name_input.editable = name_cell != null
	name_input.text = special_names.get(name_cell, "") if name_cell != null else ""


func _select_name_cell(cell: Vector2i) -> void:
	if map.get_node("Terrain").get_cell_source_id(cell) == -1:
		return
	var previous = name_cell
	name_cell = cell
	if previous != null:
		_refresh_highlight(previous)
	_refresh_highlight(cell)
	_update_name_input()
	name_input.grab_focus()
	name_input.caret_column = name_input.text.length()


func _on_name_changed(new_text: String) -> void:
	if name_cell == null:
		return
	var tile_name := new_text.strip_edges()
	if tile_name.is_empty():
		special_names.erase(name_cell)
	else:
		special_names[name_cell] = tile_name
	_set_dirty(true)


func _build_tile_list(layer: TileMapLayer) -> void:
	_clear_tile_list()

	var erase_button := Button.new()
	erase_button.text = "Erase"
	erase_button.toggle_mode = true
	erase_button.button_group = button_group
	erase_button.pressed.connect(_on_tile_selected.bind(-1, Vector2i.ZERO, 0))
	tile_list.add_child(erase_button)

	var tile_set := layer.tile_set
	var has_custom_data := tile_set.get_custom_data_layers_count() > 0
	var is_faction_layer := layer.name == "FactionControl"
	var first_button: Button = null
	var first_selection := [-1, Vector2i.ZERO, 0]

	for i in tile_set.get_source_count():
		var source_id := tile_set.get_source_id(i)
		var atlas := tile_set.get_source(source_id) as TileSetAtlasSource
		if atlas == null:
			continue
		for j in atlas.get_tiles_count():
			var coords := atlas.get_tile_id(j)
			for k in atlas.get_alternative_tiles_count(coords):
				var alt := atlas.get_alternative_tile_id(coords, k)
				if is_faction_layer and alt == 0:
					continue
				var data := atlas.get_tile_data(coords, alt)

				var text := "src %d (%d,%d) alt %d" % [source_id, coords.x, coords.y, alt]
				if is_faction_layer:
					text = _get_faction_by_alt(alt).get("name", text)
				elif has_custom_data:
					text += " " + str(data.get_custom_data_by_layer_id(0))

				var icon := AtlasTexture.new()
				icon.atlas = atlas.texture
				icon.region = atlas.get_tile_texture_region(coords)

				var button := Button.new()
				button.text = text
				button.icon = icon
				button.expand_icon = false
				button.toggle_mode = true
				button.button_group = button_group
				button.modulate = data.modulate
				button.pressed.connect(_on_tile_selected.bind(source_id, coords, alt))
				tile_list.add_child(button)

				if first_button == null:
					first_button = button
					first_selection = [source_id, coords, alt]

	if first_button != null:
		first_button.button_pressed = true
		_on_tile_selected(first_selection[0], first_selection[1], first_selection[2])
	else:
		erase_button.button_pressed = true
		_on_tile_selected(-1, Vector2i.ZERO, 0)


func _on_tile_selected(source: int, coords: Vector2i, alt: int) -> void:
	selected_source = source
	selected_coords = coords
	selected_alt = alt


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var global_pos = get_global_mouse_position()
		var pos_hovered: Vector2i = map.get_node("Terrain").local_to_map(global_pos)
		if pos_hovered != hoveredCell:
			var previous := hoveredCell
			hoveredCell = pos_hovered
			_refresh_highlight(previous)
			_refresh_highlight(hoveredCell)
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_S and key.ctrl_pressed and not faction_screen.visible:
			_on_save_pressed()
			get_viewport().set_input_as_handled()
			return

	# Prevent map painter input if the back confirm dialog or faction screen is open
	if (back_confirm_container.visible == true):
		return
	if faction_screen.visible:
		return


	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if naming_mode:
				if mouse_button.pressed:
					var terrain: TileMapLayer = map.get_node("Terrain")
					_select_name_cell(terrain.local_to_map(terrain.get_local_mouse_position()))
				return
			painting = mouse_button.pressed
			if painting:
				_paint()
	elif event is InputEventMouseMotion and painting:
		_paint()


func _paint() -> void:
	if current_layer == null:
		return
	var cell := current_layer.local_to_map(current_layer.get_local_mouse_position())
	if selected_source == -1:
		if current_layer.get_cell_source_id(cell) == -1:
			return
		current_layer.erase_cell(cell)
	else:
		if current_layer.get_cell_source_id(cell) == selected_source \
				and current_layer.get_cell_atlas_coords(cell) == selected_coords \
				and current_layer.get_cell_alternative_tile(cell) == selected_alt:
			return
		current_layer.set_cell(cell, selected_source, selected_coords, selected_alt)
	_set_dirty(true)


func _on_back_button_pressed() -> void:
	back_confirm_container.visible = true
	camera.disable_camera = true


func _on_confirm_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://MainMenu.tscn")


func _on_cancel_back_button_pressed() -> void:
	back_confirm_container.visible = false
	camera.disable_camera = false



func _set_dirty(value: bool) -> void:
	dirty = value
	save_button.text = "Save*" if dirty else "Save"


func _on_save_pressed() -> void:
	if (map_title_input.text.length() <= 0):
		animation_player.play("map_title_required")
		return
	if save_path.is_empty():
		save_dialog.popup_centered()
	else:
		_save_to(save_path)


func _on_save_dir_selected(dir: String) -> void:
	save_path = dir.path_join(map_title_input.text)
	_save_to(save_path)


func _on_load_pressed() -> void:
	load_dialog.popup_centered()


func _save_to(dir: String) -> bool:
	var flags_dir := dir.path_join("flags")
	if DirAccess.make_dir_recursive_absolute(flags_dir) != OK:
		push_error("Could not create save folder: %s" % flags_dir)
		return false
	var flag_files := _copy_flags(flags_dir)
	if not _write_json(dir.path_join("mapdata.json"), MapLoadHelper.build_map_data(map)):
		return false
	if not _write_json(dir.path_join("factiondata.json"), _build_faction_data(flag_files)):
		return false
	if not _write_json(dir.path_join("specialnames.json"), MapLoadHelper.build_special_names_data(special_names)):
		return false
	_update_flag_paths(flags_dir, flag_files)
	_set_dirty(false)
	return true


func _write_json(path: String, data: Variant) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true



func _build_faction_data(flag_files: Dictionary) -> Array:
	var data := []
	for faction in factions:
		var alt_id: int = faction["alt_id"]
		var color: Color = faction["color"]
		data.append({
			"name": faction["name"],
			"id": alt_id,
			"flag_file": flag_files.get(alt_id, ""),
			"color": color.to_html(false),
		})
	return data


func _copy_flags(flags_dir: String) -> Dictionary:
	var flag_files := {}
	var used_names := {}
	for faction in factions:
		var src: String = faction["flag"]
		if src.is_empty():
			continue
		var alt_id: int = faction["alt_id"]
		var file_name := src.get_file()
		if used_names.has(file_name):
			file_name = "%d.png" % alt_id
		used_names[file_name] = true
		flag_files[alt_id] = _copy_flag(src, flags_dir, file_name, alt_id)
	return flag_files


func _copy_flag(src: String, flags_dir: String, file_name: String, alt_id: int) -> String:
	var dest := flags_dir.path_join(file_name)
	var src_abs := ProjectSettings.globalize_path(src)
	if src_abs.simplify_path() == dest.simplify_path():
		return file_name
	if FileAccess.file_exists(src) and DirAccess.copy_absolute(src_abs, dest) == OK:
		return file_name
	var fallback_name := "%d.png" % alt_id
	var image := _load_flag_image(src)
	if image == null or image.save_png(flags_dir.path_join(fallback_name)) != OK:
		push_error("Could not save flag for faction %d from %s" % [alt_id, src])
		return ""
	return fallback_name


func _load_flag_image(src: String) -> Image:
	if src.begins_with("res://"):
		var texture := load(src) as Texture2D
		return texture.get_image() if texture != null else null
	return Image.load_from_file(src)


func _update_flag_paths(flags_dir: String, flag_files: Dictionary) -> void:
	for faction in factions:
		var file_name: String = flag_files.get(faction["alt_id"], "")
		if not file_name.is_empty():
			faction["flag"] = flags_dir.path_join(file_name)


func _load_from(dir: String) -> void:
	factions.clear()
	var map_data := MapLoadHelper.load_map_data(dir)
	if map_data.is_empty():
		return
	factions = MapLoadHelper.parse_faction_data(dir)
	_clear_map()
	_init_faction_tiles()
	MapLoadHelper.apply_map_data(map, map_data)
	special_names = MapLoadHelper.load_special_names(dir)
	name_cell = null
	save_path = dir
	_set_dirty(false)
	_on_layer_selected(layer_select.selected)


func _clear_map() -> void:
	for layer_name in PAINTABLE_LAYERS:
		var layer: TileMapLayer = map.get_node(layer_name)
		layer.clear()

