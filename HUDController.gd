extends CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready():
	setPlayerInfo()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_map_hover_data(data:CellData) -> void:
	$TileInfo/PosLabel.text = str(data.pos) + str(Global.hgh.getAStarCellId(data.pos))
	if (data.specialName != null or data.specialName != ""):
		$TileInfo/TerrainLabel.text =  "%s (%s, %s)" % [data.specialName, data.terrain.in_game_name, data.feature.in_game_name]
	else:
		$TileInfo/TerrainLabel.text =  "%s, %s" % [data.terrain.in_game_name, data.feature.in_game_name]
	var faction = null
	if (Global.factions.has(data.faction)):
		faction = Global.factions[data.faction]
	$TileInfo/FactionLabel.text = "No Control" if faction == null else faction.fullName
	$TileInfo/Flag.texture = null if faction == null else faction.flag
	$TileInfo/MoveCostLabel.text = "Movement cost: %s" % data.movementCost

	if (data.unit != null):
		setUnitInfo(data.unit)
	else:
		$UnitInfo.visible = false
		
func setUnitInfo(unit:Unit) -> void:
	$UnitInfo.visible = true
	$UnitInfo/UnitTypeLabel.text = unit.type.name
	$UnitInfo/HealthBar.value = unit.hp
	var healthPercentage:float = unit.hp / 100.0
	$UnitInfo/HealthBar.modulate = Color(1 - healthPercentage, healthPercentage, 0)
	$UnitInfo/MovementLabel.text = "Movement: %s" % unit.movePoints

func setPlayerInfo() -> void:
	$TopPanel/NameLabel.text = Global.factions[Global.currentPlayer].fullName
	$TopPanel/Flag.texture = Global.factions[Global.currentPlayer].flag
	$TopPanel/TurnLabel.text = "Turn: %d" % (Global.turn / 4)
	$TopPanel/TurnsUntilReinforceLabel.text = "Turns until reinforcement: %d" % (10 - ((Global.turn / 4) % 10))


func _on_map_next_turn() -> void:
	setPlayerInfo()
