class_name FactionItemContainer
extends MarginContainer

var alt_id: int = 0
var flag_path: String = ""

@onready var flag_texture: TextureRect = $HBoxContainer/FlagContainer/FlagTexture
@onready var pick_flag_button: Button = $HBoxContainer/FlagContainer/PickFlagTextureButton
@onready var name_edit: LineEdit = $HBoxContainer/InfoContainer/NameEdit
@onready var color_rect: ColorRect = $HBoxContainer/InfoContainer/ColorContainer/ColorRect
@onready var pick_color_button: Button = $HBoxContainer/InfoContainer/ColorContainer/PickColorButton
@onready var color_popup: PopupPanel = $ColorPopup
@onready var color_picker: ColorPicker = $ColorPopup/ColorPicker
@onready var id_label: Label = $HBoxContainer/InfoContainer/IDLabel
@onready var delete_button: Button = $HBoxContainer/DeleteFactionButton

var flag_dialog: FileDialog


func _ready() -> void:
	flag_dialog = FileDialog.new()
	flag_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	flag_dialog.access = FileDialog.ACCESS_FILESYSTEM
	flag_dialog.use_native_dialog = true
	flag_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	flag_dialog.file_selected.connect(_on_flag_file_selected)
	add_child(flag_dialog)

	pick_flag_button.pressed.connect(_on_pick_flag_button_pressed)
	pick_color_button.pressed.connect(_on_pick_color_button_pressed)
	color_picker.color_changed.connect(_on_color_changed)
	delete_button.pressed.connect(queue_free)


# Must be called after add_child() so the @onready node references are valid.
func setup(data: Dictionary) -> void:
	alt_id = data.get("alt_id", 0)
	name_edit.text = data.get("name", "")
	var color: Color = data.get("color", Color.WHITE)
	color_rect.color = color
	color_picker.color = color
	id_label.text = "ID: %d" % alt_id
	flag_path = data.get("flag", "")
	if flag_path != "":
		flag_texture.texture = MapLoadHelper.load_texture(flag_path)
	else:
		flag_texture.texture = null


func get_data() -> Dictionary:
	return {"name": name_edit.text, "color": color_rect.color, "alt_id": alt_id, "flag": flag_path}


func _on_pick_flag_button_pressed() -> void:
	flag_dialog.popup_centered_ratio(0.6)


func _on_flag_file_selected(path: String) -> void:
	flag_path = path
	flag_texture.texture = MapLoadHelper.load_texture(path)


func _on_pick_color_button_pressed() -> void:
	color_popup.popup_centered()


func _on_color_changed(color: Color) -> void:
	color_rect.color = color
