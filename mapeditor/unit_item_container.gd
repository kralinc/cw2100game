class_name UnitItemContainer
extends MarginContainer

# Emitted when anything shown on other items changes (names, advantages, deletion)
signal changed

var unit_id: int = 0
var texture_path: String = ""
var advantage_ids: Array[int] = []

@onready var unit_texture: TextureRect = $HBoxContainer/TextureContainer/UnitTexture
@onready var pick_texture_button: Button = $HBoxContainer/TextureContainer/PickTextureButton
@onready var ui_name_edit: LineEdit = $HBoxContainer/InfoContainer/NameContainer/UiNameEdit
@onready var name_edit: LineEdit = $HBoxContainer/InfoContainer/NameContainer/NameEdit
@onready var hp_spin: SpinBox = $HBoxContainer/InfoContainer/StatsContainer/HpSpin
@onready var movement_spin: SpinBox = $HBoxContainer/InfoContainer/StatsContainer/MovementSpin
@onready var cost_spin: SpinBox = $HBoxContainer/InfoContainer/StatsContainer/CostSpin
@onready var advantage_menu: MenuButton = $HBoxContainer/InfoContainer/AdvantageMenu
@onready var id_label: Label = $HBoxContainer/InfoContainer/IDLabel
@onready var delete_button: Button = $HBoxContainer/DeleteUnitButton

var texture_dialog: FileDialog


func _ready() -> void:
	texture_dialog = FileDialog.new()
	texture_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	texture_dialog.access = FileDialog.ACCESS_FILESYSTEM
	texture_dialog.use_native_dialog = true
	texture_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	texture_dialog.file_selected.connect(_on_texture_file_selected)
	add_child(texture_dialog)

	pick_texture_button.pressed.connect(_on_pick_texture_button_pressed)
	name_edit.text_changed.connect(func(_text): changed.emit())
	ui_name_edit.text_changed.connect(func(_text): changed.emit())
	advantage_menu.get_popup().hide_on_checkable_item_selection = false
	advantage_menu.get_popup().id_pressed.connect(_on_advantage_toggled)
	delete_button.pressed.connect(_on_delete_pressed)


# Must be called after add_child() so the @onready node references are valid.
func setup(data: Dictionary) -> void:
	unit_id = data.get("id", 0)
	name_edit.text = data.get("name", "")
	ui_name_edit.text = data.get("ui_name", "")
	hp_spin.value = data.get("hp", 100)
	movement_spin.value = data.get("movement", 1)
	cost_spin.value = data.get("cost", 1)
	advantage_ids.assign(data.get("advantage_ids", []))
	id_label.text = "ID: %d" % unit_id
	texture_path = data.get("texture", "")
	unit_texture.texture = MapLoadHelper.load_texture(texture_path)


func get_data() -> Dictionary:
	return {
		"id": unit_id,
		"name": name_edit.text.strip_edges(),
		"ui_name": ui_name_edit.text.strip_edges(),
		"hp": int(hp_spin.value),
		"movement": int(movement_spin.value),
		"cost": int(cost_spin.value),
		"texture": texture_path,
		"advantage_ids": advantage_ids.duplicate(),
	}


func get_display_name() -> String:
	var ui_name := ui_name_edit.text.strip_edges()
	return ui_name if not ui_name.is_empty() else name_edit.text.strip_edges()


# others: Array of [id, display name] for every other unit, used to fill the advantage menu
func set_advantage_options(others: Array) -> void:
	var popup := advantage_menu.get_popup()
	popup.clear()
	var names: Array[String] = []
	for other in others:
		var other_id: int = other[0]
		popup.add_check_item(other[1], other_id)
		var checked := advantage_ids.has(other_id)
		popup.set_item_checked(popup.get_item_index(other_id), checked)
		if checked:
			names.append(other[1])
	advantage_menu.text = "Strong vs: " + (", ".join(names) if not names.is_empty() else "none")


func _on_advantage_toggled(other_id: int) -> void:
	if advantage_ids.has(other_id):
		advantage_ids.erase(other_id)
	else:
		advantage_ids.append(other_id)
	changed.emit()


func _on_delete_pressed() -> void:
	queue_free()
	changed.emit()


func _on_pick_texture_button_pressed() -> void:
	texture_dialog.popup_centered_ratio(0.6)


func _on_texture_file_selected(path: String) -> void:
	texture_path = path
	unit_texture.texture = MapLoadHelper.load_texture(path)
