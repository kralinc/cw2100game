extends Control

const FactionSelectUI = preload("res://FactionSelectUI.tscn")

var mapName:String
var factions:Dictionary
var factionControlModes:Dictionary = {}

var mapSelectDropdown:OptionButton
var factionContainer:HBoxContainer
var startButton:Button

func _ready() -> void:
	mapSelectDropdown = get_node("%MapSelectDropdown")
	mapSelectDropdown.item_selected.connect(onMapSelected)

	factionContainer = get_node("%FactionContainer")
	startButton = get_node("%StartButton")
	startButton.pressed.connect(onStartButtonPressed)

	getMaps()
	onMapSelected(0)

func getMaps() -> void:
	var maps_path = "res://maps"
	var dir = DirAccess.open(maps_path)
	if dir:
		var subdirs = dir.get_directories()
		for subdir_name in subdirs:
			if subdir_name != "common_data":
				mapSelectDropdown.add_item(subdir_name)
	else:
		printerr("Failed to open maps directory: %s" % maps_path)

func onMapSelected(itemIndex:int) -> void:
	mapName = mapSelectDropdown.get_item_text(itemIndex)
	factions = Global.setupFactions(mapName)
	factionControlModes = {}
	# Clear previous faction UI elements
	for child in factionContainer.get_children():
		child.queue_free()
	var firstFaction:bool = true
	for faction in factions.values():
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
	Global.setupGameData(mapName, factionControlModes)
	Global.spectatorMode = false
	get_tree().change_scene_to_file("res://root.tscn")
