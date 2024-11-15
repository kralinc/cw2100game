extends Node2D

signal hover_data(data:CellData)
signal next_turn()

var hoveredCell = Vector2i()
var clickedCell = Vector2i()
var hoverPath = []
var selectedUnit:Unit
var selectedUnitRange:Dictionary
@export var unitScene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready():
	initMapData()
	initFactionControl()
	initPathfinding()
	initUnits()
	nextTurnFogOfWar(Global.currentPlayer)
	nextTurnUnitSetup(Global.currentPlayer)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	doHighlight()
	
func _input(event):
	if event is InputEventMouseMotion:
		var global_pos = get_global_mouse_position()
		var pos_hovered = $Terrain.local_to_map(global_pos)
		if (Global.mapData.has(pos_hovered)):
			hover_data.emit(Global.mapData[pos_hovered])
		else:
			hover_data.emit(Global.getEmptyCell(pos_hovered))
		hoveredCell = pos_hovered

func doHighlight():
	$Highlight.clear()
	if (clickedCell != null):
		doClickedHighlight(clickedCell)
	highlightMoveRange()
	if (selectedUnit != null):
		doPathHighlight()
		doHoverPathHighlight()
	$Highlight.set_cell(hoveredCell, 0, Vector2(0,0))
		
func doClickedHighlight(pos_clicked):
	$Highlight.set_cell(clickedCell, -1)
	$Highlight.set_cell(pos_clicked, 0, Vector2i(0,0), 1)
	clickedCell = pos_clicked
	
func doPathHighlight():
	for cell in selectedUnit.movePath:
		$Highlight.set_cell(cell, 0, Vector2i(0,0), 3)
	
func doHoverPathHighlight():
	if (Global.mapData.has(hoveredCell) and (hoverPath.size() == 0 or (hoverPath.size() > 0 and hoverPath[hoverPath.size() - 1] != hoveredCell))):
		hoverPath = Global.hgh.getPath(selectedUnit.position, hoveredCell, true)
	
	for cell in hoverPath:
		$Highlight.set_cell(cell, 1, Vector2i(0,0), 0)
		
		
func highlightMoveRange():
	for cell in selectedUnitRange.keys():
		if (cellContainsEnemyUnit(cell)):
			$Highlight.set_cell(cell, 0, Vector2i(0,0), 2)
		else:
			$Highlight.set_cell(cell, 0, Vector2i(0,0), 1)

func selectUnit(pos_clicked):
	if (Global.mapData.has(pos_clicked) and Global.mapData[pos_clicked].unit != null):
		var unit = Global.mapData[pos_clicked].unit
		if (unit.faction == Global.currentPlayer and unit.movePoints > 0):
			selectedUnit = unit
			selectedUnitRange = getMoveRange(pos_clicked, selectedUnit.movePoints)
		
		
func clickMove(pos_clicked):
	var path = Global.hgh.getPath(selectedUnit.position, pos_clicked, true)
	if (path.is_empty()):
		return
	var start = selectedUnit.position
	path = path.slice(1) #remove the first cell because we don't want to use it in movement
	selectedUnit.movePath = path
	moveUnit(selectedUnit, start)
	
func moveUnit(unit:Unit, start:Vector2i):
	var mapUnitPath = []
	var remainingMovement = unit.movePoints
	var dead = false
	var canMove = true
	var combatResult = null
	while not unit.movePath.is_empty():
		var cell = unit.movePath.pop_front()
		if (Global.mapData[cell].unit != null and Global.mapData[cell].unit.faction != unit.faction):
			combatResult = CombatHelper.attack(Global.mapData[unit.position], Global.mapData[cell])
			dead = combatResult.attackerDead
			canMove = combatResult.defenderDead
			remainingMovement = 0
			
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
	Global.hgh.freeCell(start)
	Global.processDeaths(combatResult)
	if not dead:
		if (remainingMovement <= 0):
			Global.mapUnits[unit.mapUnitId].setMovementIndicatorEmpty(true)
		unit.movePoints = remainingMovement if remainingMovement >= 0 else 0
		Global.factions[unit.faction].unitPositions.erase(start)
		Global.factions[unit.faction].unitPositions[unit.position] = true
		Global.hgh.occupyCell(unit.position)
		Global.mapUnits[unit.mapUnitId].startMove(mapUnitPath)
		updateFowAroundCell(unit.position)

func takeEnemyTerritory(unitCell:Vector2i, unit:Unit) -> void:
	var faction = Global.factions[unit.faction]
	var cells = Global.hgh.getNeighbors(unitCell)
	cells.push_back(unitCell)
	for cell in cells:
		if (cell == unitCell or Global.mapData[cell].unit == null):
			Global.mapData[cell].faction = unit.faction
			$FactionControl.set_cell(cell, 1, Vector2i(0,0), unit.faction)
			$FOW.set_cell(cell, -1)
			
func updateFowAroundCell(cell:Vector2i):
	for outerCell in Global.hgh.getNeighbors(cell):
		$FOW.set_cell(outerCell, -1)
		if Global.mapData[outerCell].unit != null:
			Global.mapUnits[Global.mapData[outerCell].unit.mapUnitId].visible = true

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
	var unitPositions = $CombatUnitInit.get_used_cells()
	for pos in unitPositions:
		var mapUnit = unitScene.instantiate()
		var unit = Unit.new()
		var mapPos = $Terrain.map_to_local(pos)
		unit.position = pos
		unit.hp = 100.0
		unit.movePoints = 3
		unit.defaultMovePoints = unit.movePoints
		unit.faction = getFactionAtPos(pos)
		Global.factions[unit.faction].unitPositions[pos] = true
		unit.name = "Infantry"
		mapUnit.position = mapPos
		mapUnit.mapPosition = pos
		mapUnit.setInfo(Global.factions[unit.faction])
		Global.mapUnits[Global.mapUnitsIncId] = mapUnit
		unit.mapUnitId = Global.mapUnitsIncId
		Global.mapUnitsIncId += 1
		Global.mapData[pos].unit = unit
		Global.hgh.occupyCell(pos)
		add_child(mapUnit)
	$CombatUnitInit.clear()
	
func initMapData():
	for cell in $Terrain.get_used_cells():
		var cellData = CellData.new()
		cellData.pos = cell
		cellData.worldPos = $Terrain.map_to_local(cell)
		cellData.terrain = getTerrainAtPos(cell)
		cellData.feature = getFeatureAtPos(cell)
		cellData.movementCost = cellData.terrain.movement_cost + cellData.feature.movement_cost
		Global.mapData[cell] = cellData

func initFactionControl():
	var cells = $FactionControl.get_used_cells()
	for pos in cells:
		var cell = $FactionControl.get_cell_tile_data(pos)
		if ($Terrain.get_cell_tile_data(pos) == null):
			$FactionControl.set_cell(pos, -1)
		else:
			cell.modulate = Global.factions[getFactionAtPos(pos)].color
			Global.mapData[pos].faction = getFactionAtPos(pos)
			
func getFactionAtPos(pos):
	var tileData = $FactionControl.get_cell_tile_data(pos)
	return 0 if tileData == null else tileData.get_custom_data("factionId")
	
func getTerrainAtPos(pos):
	var tileData = $Terrain.get_cell_tile_data(pos)
	return Global.terrain["NONE"] if tileData == null else Global.terrain[tileData.get_custom_data("name")]
	
func getFeatureAtPos(pos):
	var tileData = $Features.get_cell_tile_data(pos)
	return Global.terrain["NONE"] if tileData == null else Global.terrain[tileData.get_custom_data("name")]
	
func cellContainsEnemyUnit(pos):
	return Global.mapData.has(pos) and Global.mapData[pos].unit != null and selectedUnit != null and Global.mapData[pos].unit.faction != selectedUnit.faction
	
func cellContainsFriendlyUnit(pos):
	return Global.mapData.has(pos) and Global.mapData[pos].unit != null and selectedUnit != null and Global.mapData[pos].unit.faction == selectedUnit.faction
	
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
			$FOW.set_cell(cell.pos, 0, Vector2i(0,0))
			if cell.unit != null:
				Global.mapUnits[cell.unit.mapUnitId].visible = false
		else:
			$FOW.set_cell(cell.pos, -1)
			if cell.unit != null:
				Global.mapUnits[cell.unit.mapUnitId].visible = true
				
	for unitPos in Global.factions[player].unitPositions:
		var unit = Global.mapData[unitPos].unit
		for innerCell in Global.hgh.getNeighbors(unit.position):
			for outerCell in Global.hgh.getNeighbors(innerCell):
				$FOW.set_cell(outerCell, -1)
				if Global.mapData[outerCell].unit != null:
					Global.mapUnits[Global.mapData[outerCell].unit.mapUnitId].visible = true

func nextTurnUnitSetup(player:int):
	for id in Global.mapUnits:
		var cell = Global.mapUnits[id].mapPosition
		var unit = Global.mapData[cell].unit
		if unit.faction == player:
			unit.movePoints = unit.defaultMovePoints
			Global.mapUnits[id].setMovementIndicatorVisible(true)
			Global.mapUnits[id].setMovementIndicatorEmpty(false)
		else:
			Global.mapUnits[id].setMovementIndicatorVisible(false)
		

func nextTurn():
	for cell in Global.factions[Global.currentPlayer].unitPositions:
		var unit = Global.mapData[cell].unit
		if not unit.movePath.is_empty():
			moveUnit(unit, unit.position)
	
	Global.turn += 1
	Global.currentPlayer = (Global.currentPlayer) % (Global.factions.size() - 1) + 1
	
	nextTurnFogOfWar(Global.currentPlayer)
	nextTurnUnitSetup(Global.currentPlayer)
	
	next_turn.emit()

func _on_button_pressed() -> void:
	$FactionControl.visible = !$FactionControl.visible

func _on_click_handler_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			$Highlight.clear()
			hoverPath = []
			var global_clicked = get_global_mouse_position()
			var pos_clicked = $Terrain.local_to_map(global_clicked)
			clickedCell = pos_clicked
			if (Global.mapData.has(pos_clicked)):
				if (selectedUnit != null and not cellContainsFriendlyUnit(pos_clicked)):
					clickMove(pos_clicked)
					clearHighlights()
				else:
					selectUnit(pos_clicked)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
			clearHighlights()


func _on_button_2_pressed() -> void:
	nextTurn()
