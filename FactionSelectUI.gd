extends MarginContainer

signal control_option_selected(factionId:int, isHuman:bool)

var faction:Faction

func initialize(factionInfo:Faction, isFirst:bool) -> void:
	faction = factionInfo
	var factionName:Label = get_node("%FactionName")
	var flag:TextureRect = get_node("%Flag")
	var controlOption:OptionButton = get_node("%ControlOption")
	controlOption.item_selected.connect(onControlItemSelected)

	factionName.text = factionInfo.fullName
	flag.texture = factionInfo.flag
	controlOption.selected = 1 if isFirst else 0


func onControlItemSelected(index: int) -> void:
	control_option_selected.emit(faction.id, true if index == 1 else false)
