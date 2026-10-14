extends Node2D

signal hover_data(data:CellData)
signal combat_panel_data(data:CombatData)
signal unit_info_data(data:Unit)
signal update_top_panel()
signal set_reinforcement_ui(active:bool)
signal set_reinforcement_count_ui(num:int)
signal next_turn()

enum {PLAY_MODE, REINFORCEMENT_MODE, MULTI_MOVE}

var inputMode = PLAY_MODE
var hoveredCell = Vector2i()
var clickedCell = Vector2i()
#Used for click-and-drag
var clickedWorldPos = Vector2()
var hoveredWorldPos = Vector2()
var selectedUnitPositions:Dictionary
var selectedUnitMidpoint:Vector2i
var selectedUnitRelativePositions:Dictionary

var hoverPath = []
var selectedUnit:Unit
var selectedUnitRange:Dictionary
var selectedUnitType:UnitType
var reinforcementCount:int = 0
var highlightDirty = true
var currentHighlights:Dictionary = {} # Vector2i cell -> Vector2i(source, alternative) on the Highlight layer
var pendingHighlights:Dictionary = {}
var lastEliminatedHumanFaction:int = -1
@export var unitScene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready():
	initMapData()
	initHighlightCells()
	initFactionControl()
	initPathfinding()
	initUnits()
	$HUD/GameEndScreen.spectate_pressed.connect(_on_game_end_screen_spectate_pressed)
	Global.currentPlayerIterator = Global.factionsList.size() - 1
	nextTurn()
	Global.intraTurnCounter = 0
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if (Input.is_action_pressed("next_turn") and not $HUD/GameEndScreen.visible):
		nextTurn()

	if highlightDirty:
		highlightDirty = false
		getHoverPath()
		doHighlight()

# Highlights are only recalculated on frames where something that affects them has changed
func queueHighlightRefresh():
	highlightDirty = true

func doHighlight():
	pendingHighlights = {}
	if not Global.spectatorTurn:
		highlightLostTiles()
	if (clickedCell != null):
		doClickedHighlight(clickedCell)
	highlightUnitMultiSelect()
	highlightMoveRange()
	if (selectedUnit != null or (selectedUnit == null and Global.cellContainsFriendlyUnit(hoveredCell))):
		var unit = selectedUnit if selectedUnit != null else Global.mapData[hoveredCell].unit
		doPathHighlight(unit)
	if (selectedUnit != null or selectedUnitRelativePositions.size() > 0):
		doHoverPathHighlight()
	if inputMode == REINFORCEMENT_MODE:
		highlightReinforcementPlacementRange(Global.factions[Global.currentPlayer])
	setHighlight(hoveredCell, 0)
	applyHighlights()

# Later calls override earlier ones for the same cell, like set_cell would
func setHighlight(cell:Vector2i, alternative:int, source:int = 0):
	pendingHighlights[cell] = Vector2i(source, alternative)

# Only touch the cells whose highlight differs from what is currently drawn
func applyHighlights():
	var highlightLayer:TileMapLayer = $MapContainer/Map/Highlight
	for cell in currentHighlights:
		if not pendingHighlights.has(cell):
			highlightLayer.erase_cell(cell)
	for cell in pendingHighlights:
		var tile:Vector2i = pendingHighlights[cell]
		if not currentHighlights.has(cell) or currentHighlights[cell] != tile:
			highlightLayer.set_cell(cell, tile.x, Vector2i(0,0), tile.y)
	currentHighlights = pendingHighlights

func highlightLostTiles():
	for tile in Global.factions[Global.currentPlayer].tilesLostLastTurn:
		setHighlight(tile, 4)


func doClickedHighlight(pos_clicked):
	setHighlight(pos_clicked, 1)
	
func doPathHighlight(unit:Unit):
	for cell in unit.movePath:
		setHighlight(cell, 3)
	
func doHoverPathHighlight():
	for cell in hoverPath:
		setHighlight(cell, 0, 1)

		
func highlightMoveRange():
	for cell in selectedUnitRange.keys():
		if (Global.cellContainsEnemyUnit(cell) and $MapContainer/Map/FOW.get_cell_tile_data(cell) == null):
			setHighlight(cell, 2)
		else:
			setHighlight(cell, 1)

func highlightReinforcementPlacementRange(faction:Faction):
	for cell in faction.importantTiles:
		if Global.mapData[cell].unit == null:
			setHighlight(cell, 3)
		for neighbor in Global.hgh.getNeighbors(cell):
			if Global.mapData[neighbor].unit == null and Global.mapData[neighbor].faction == Global.currentPlayer:
				setHighlight(neighbor, 3)
				
				
func highlightUnitMultiSelect():
	for position in selectedUnitPositions:
		doClickedHighlight(selectedUnitPositions[position].position)
		
func getHoverPath():
	if (inputMode == PLAY_MODE and selectedUnit != null and Global.mapData.has(hoveredCell) 
		and (hoverPath.size() == 0 or (hoverPath.size() > 0 and hoverPath[hoverPath.size() - 1] != hoveredCell))):
		hoverPath = Global.hgh.getPath(selectedUnit.position, hoveredCell, true)
	elif (inputMode == MULTI_MOVE and Global.mapData.has(hoveredCell)):
		hoverPath = getMultiHoverPath()

func getMultiHoverPath():
	var path = []
	for item in selectedUnitRelativePositions:
		var endpoint = hoveredCell + item
		var beginPoint = selectedUnitMidpoint + item
		path += Global.hgh.getPath(beginPoint, endpoint, true)
	return path
	

func determineUnitMultiSelect():
	for unitPosition in Global.factions[Global.currentPlayer].unitPositions:
		var unitGlobalPosition = $MapContainer/Map/Terrain.map_to_local(unitPosition)
		if $SelectBox.get_global_rect().has_point(unitGlobalPosition):
			selectedUnitPositions[unitPosition] = Global.mapData[unitPosition].unit
		else:
			selectedUnitPositions.erase(unitPosition)

func selectUnit(pos_clicked):
	if (Global.mapData.has(pos_clicked) and Global.mapData[pos_clicked].unit != null):
		var unit = Global.mapData[pos_clicked].unit
		if (unit.faction == Global.currentPlayer and unit.movePoints > 0):
			selectedUnit = unit
			selectedUnitRange = getMoveRange(pos_clicked, selectedUnit.movePoints)
		
func clickMove(unitPosition:Vector2i, pos_clicked:Vector2i):
	var path = Global.hgh.getPath(unitPosition, pos_clicked, true)
	if (path.is_empty()):
		return
	var endPoint = path[path.size() - 1] #Last cell might not be the clicked cell
	var start = unitPosition
	#path = path.slice(1) #remove the first cell because we don't want to use it in movement
	Global.mapData[unitPosition].unit.movePath = path
	moveUnit(Global.mapData[unitPosition].unit, start)
	unit_info_data.emit(Global.mapData[endPoint].unit)

func moveUnit(unit:Unit, start:Vector2i):
	var mapUnitPath = []
	var remainingMovement = unit.movePoints
	var dead = false
	var canMove = true
	var combatResult = null
	while not unit.movePath.is_empty() and remainingMovement > 0:
		var cell = unit.movePath.pop_front()
		if Global.mapData[cell].unit != null:
			if Global.mapData[cell].unit.faction != unit.faction:
				#enemy unit, initiate combat
				combatResult = CombatHelper.attack(Global.mapData[unit.position], Global.mapData[cell])
				dead = combatResult.attackerDead
				canMove = combatResult.defenderDead
				remainingMovement = 0
				Global.processDeaths(combatResult)
			else:
				#this likely happens if you've autopathed multiple units and they overlap.
				#recalculate the movePath to go around.
				if not unit.movePath.is_empty():
					unit.movePath = Global.hgh.getPath(unit.position, unit.movePath.pop_back(), true)
					continue
				else:
					break
			
		if not dead and canMove:
			mapUnitPath.push_back(Global.mapData[cell].worldPos)
			remainingMovement -= Global.mapData[cell].movementCost
			Global.updateUnitPosition(unit, cell)
			updateFowAroundCell(unit.position)
			if (Global.mapData[cell].faction != unit.faction):
				takeEnemyTerritory(cell, unit)
			if (remainingMovement <= 0 or unit.movePath.is_empty()):
				break
		else:
			break
	if not dead:
		Global.mapUnits[unit.mapUnitId].startMove(mapUnitPath)
		if (remainingMovement <= 0):
			Global.mapUnits[unit.mapUnitId].setMovementIndicatorEmpty(true)
		unit.movePoints = remainingMovement if remainingMovement >= 0 else 0

func takeEnemyTerritory(unitCell:Vector2i, unit:Unit) -> void:
	var faction = Global.factions[unit.faction]
	var cells = Global.hgh.getNeighbors(unitCell)
	cells.push_back(unitCell)
	for cell in cells:
		if (cell == unitCell or Global.mapData[cell].unit == null):
			captureCell(cell, unit.faction)

func captureCell(cellId:Vector2i, toFaction:int) -> void:
	var mapCell = Global.mapData[cellId]
	if mapCell.important:
		print("Important tile taken: ", mapCell.pos)
		Global.factions[mapCell.faction].importantTiles.erase(mapCell.pos)
		Global.factions[toFaction].importantTiles[mapCell.pos] = true
		update_top_panel.emit()
	if (mapCell.faction != toFaction):
		Global.factions[mapCell.faction].tilesLostLastTurn[mapCell.pos] = true
		Global.factions[toFaction].controlledTiles[mapCell.pos] = true
		Global.factions[mapCell.faction].controlledTiles.erase(mapCell.pos)
	mapCell.faction = toFaction
	$MapContainer/Map/FactionControl.set_cell(cellId, 1, Vector2i(0,0), toFaction)
	$MapContainer/Map/FOW.set_cell(cellId, -1)
		
			
func updateFowAroundCell(cell:Vector2i):
	for outerCell in Global.hgh.getNeighbors(cell):
		if (Global.humanPlayers.has(Global.currentPlayer)):
			$MapContainer/Map/FOW.set_cell(outerCell, -1)
		Global.factions[Global.currentPlayer].visibleTiles[outerCell] = true
		if Global.mapData[outerCell].unit != null:
			setUnitVisible(outerCell, true)

func getMoveRange(start:Vector2i, range:int) -> Dictionary:
	var frontier = PriorityQueue.new()
	frontier.put(start, 0)
	var came_from:Dictionary
	var cost_so_far:Dictionary
	came_from[start] = null
	cost_so_far[start] = 0
	var current:Vector2i
	
	while not frontier.empty():
		current = frontier.extract()
		if (Global.cellContainsEnemyUnit(current) or cost_so_far[current] >= range):
			continue
		var neighbors = Global.hgh.getNeighbors(current)
		for next in neighbors:
			if (not Global.mapData.has(next)):
				continue
			var new_cost = cost_so_far[current] + Global.mapData[next].movementCost
			if (not cost_so_far.has(next) and not Global.cellContainsFriendlyUnit(next)) or (cost_so_far.has(next) and new_cost < cost_so_far[next]):
				cost_so_far[next] = new_cost
				frontier.put(next, new_cost)
				came_from[next] = current
	return came_from
	
func initUnits():
	var unitPositions = $MapContainer/Map/CombatUnitInit.get_used_cells()
	for pos in unitPositions:
		if Global.mapData.has(pos):
			var unitTypeName = $MapContainer/Map/CombatUnitInit.get_cell_tile_data(pos).get_custom_data("type")
			createNewUnit(pos, Global.unitTypes[unitTypeName])
	$MapContainer/Map/CombatUnitInit.clear()
	
func createNewUnit(pos:Vector2i, type:UnitType):
	var mapPos = $MapContainer/Map/Terrain.map_to_local(pos)
	var mapUnit = unitScene.instantiate()
	var unit = Unit.new()
	unit.type = type
	unit.position = pos
	unit.hp = unit.type.hp
	unit.movePoints = unit.type.movementPoints
	unit.faction = getFactionAtPos(pos)
	Global.factions[unit.faction].unitPositions[pos] = true
	mapUnit.position = mapPos
	mapUnit.mapPosition = pos
	mapUnit.setInfo(Global.factions[unit.faction], unit.type)
	Global.mapUnits[Global.mapUnitsIncId] = mapUnit
	unit.mapUnitId = Global.mapUnitsIncId
	Global.mapUnitsIncId += 1
	Global.mapData[pos].unit = unit
	Global.hgh.setCellOccupied(pos, true)
	add_child(mapUnit)
	
func initHighlightCells():
	#Add an alternative tile to the highlight layer for each item in the cellHighlightColors array
	MapLoadHelper.init_highlight_tiles($MapContainer/Map/Highlight, Global.cellHighlightColors)

func initMapData():
	var map := MapLoadHelper.instantiate_map()
	$MapContainer.add_child(map)
	MapLoadHelper.init_faction_tiles(map.get_node("FactionControl"), Global.mapFactionEntries)
	MapLoadHelper.init_unit_tiles(map.get_node("CombatUnitInit"), Global.mapUnitEntries)
	MapLoadHelper.apply_map_data(map, Global.mapEntries)
	for cell in $MapContainer/Map/Terrain.get_used_cells():
		var cellData = CellData.new()
		cellData.pos = cell
		cellData.worldPos = $MapContainer/Map/Terrain.map_to_local(cell)
		cellData.terrain = getTerrainAtPos(cell)
		cellData.feature = getFeatureAtPos(cell)
		cellData.movementCost = cellData.terrain.movement_cost + cellData.feature.movement_cost
		cellData.important = $MapContainer/Map/Important.get_cell_tile_data(cell) != null
		Global.numImportantTiles += 1 if cellData.important else 0
		if Global.specialNames.has(cell):
			cellData.specialName = Global.specialNames[cell]
		Global.mapData[cell] = cellData
	

func initFactionControl():
	var cells = $MapContainer/Map/FactionControl.get_used_cells()
	for pos in cells:
		var cell = $MapContainer/Map/FactionControl.get_cell_tile_data(pos)
		if ($MapContainer/Map/Terrain.get_cell_tile_data(pos) == null):
			$MapContainer/Map/FactionControl.set_cell(pos, -1)
		else:
			var faction = getFactionAtPos(pos)
			cell.modulate = Global.factions[faction].color
			Global.mapData[pos].faction = faction
			Global.factions[faction].controlledTiles[pos] = true
			if Global.mapData[pos].important:
				Global.factions[faction].importantTiles[pos] = true

	for factionId in Global.factions:
		if (factionId == 0):
			continue
		var faction = Global.factions[factionId]
		if (faction.importantTiles.size() > 0):
			Global.factionsList.append(factionId)

			
func getFactionAtPos(pos):
	var tileData = $MapContainer/Map/FactionControl.get_cell_tile_data(pos)
	return 0 if tileData == null else tileData.get_custom_data("factionId")
	
func getTerrainAtPos(pos):
	var tileData = $MapContainer/Map/Terrain.get_cell_tile_data(pos)
	var tileType = tileData.get_custom_data("name")
	return Global.terrain["NONE"] if tileData == null else Global.terrain[tileType]
	
func getFeatureAtPos(pos):
	var tileData = $MapContainer/Map/Features.get_cell_tile_data(pos)
	return Global.terrain["NONE"] if tileData == null else Global.terrain[tileData.get_custom_data("name")]
	
func clearHighlights():
	clickedCell = null
	selectedUnit = null
	selectedUnitRange.clear()
	hoverPath = []
	
func initPathfinding():
	Global.hgh = HGH.new()
	Global.hgh.setMapData(Global.mapData)
	Global.hgh.initMap()
	
func nextTurnFogOfWar(player:int):
	if Global.spectatorTurn:
		revealAll()
		return
	var playerIsHuman:bool = Global.humanPlayers.has(player)
	for tile in Global.mapData:
		var cell = Global.mapData[tile]
		if cell.faction != player:
			Global.factions[player].visibleTiles.erase(cell.pos)
			if playerIsHuman:
				$MapContainer/Map/FOW.set_cell(cell.pos, 0, Vector2i(0,0))
			if cell.unit != null:
				setUnitVisible(cell.pos, false)
		else:
			Global.factions[player].visibleTiles[cell.pos] = true
			if playerIsHuman:
				$MapContainer/Map/FOW.set_cell(cell.pos, -1)
			if cell.unit != null:
				setUnitVisible(cell.pos, true)
				
	for unitPos in Global.factions[player].unitPositions:
		var unit = Global.mapData[unitPos].unit
		for innerCell in Global.hgh.getNeighbors(unit.position):
			for outerCell in Global.hgh.getNeighbors(innerCell):
				Global.factions[player].visibleTiles[outerCell] = true
				if playerIsHuman:
					$MapContainer/Map/FOW.set_cell(outerCell, -1)
				if Global.mapData[outerCell].unit != null:
					setUnitVisible(outerCell, true)

func revealAll():
	print("revealall")
	for cellId in Global.mapData.keys():
		var cell = Global.mapData[cellId]
		Global.factions[Global.currentPlayer].visibleTiles[cellId] = true
		$MapContainer/Map/FOW.set_cell(cellId, -1)
		if cell.unit != null:
			setUnitVisible(cellId, true)
					
func setUnitVisible(cell:Vector2i, _visible:bool):
	var cellData = Global.mapData[cell]
	if Global.humanPlayers.has(Global.currentPlayer) or Global.spectatorMode:
		Global.mapUnits[cellData.unit.mapUnitId].visible = _visible
	Global.hgh.setCellOccupied(cell, _visible)

func getUnitVisible(cell:Vector2i):
	return Global.mapData.has(cell) and Global.mapData[cell].unit != null and Global.factions[Global.currentPlayer].visibleTiles.has(cell)

func nextTurnUnitSetup(player:int):
	for id in Global.mapUnits:
		var cell = Global.mapUnits[id].mapPosition
		var unit = Global.mapData[cell].unit
		if (not unit):
			print("NULL UNIT: Cell: %s, Player: %s" % [cell, Global.currentPlayer])
			continue
		if unit.faction == player:
			unit.movePoints = unit.type.movementPoints
			unit.hp = min(unit.hp + 10, unit.type.hp)
			Global.mapUnits[id].setMovementIndicatorVisible(true)
			Global.mapUnits[id].setMovementIndicatorEmpty(false)
		else:
			Global.mapUnits[id].setMovementIndicatorVisible(false)

func doAITurn():
	if (inputMode == REINFORCEMENT_MODE):
		var unitsToCreate:Array = AIManager.placeReinforcements(Global.factions[Global.currentPlayer])
		for unitDefinition in unitsToCreate:
			createNewUnit(unitDefinition.position, unitDefinition.type)
	else:
		var start_time = Time.get_ticks_msec()
		var tasks:Array = AIManager.gatherTasks(Global.factions[Global.currentPlayer])
		var assignments:Array = AIManager.gatherAssignments(tasks, Global.factions[Global.currentPlayer])
		var assignedTasks:Array = AIManager.assignTasks(assignments)
		for assignedTask in assignedTasks:
			var taskPosition = assignedTask.task.target
			var unitPosition = assignedTask.unit
			clickMove(unitPosition, taskPosition)
		var end_time = Time.get_ticks_msec()
		print("AI turn for %s took %s ms" % [Global.factions[Global.currentPlayer].fullName, end_time - start_time])

	nextTurn()

func nextTurn():
	queueHighlightRefresh()
	nextTurnEndOfTurnActions()
	nextTurnStartOfTurnActions()

func nextTurnEndOfTurnActions():
	if not Global.spectatorTurn:
		if (inputMode == MULTI_MOVE):
			exitMultiMoveMode()
		if inputMode == PLAY_MODE:
			for cell in Global.factions[Global.currentPlayer].unitPositions.keys():
				var unit = Global.mapData[cell].unit
				if not unit.movePath.is_empty():
					moveUnit(unit, unit.position)
		
			Global.intraTurnCounter += 1
			if (Global.intraTurnCounter >= Global.factionsList.size()):
				Global.turnsUntilReinforcement -= 1
				Global.turn += 1
				Global.intraTurnCounter = 0
		elif inputMode == REINFORCEMENT_MODE:
			Global.reinforcementModeCounter += 1
			
			if Global.reinforcementModeCounter >= Global.factionsList.size():
				inputMode = PLAY_MODE
				set_reinforcement_ui.emit(false)
				Global.reinforcementModeCounter = 0
				Global.turnsUntilReinforcement = 10
				selectedUnitType = null

	Global.factions[Global.currentPlayer].tilesLostLastTurn.clear()
	Global.factions[Global.currentPlayer].visibleTiles.clear()
	# Remove faction if it has no important tiles left
	if not Global.spectatorTurn and Global.factions[Global.currentPlayer].importantTiles.size() == 0:
		removeFaction()

func nextTurnStartOfTurnActions():
	Global.currentPlayer = Global.getNextFactionId()
	var currentFaction = Global.factions[Global.currentPlayer]
	
	if inputMode == REINFORCEMENT_MODE:
		reinforcementCount = Global.getReinforcementCount()
		set_reinforcement_count_ui.emit(reinforcementCount)

	removeTerritoryPockets()
	currentFaction.numControlledTilesPerTurn.append(currentFaction.controlledTiles.size())

	nextTurnFogOfWar(Global.currentPlayer)
	nextTurnUnitSetup(Global.currentPlayer)
	clearHighlights()
	
	if inputMode == PLAY_MODE and Global.turnsUntilReinforcement == 0:
		inputMode = REINFORCEMENT_MODE
		set_reinforcement_ui.emit(true)
		reinforcementCount = Global.getReinforcementCount()
		set_reinforcement_count_ui.emit(reinforcementCount)
	next_turn.emit()

	if checkGameOver():
		return

	elif (!Global.humanPlayers.has(Global.currentPlayer) and not Global.spectatorTurn):
		doAITurn()

# Shows the game end screen and returns true if the game should stop advancing turns
func checkGameOver() -> bool:
	var endScreen = $HUD/GameEndScreen
	if Global.factionsList.size() <= 1:
		var winnerId = Global.factionsList[0] if Global.factionsList.size() == 1 else -1
		var victory = Global.humanPlayers.has(winnerId)
		print("Game over. Winner: %s" % (Global.factions[winnerId].fullName if winnerId != -1 else "None"))
		endScreen.showResult(victory, Global.factions[winnerId] if victory else getLastEliminatedHumanFaction(), false)
		return true
	if not Global.spectatorMode and checkAllHumanPlayersDead():
		print("All human players are dead. Game over.")
		Global.spectatorMode = true
		endScreen.showResult(false, getLastEliminatedHumanFaction(), true)
		return true
	return false

func getLastEliminatedHumanFaction() -> Faction:
	return Global.factions.get(lastEliminatedHumanFaction)

func _on_game_end_screen_spectate_pressed() -> void:
	# The turn that was interrupted by the end screen belongs to an AI, so let it play
	doAITurn()

func checkAllHumanPlayersDead():
	var allDead = true
	for faction in Global.factionsList:
		if Global.humanPlayers.has(faction):
			allDead = false
			break
	return allDead

func removeFaction():
	if Global.humanPlayers.has(Global.currentPlayer):
		lastEliminatedHumanFaction = Global.currentPlayer
	#Clear faction units
	for unitPos in Global.factions[Global.currentPlayer].unitPositions.keys():
		var unit = Global.mapData[unitPos].unit
		if unit != null:
			Global.factions[Global.currentPlayer].unitPositions.erase(unitPos)
			Global.mapUnits[unit.mapUnitId].destroySelf()
			Global.mapUnits.erase(unit.mapUnitId)
			Global.hgh.setCellOccupied(unitPos, false)
			Global.mapData[unitPos].unit = null
	#Clear faction tile ownership
	for tile in Global.mapData.keys():
		if Global.mapData[tile].faction == Global.currentPlayer:
			Global.mapData[tile].faction = 0
			$MapContainer/Map/FactionControl.set_cell(tile, -1)
	# Remove faction from the list and step the turn iterator back so the next faction isn't skipped
	var removedIndex = Global.factionsList.find(Global.currentPlayer)
	if removedIndex != -1:
		Global.factionsList.remove_at(removedIndex)
		Global.currentPlayerIterator = removedIndex - 1

func removeTerritoryPockets():
	#Breadth first search
	# Remove any territory pockets that are not connected to an important tile
	var importantTiles = Global.factions[Global.currentPlayer].importantTiles.keys()
	var visited:Dictionary = {}
	for importantTile in importantTiles:
		if visited.has(importantTile):
			continue
		visited[importantTile] = true
		var queue:Array = Global.hgh.getNeighbors(importantTile)
		while not queue.is_empty():
			var tile = queue.pop_front()
			if not Global.mapData.has(tile) or Global.mapData[tile].faction != Global.currentPlayer or visited.has(tile):
				continue
			visited[tile] = true
			queue += Global.hgh.getNeighbors(tile)

	for tile in Global.factions[Global.currentPlayer].controlledTiles.keys():
		if not visited.has(tile):
			captureCell(tile, 0)  # Capture the tile for the neutral faction

func activateSelectBox():
	$SelectBox.visible = true
	clearHighlights()
	
func enableSelectedUnitMovement():
	$SelectBox.visible = false
	if selectedUnitPositions.size() > 0:
		selectedUnitMidpoint = Global.hgh.calculateMidpointOfCells(selectedUnitPositions)
		selectedUnitRelativePositions = calculateRelativeHexPositions(selectedUnitMidpoint, selectedUnitPositions)
		inputMode = MULTI_MOVE
	
func calculateRelativeHexPositions(midpoint:Vector2i, list:Dictionary):
	var relativeList:Dictionary
	for item in list:
		var relativePosition = item - midpoint
		relativeList[relativePosition] = true
	return relativeList

func performMultiMove(pos_clicked:Vector2i):
	for item in selectedUnitRelativePositions:
		var from = item + selectedUnitMidpoint
		var to = item + pos_clicked
		clickMove(from, to)
	exitMultiMoveMode()
	
func exitMultiMoveMode():
	inputMode = PLAY_MODE
	selectedUnitRelativePositions.clear()
	selectedUnitPositions.clear()

func _input(event):
	if $HUD/GameEndScreen.visible:
		return
	if event is InputEventMouseMotion:
		var global_pos = get_global_mouse_position()
		hoveredWorldPos = global_pos
		if hoveredWorldPos.distance_to(clickedWorldPos) > 100 and Input.is_action_pressed("left_click") and inputMode == PLAY_MODE:
			activateSelectBox()
		var pos_hovered = $MapContainer/Map/Terrain.local_to_map(global_pos)
		if hoveredCell != pos_hovered:
			if (Global.mapData.has(pos_hovered)):
				hover_data.emit(Global.mapData[pos_hovered])
				if (Global.mapData[pos_hovered].unit != null and getUnitVisible(pos_hovered)):
					unit_info_data.emit(Global.mapData[pos_hovered].unit)
				else:
					unit_info_data.emit(null)
				if (selectedUnit != null and Global.cellContainsEnemyUnit(pos_hovered) and getUnitVisible(pos_hovered)):
					var combatData = CombatHelper.getCombatData(Global.mapData[selectedUnit.position], Global.mapData[pos_hovered])
					combat_panel_data.emit(combatData)
				else:
					combat_panel_data.emit(null)
			else:
				hover_data.emit(Global.getEmptyCell(pos_hovered))
				combat_panel_data.emit(null)
			hoveredCell = pos_hovered
			queueHighlightRefresh()
		if $SelectBox.visible:
			$SelectBox.size = hoveredWorldPos - clickedWorldPos
			determineUnitMultiSelect()
			queueHighlightRefresh()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_released() and $SelectBox.visible:
			enableSelectedUnitMovement()
			queueHighlightRefresh()
			

func _on_button_pressed() -> void:
	$MapContainer/Map/FactionControl.visible = !$MapContainer/Map/FactionControl.visible

func _on_click_handler_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		queueHighlightRefresh()
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			clickedWorldPos = get_global_mouse_position()
			$SelectBox.position = clickedWorldPos
			hoverPath = []
			var global_clicked = get_global_mouse_position()
			var pos_clicked = $MapContainer/Map/Terrain.local_to_map(global_clicked)
			clickedCell = pos_clicked
			if (Global.mapData.has(pos_clicked)):
				if inputMode == PLAY_MODE:
					if (selectedUnit != null and not Global.cellContainsFriendlyUnit(pos_clicked)):
						clickMove(selectedUnit.position, pos_clicked)
						clearHighlights()
					else:
						selectUnit(pos_clicked)
				elif inputMode == REINFORCEMENT_MODE:
					if selectedUnitType != null and getFactionAtPos(pos_clicked) == Global.currentPlayer and not Global.cellContainsFriendlyUnit(pos_clicked) and reinforcementCount > 0 and Global.cellAroundImportantTile(pos_clicked):
						createNewUnit(pos_clicked, selectedUnitType)
						reinforcementCount -= 1
						set_reinforcement_count_ui.emit(reinforcementCount)
				elif inputMode == MULTI_MOVE:
					performMultiMove(pos_clicked)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
			clearHighlights()
			$SelectBox.visible = false
			if inputMode == MULTI_MOVE:
				exitMultiMoveMode()

func _on_set_selected_unit(type:UnitType):
	selectedUnitType = type

func _on_button_2_pressed() -> void:
	nextTurn()
