extends Control

const PAINTABLE_LAYERS = ["Terrain", "Features", "FactionControl", "CombatUnitInit", "Important"]
const FACTION_SOURCE_ID = 1
const FACTION_COORDS = Vector2i(0, 0)

@onready var map: Node2D = $Map
@onready var layer_select: OptionButton = $UI/Panel/VBox/LayerSelect
@onready var tile_list: VBoxContainer = $UI/Panel/VBox/Scroll/TileList
@onready var back_confirm_container: MarginContainer = $UI/BackConfirmContainer
@onready var camera: CameraController = $Camera2D
@onready var faction_screen = $UI/FactionManagementScreen

var current_layer: TileMapLayer
var button_group := ButtonGroup.new()
var selected_source: int = -1
var selected_coords: Vector2i = Vector2i.ZERO
var selected_alt: int = 0
var painting: bool = false
# Each entry: { "name": String, "color": Color, "alt_id": int, "flag": String }
var factions: Array[Dictionary] = []


func _ready() -> void:
	_init_default_factions()
	for layer_name in PAINTABLE_LAYERS:
		layer_select.add_item(layer_name)
	layer_select.item_selected.connect(_on_layer_selected)
	layer_select.select(0)
	_on_layer_selected(0)
	$Camera2D.position = Vector2(600, 400)
	faction_screen.factions_saved.connect(_on_factions_saved)


func _init_default_factions() -> void:
	factions = [
		{"name": "RED", "color": Color.RED, "alt_id": 1, "flag": ""},
		{"name": "BLU", "color": Color.BLUE, "alt_id": 2, "flag": ""},
	]
	_init_faction_tiles()


func _init_faction_tiles() -> void:
	var faction_layer: TileMapLayer = map.get_node("FactionControl")
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


func _on_layer_selected(index: int) -> void:
	current_layer = map.get_node(PAINTABLE_LAYERS[index])
	_build_tile_list(current_layer)


func _build_tile_list(layer: TileMapLayer) -> void:
	for child in tile_list.get_children():
		tile_list.remove_child(child)
		child.queue_free()

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
	# Prevent map painter input if the back confirm dialog or faction screen is open
	if (back_confirm_container.visible == true):
		return
	if faction_screen.visible:
		return


	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
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
		current_layer.erase_cell(cell)
	else:
		current_layer.set_cell(cell, selected_source, selected_coords, selected_alt)


func _on_back_button_pressed() -> void:
	back_confirm_container.visible = true
	camera.disable_camera = true


func _on_confirm_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://MainMenu.tscn")


func _on_cancel_back_button_pressed() -> void:
	back_confirm_container.visible = false
	camera.disable_camera = false
