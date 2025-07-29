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
@export var unitScene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready():
	initMapData()
	initFactionControl()
	initPathfinding()
	initUnits()
	#nextTurnFogOfWar(Global.currentPlayer)
	#nextTurnUnitSetup(Global.currentPlayer)
	Global.currentPlayerIterator = Global.factionsList.size() - 1
	nextTurn()
	Global.intraTurnCounter = 0
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	getHoverPath()
	doHighlight()

func doHighlight():
	$MapContainer/Map/Highlight.clear()
	if (clickedCell != null):
		doClickedHighlight(clickedCell)
	highlightUnitMultiSelect()
	highlightMoveRange()
	if (selectedUnit != null or (selectedUnit == null and cellContainsFriendlyUnit(hoveredCell))):
		var unit = selectedUnit if selectedUnit != null else Global.mapData[hoveredCell].unit
		doPathHighlight(unit)
	if (selectedUnit != null or selectedUnitRelativePositions.size() > 0):
		doHoverPathHighlight()
	if inputMode == REINFORCEMENT_MODE:
		highlightReinforcementPlacementRange(Global.factions[Global.currentPlayer])
	$MapContainer/Map/Highlight.set_cell(hoveredCell, 0, Vector2(0,0))
		
func doClickedHighlight(pos_clicked):
	#if clickedCell != null:
		#$MapContainer/Map/Highlight.set_cell(clickedCell, -1)
	$MapContainer/Map/Highlight.set_cell(pos_clicked, 0, Vector2i(0,0), 1)
	#clickedCell = pos_clicked
	
func doPathHighlight(unit:Unit):
	for cell in unit.movePath:
		$MapContainer/Map/Highlight.set_cell(cell, 0, Vector2i(0,0), 3)
	
func doHoverPathHighlight():
	for cell in hoverPath:
		$MapContainer/Map/Highlight.set_cell(cell, 1, Vector2i(0,0), 0)

		
func highlightMoveRange():
	for cell in selectedUnitRange.keys():
		if (cellContainsEnemyUnit(cell) and $MapContainer/Map/FOW.get_cell_tile_data(cell) == null):
			$MapContainer/Map/Highlight.set_cell(cell, 0, Vector2i(0,0), 2)
		else:
			$MapContainer/Map/Highlight.set_cell(cell, 0, Vector2i(0,0), 1)

func highlightReinforcementPlacementRange(faction:Faction):
	for cell in faction.importantTiles:
		if Global.mapData[cell].unit == null:
			$MapContainer/Map/Highlight.set_cell(cell, 0, Vector2i(0,0), 2)
		for neighbor in Global.hgh.getNeighbors(cell):
			if Global.mapData[neighbor].unit == null and Global.mapData[neighbor].faction == Global.currentPlayer:
				$MapContainer/Map/Highlight.set_cell(neighbor, 0, Vector2i(0,0), 2)
				
				
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
			Global.mapData[unit.position].unit = null
			Global.mapData[cell].unit = unit
			unit.position = cell
			Global.mapUnits[unit.mapUnitId].mapPosition = unit.position
			if (Global.mapData[cell].faction != unit.faction):
				takeEnemyTerritory(cell, unit)
			if (remainingMovement <= 0 or unit.movePath.is_empty()):
				break
		else:
			break
	Global.hgh.setCellOccupied(start, false)
	Global.processDeaths(combatResult)
	updateFowAroundCell(unit.position)
	Global.factions[unit.faction].unitPositions.erase(start)
	if not dead:
		if (remainingMovement <= 0):
			Global.mapUnits[unit.mapUnitId].setMovementIndicatorEmpty(true)
		unit.movePoints = remainingMovement if remainingMovement >= 0 else 0
		Global.factions[unit.faction].unitPositions[unit.position] = true
		Global.hgh.setCellOccupied(unit.position, true)
		Global.mapUnits[unit.mapUnitId].startMove(mapUnitPath)

func takeEnemyTerritory(unitCell:Vector2i, unit:Unit) -> void:
	var faction = Global.factions[unit.faction]
	var cells = Global.hgh.getNeighbors(unitCell)
	cells.push_back(unitCell)
	for cell in cells:
		if (cell == unitCell or Global.mapData[cell].unit == null):
			var mapCell = Global.mapData[cell]
			if mapCell.important:
				print("Important tile taken: ", mapCell.pos)
				Global.factions[mapCell.faction].importantTiles.erase(mapCell.pos)
				Global.factions[unit.faction].importantTiles[mapCell.pos] = true
				update_top_panel.emit()
			mapCell.faction = unit.faction
			$MapContainer/Map/FactionControl.set_cell(cell, 1, Vector2i(0,0), unit.faction)
			$MapContainer/Map/FOW.set_cell(cell, -1)
			
func updateFowAroundCell(cell:Vector2i):
	for outerCell in Global.hgh.getNeighbors(cell):
		$MapContainer/Map/FOW.set_cell(outerCell, -1)
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
		if (cellContainsEnemyUnit(current) or cost_so_far[current] >= range):
			continue
		var neighbors = Global.hgh.getNeighbors(current)
		for next in neighbors:
			if (not Global.mapData.has(next)):
				continue
			var new_cost = cost_so_far[current] + Global.mapData[next].movementCost
			if (not cost_so_far.has(next) and not cellContainsFriendlyUnit(next)) or (cost_so_far.has(next) and new_cost < cost_so_far[next]):
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
	
func initMapData():
	var scene = Global.mapScene.instantiate()
	$MapContainer.add_child(scene)
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
	return Global.terrain["NONE"] if tileData == null else Global.terrain[tileData.get_custom_data("name")]
	
func getFeatureAtPos(pos):
	var tileData = $MapContainer/Map/Features.get_cell_tile_data(pos)
	return Global.terrain["NONE"] if tileData == null else Global.terrain[tileData.get_custom_data("name")]
	
func cellContainsEnemyUnit(pos):
	return Global.mapData.has(pos) and Global.mapData[pos].unit != null and Global.mapData[pos].unit.faction != Global.currentPlayer
	
func cellContainsFriendlyUnit(pos):
	return Global.mapData.has(pos) and Global.mapData[pos].unit != null and Global.mapData[pos].unit.faction == Global.currentPlayer
	
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
	for tile in Global.mapData:
		var cell = Global.mapData[tile]
		if cell.faction != player:
			$MapContainer/Map/FOW.set_cell(cell.pos, 0, Vector2i(0,0))
			if cell.unit != null:
				setUnitVisible(cell.pos, false)
		else:
			$MapContainer/Map/FOW.set_cell(cell.pos, -1)
			if cell.unit != null:
				setUnitVisible(cell.pos, true)
				
	for unitPos in Global.factions[player].unitPositions:
		var unit = Global.mapData[unitPos].unit
		for innerCell in Global.hgh.getNeighbors(unit.position):
			for outerCell in Global.hgh.getNeighbors(innerCell):
				$MapContainer/Map/FOW.set_cell(outerCell, -1)
				if Global.mapData[outerCell].unit != null:
					setUnitVisible(outerCell, true)
					
func setUnitVisible(cell:Vector2i, visible:bool):
	var cellData = Global.mapData[cell]
	Global.mapUnits[cellData.unit.mapUnitId].visible = visible
	Global.hgh.setCellOccupied(cell, visible)
	
func getUnitVisible(cell:Vector2i):
	return Global.mapData.has(cell) and Global.mapData[cell].unit != null and $MapContainer/Map/FOW.get_cell_tile_data(cell) == null

func nextTurnUnitSetup(player:int):
	for id in Global.mapUnits:
		var cell = Global.mapUnits[id].mapPosition
		var unit = Global.mapData[cell].unit
		if unit.faction == player:
			unit.movePoints = unit.type.movementPoints
			Global.mapUnits[id].setMovementIndicatorVisible(true)
			Global.mapUnits[id].setMovementIndicatorEmpty(false)
		else:
			Global.mapUnits[id].setMovementIndicatorVisible(false)
		

func nextTurn():
	if (inputMode == MULTI_MOVE):
		exitMultiMoveMode()
	if inputMode == PLAY_MODE:
		var unitPositionsCopy = Global.factions[Global.currentPlayer].unitPositions.duplicate()
		for cell in unitPositionsCopy:
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
	Global.currentPlayer = Global.getNextFactionId()
	
	if inputMode == REINFORCEMENT_MODE:
		reinforcementCount = getReinforcementCount()
		set_reinforcement_count_ui.emit(reinforcementCount)
	nextTurnFogOfWar(Global.currentPlayer)
	nextTurnUnitSetup(Global.currentPlayer)
	clearHighlights()
	
	if inputMode == PLAY_MODE and Global.turnsUntilReinforcement == 0:
		inputMode = REINFORCEMENT_MODE
		set_reinforcement_ui.emit(true)
		reinforcementCount = getReinforcementCount()
		set_reinforcement_count_ui.emit(reinforcementCount)
	next_turn.emit()
	
#This calculation is meant to provide a slowly rising curve for reinforcement counts based on the number
#of important tiles owned by the faction. This way power doesn't linearly increase with size.
func getReinforcementCount():
	var faction:Faction = Global.factions[Global.currentPlayer]
	var e:float = 2.718281828
	return (faction.importantTiles.size() + 3)/2

func cellAroundImportantTile(cell:Vector2i):
	if Global.mapData[cell].important:
		return true
	
	for neighbor in Global.hgh.getNeighbors(cell):
		if Global.mapData[neighbor].important:
			return true
	return false

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
				if (selectedUnit != null and cellContainsEnemyUnit(pos_hovered) and getUnitVisible(pos_hovered)):
					var combatData = CombatHelper.getCombatData(Global.mapData[selectedUnit.position], Global.mapData[pos_hovered])
					combat_panel_data.emit(combatData)
				else:
					combat_panel_data.emit(null)
			else:
				hover_data.emit(Global.getEmptyCell(pos_hovered))
				combat_panel_data.emit(null)
			hoveredCell = pos_hovered
		if $SelectBox.visible:
			$SelectBox.size = hoveredWorldPos - clickedWorldPos
			determineUnitMultiSelect()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_released() and $SelectBox.visible:
			enableSelectedUnitMovement()
			

func _on_button_pressed() -> void:
	$MapContainer/Map/FactionControl.visible = !$MapContainer/Map/FactionControl.visible

func _on_click_handler_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			clickedWorldPos = get_global_mouse_position()
			$SelectBox.position = clickedWorldPos
			$MapContainer/Map/Highlight.clear()
			hoverPath = []
			var global_clicked = get_global_mouse_position()
			var pos_clicked = $MapContainer/Map/Terrain.local_to_map(global_clicked)
			clickedCell = pos_clicked
			if (Global.mapData.has(pos_clicked)):
				if inputMode == PLAY_MODE:
					if (selectedUnit != null and not cellContainsFriendlyUnit(pos_clicked)):
						clickMove(selectedUnit.position, pos_clicked)
						clearHighlights()
					else:
						selectUnit(pos_clicked)
				elif inputMode == REINFORCEMENT_MODE:
					if selectedUnitType != null and getFactionAtPos(pos_clicked) == Global.currentPlayer and not cellContainsFriendlyUnit(pos_clicked) and reinforcementCount > 0 and cellAroundImportantTile(pos_clicked):
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
