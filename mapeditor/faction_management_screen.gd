extends MarginContainer

signal factions_saved(factions: Array[Dictionary])

const FACTION_ITEM = preload("res://mapeditor/faction_item_container.tscn")

@onready var close_button: Button = $VBoxContainer/TopBarContainer/HBoxContainer/FactionScreenCloseButton
@onready var add_button: Button = $VBoxContainer/TopBarContainer/HBoxContainer/AddFactionButton
@onready var faction_list: VBoxContainer = $VBoxContainer/FactionManagementContainer/ScrollContainer/FactionListContainer


func _ready() -> void:
	close_button.pressed.connect(_on_close_button_pressed)
	add_button.pressed.connect(_on_add_button_pressed)


func open(factions: Array[Dictionary]) -> void:
	for child in faction_list.get_children():
		faction_list.remove_child(child)
		child.queue_free()
	for faction in factions:
		var item := FACTION_ITEM.instantiate() as FactionItemContainer
		faction_list.add_child(item)
		item.setup(faction)
	visible = true


func _on_add_button_pressed() -> void:
	var next_id := 1
	for item in _get_active_items():
		next_id = maxi(next_id, item.alt_id + 1)
	var item := FACTION_ITEM.instantiate() as FactionItemContainer
	faction_list.add_child(item)
	item.setup({"name": "", "color": Color.WHITE, "alt_id": next_id, "flag": ""})


func _on_close_button_pressed() -> void:
	var result: Array[Dictionary] = []
	for item in _get_active_items():
		result.append(item.get_data())
	factions_saved.emit(result)
	visible = false


# Excludes items already queued for deletion by their DEL button.
func _get_active_items() -> Array[FactionItemContainer]:
	var items: Array[FactionItemContainer] = []
	for child in faction_list.get_children():
		if child.is_queued_for_deletion():
			continue
		items.append(child as FactionItemContainer)
	return items
