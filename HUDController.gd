extends CanvasLayer

var reinforcementButtonScene = preload("res://reinforcement_button.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	setPlayerInfo()
	generateReinforcementButtons()

func setUnitInfo(unit:Unit) -> void:
	if (unit == null):
		$UnitInfo.visible = false
	else:
		$UnitInfo.visible = true
		$UnitInfo/UnitTypeLabel.text = unit.type.uiName
		setHealthBar($UnitInfo/HealthBar, unit.hp)
		$UnitInfo/MovementLabel.text = "Movement: %s" % unit.movePoints

func setPlayerInfo() -> void:
	$TopPanel/NameLabel.text = Global.factions[Global.currentPlayer].fullName
	$TopPanel/Flag.texture = Global.factions[Global.currentPlayer].flag
	$TopPanel/TurnLabel.text = "Turn: %d" % (Global.turn)
	$TopPanel/TurnsUntilReinforceLabel.text = "Turns until reinforcement: %d" % Global.turnsUntilReinforcement
	updateTopPanel()

func setHealthBar(bar:ProgressBar, value:float):
	var healthPercentage = value / 100.0
	bar.modulate = Color(1 - healthPercentage, healthPercentage, 0)
	bar.value = value

func generateReinforcementButtons():
	var rootNode = get_node("/root/Root")
	for unitType in Global.unitTypes:
		var type = Global.unitTypes[unitType]
		var button = reinforcementButtonScene.instantiate()
		button.unitType = type
		button.icon = type.sprite
		button.set_selected_unit.connect(rootNode._on_set_selected_unit.bind())
		$ReinforcementUI/ButtonAnchor.add_child(button)

func updateTopPanel():
	$TopPanelExtra/ImportantLabel.text = "Important Tiles: %d" % Global.factions[Global.currentPlayer].importantTiles.size()

# =========================================================
# Signals
# =========================================================
func _on_root_hover_data(data:CellData) -> void:
	$TileInfo/PosLabel.text = str(data.pos) + str(Global.hgh.getAStarCellId(data.pos))
	if (data.specialName != null or data.specialName != ""):
		$TileInfo/TerrainLabel.text =  "%s (%s, %s)" % [data.specialName, data.terrain.in_game_name, data.feature.in_game_name]
	else:
		$TileInfo/TerrainLabel.text =  "%s, %s" % [data.terrain.in_game_name, data.feature.in_game_name]
	if data.important == true:
		$TileInfo/TerrainLabel.text += ", Important"
	var faction = null
	if (Global.factions.has(data.faction)):
		faction = Global.factions[data.faction]
	$TileInfo/FactionLabel.text = "No Control" if faction == null else faction.fullName
	$TileInfo/Flag.texture = null if faction == null else faction.flag
	$TileInfo/MoveCostLabel.text = "Movement cost: %s" % data.movementCost

func _on_root_unit_info_data(data: Unit) -> void:
	setUnitInfo(data)

func _on_root_next_turn() -> void:
	setPlayerInfo()

func _on_root_update_top_panel() -> void:
	updateTopPanel()

func _on_root_combat_panel_data(data: CombatData) -> void:
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
		$CombatPanel/AttackerLabel.text = attackerUnit.type.uiName
		$CombatPanel/DefenderLabel.text = defenderUnit.type.uiName
		setHealthBar($CombatPanel/AttackerHealthBarHigh, attackerUnit.hp - data.attackerMinDamage)
		setHealthBar($CombatPanel/AttackerHealthBarLow, attackerUnit.hp - data.attackerMaxDamage)
		$CombatPanel/AttackerDamageLabel.text = "%d - %d" % [attackerUnit.hp - data.attackerMinDamage, attackerUnit.hp - data.attackerMaxDamage]
		setHealthBar($CombatPanel/DefenderHealthBarHigh, defenderUnit.hp - data.defenderMinDamage)
		setHealthBar($CombatPanel/DefenderHealthBarLow, defenderUnit.hp - data.defenderMaxDamage)
		$CombatPanel/DefenderDamageLabel.text = "%d - %d" % [defenderUnit.hp - data.defenderMinDamage, defenderUnit.hp - data.defenderMaxDamage]

		$CombatPanel/AdvantageLabel.visible = true
		if attackerUnit.hasAdvantageAgainst(defenderUnit):
			$CombatPanel/AdvantageLabel.text = "ADVANTAGE"
			$CombatPanel/AdvantageLabel.modulate = Color(0,1,0)
		elif defenderUnit.hasAdvantageAgainst(attackerUnit):
			$CombatPanel/AdvantageLabel.text = "DISADVANTAGE"
			$CombatPanel/AdvantageLabel.modulate = Color(1,0,0)
		else:
			$CombatPanel/AdvantageLabel.visible = false

func _on_root_set_reinforcement_ui(active: bool) -> void:
	$ReinforcementUI.visible = active

func _on_root_set_reinforcement_count_ui(num: int) -> void:
	$ReinforcementUI/ReinforcementLabel.text = "REINFORCEMENTS: %d" % num
