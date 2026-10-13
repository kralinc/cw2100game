extends Control

const FactionSelectUI = preload("res://FactionSelectUI.tscn")


var factions:Dictionary[int, Faction]
var factionControlModes:Dictionary = {}
var factionContainer:HBoxContainer
var startButton:Button

var load_dialog: FileDialog
var map_dir:String

func _ready() -> void:

	factionContainer = get_node("%FactionContainer")
	startButton = get_node("%StartButton")
	startButton.pressed.connect(onStartButtonPressed)

	load_dialog = MapLoadHelper.create_dir_dialog("Open map folder", self)
	load_dialog.dir_selected.connect(_load_map_data)
	
	

func _setup_faction_UI(factionInfo:Dictionary[int, Faction]):
	# Clear previous faction UI elements
	for child in factionContainer.get_children():
		child.queue_free()
	factionControlModes = {}

	var firstFaction:bool = true
	for faction in factionInfo.values():
		if faction.id == 0: continue # Skip neutral faction

		var factionSelectUi = FactionSelectUI.instantiate()
		factionSelectUi.initialize(faction, firstFaction)
		factionSelectUi.control_option_selected.connect(onFactionControlOptionSelected)
		factionContainer.add_child(factionSelectUi)

		factionControlModes[faction.id] = true if firstFaction else false
		firstFaction = false


func onFactionControlOptionSelected(factionId:int, isHuman:bool) -> void:
	factionControlModes[factionId] = isHuman

func onStartButtonPressed() -> void:
	if map_dir.is_empty():
		push_warning("No map folder selected.")
		return
	Global.setupGameData(map_dir, factionControlModes)
	Global.spectatorMode = false
	get_tree().change_scene_to_file("res://root.tscn")


func _on_map_editor_button_pressed() -> void:
	get_tree().change_scene_to_file("res://mapeditor/MapEditor.tscn")


func _on_map_select_button_pressed() -> void:
	load_dialog.popup_centered()

func _load_map_data(dir: String) -> void:
	map_dir = dir
	var faction_data = MapLoadHelper.parse_faction_data(dir)
	var factionInfo = MapLoadHelper.create_faction_info_from_faction_data(faction_data)
	_setup_faction_UI(factionInfo)
	factions = factionInfo
