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

	
func _on_map_unit_info_data(data: Unit) -> void:
	setUnitInfo(data)
		
func setUnitInfo(unit:Unit) -> void:
	if (unit == null):
		$UnitInfo.visible = false
	else:
		$UnitInfo.visible = true
		$UnitInfo/UnitTypeLabel.text = unit.type.name
		setHealthBar($UnitInfo/HealthBar, unit.hp)
		$UnitInfo/MovementLabel.text = "Movement: %s" % unit.movePoints

func setPlayerInfo() -> void:
	$TopPanel/NameLabel.text = Global.factions[Global.currentPlayer].fullName
	$TopPanel/Flag.texture = Global.factions[Global.currentPlayer].flag
	$TopPanel/TurnLabel.text = "Turn: %d" % (Global.turn / 4)
	$TopPanel/TurnsUntilReinforceLabel.text = "Turns until reinforcement: %d" % (10 - ((Global.turn / 4) % 10))


func _on_map_next_turn() -> void:
	setPlayerInfo()


func _on_map_combat_panel_data(data: CombatData) -> void:
	if data == null:
		$CombatPanel.visible = false
	else:
		$CombatPanel.visible = true
		var attackerUnit:Unit = data.attackerCell.unit
		var defenderUnit:Unit = data.defenderCell.unit
		var attackerFaction:Faction = Global.factions[attackerUnit.faction]
		var defenderFaction:Faction = Global.factions[defenderUnit.faction]
		$CombatPanel/AttackerFlag.texture = attackerFaction.flag
		$CombatPanel/DefenderFlag.texture = defenderFaction.flag
		$CombatPanel/AttackerLabel.text = attackerUnit.type.name
		$CombatPanel/DefenderLabel.text = defenderUnit.type.name
		setHealthBar($CombatPanel/AttackerHealthBarHigh, attackerUnit.hp - data.attackerMinDamage)
		setHealthBar($CombatPanel/AttackerHealthBarLow, attackerUnit.hp - data.attackerMaxDamage)
		$CombatPanel/AttackerDamageLabel.text = "%d - %d" % [data.attackerMinDamage, data.attackerMaxDamage]
		setHealthBar($CombatPanel/DefenderHealthBarHigh, defenderUnit.hp - data.defenderMinDamage)
		setHealthBar($CombatPanel/DefenderHealthBarLow, defenderUnit.hp - data.defenderMaxDamage)
		$CombatPanel/DefenderDamageLabel.text = "%d - %d" % [data.defenderMinDamage, data.defenderMaxDamage]
		
		$CombatPanel/AdvantageLabel.visible = true
		if attackerUnit.hasAdvantageAgainst(defenderUnit):
			$CombatPanel/AdvantageLabel.text = "ADVANTAGE"
			$CombatPanel/AdvantageLabel.modulate = Color(0,1,0)
		elif defenderUnit.hasAdvantageAgainst(attackerUnit):
			$CombatPanel/AdvantageLabel.text = "DISADVANTAGE"
			$CombatPanel/AdvantageLabel.modulate = Color(1,0,0)
		else:
			$CombatPanel/AdvantageLabel.visible = false
		
func setHealthBar(bar:ProgressBar, value:float):
	var healthPercentage = value / 100.0
	bar.modulate = Color(1 - healthPercentage, healthPercentage, 0)
	bar.value = value
