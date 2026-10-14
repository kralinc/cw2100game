extends MarginContainer

signal units_saved(units: Array[Dictionary])

const UNIT_ITEM = preload("res://mapeditor/unit_item_container.tscn")

@onready var close_button: Button = $VBoxContainer/TopBarContainer/HBoxContainer/UnitScreenCloseButton
@onready var add_button: Button = $VBoxContainer/TopBarContainer/HBoxContainer/AddUnitButton
@onready var unit_list: VBoxContainer = $VBoxContainer/UnitManagementContainer/ScrollContainer/UnitListContainer


func _ready() -> void:
	close_button.pressed.connect(_on_close_button_pressed)
	add_button.pressed.connect(_on_add_button_pressed)


func open(units: Array[Dictionary]) -> void:
	for child in unit_list.get_children():
		unit_list.remove_child(child)
		child.queue_free()
	for unit in units:
		_add_item(unit)
	_refresh_advantage_options()
	visible = true


func _add_item(data: Dictionary) -> void:
	var item := UNIT_ITEM.instantiate() as UnitItemContainer
	unit_list.add_child(item)
	item.setup(data)
	item.changed.connect(_refresh_advantage_options)


func _on_add_button_pressed() -> void:
	var next_id := 0
	for item in _get_active_items():
		next_id = maxi(next_id, item.unit_id + 1)
	_add_item({
		"id": next_id,
		"name": "unit_%d" % next_id,
		"ui_name": "New Unit",
		"hp": 100,
		"movement": 3,
		"cost": 1,
		"texture": "",
		"advantage_ids": [],
	})
	_refresh_advantage_options()


func _on_close_button_pressed() -> void:
	var result: Array[Dictionary] = []
	var used_names := {}
	var valid_ids := {}
	for item in _get_active_items():
		valid_ids[item.unit_id] = true
	for item in _get_active_items():
		var data := item.get_data()
		# Unit keys are used as dictionary keys in units.json, so they must be unique and non-empty
		var unit_name: String = data["name"]
		if unit_name.is_empty():
			unit_name = "unit_%d" % data["id"]
		if used_names.has(unit_name):
			unit_name = "%s_%d" % [unit_name, data["id"]]
		used_names[unit_name] = true
		data["name"] = unit_name
		if data["ui_name"].is_empty():
			data["ui_name"] = unit_name
		data["advantage_ids"] = data["advantage_ids"].filter(func(id): return valid_ids.has(id) and id != data["id"])
		result.append(data)
	units_saved.emit(result)
	visible = false


# Each item's "Strong vs" menu lists every other unit, so rebuild them whenever names or the unit list change
func _refresh_advantage_options() -> void:
	var items := _get_active_items()
	for item in items:
		var others := []
		for other in items:
			if other != item:
				others.append([other.unit_id, other.get_display_name()])
		item.set_advantage_options(others)


# Excludes items already queued for deletion by their DEL button.
func _get_active_items() -> Array[UnitItemContainer]:
	var items: Array[UnitItemContainer] = []
	for child in unit_list.get_children():
		if child.is_queued_for_deletion():
			continue
		items.append(child as UnitItemContainer)
	return items
