extends Node

signal take_enemy_territory(cell:Vector2i)

var MAP_NAME = "largetest"
var humanPlayers:Dictionary = {1: true}

var mapScene:PackedScene
var mapUnitsIncId = 0
var hgh:HGH
var mapData:Dictionary
var mapUnits:Dictionary
var factions:Dictionary
var factionsList:Array = [] # for turn-taking
var terrain:Dictionary
var unitTypes:Dictionary
var currentPlayer:int = 1
var currentPlayerIterator:int = 0
var numImportantTiles:int = 0
var specialNames:Dictionary
var cellHighlightColors:Array = [Color(1, 0.8, 0, 1), Color(1, 0, 0, 1), Color(0, 0.5, 1, 1), Color(1, 0, 0, 0.5)]

var spectatorMode:bool = false
var spectatorTurn:bool = false

var turn = 1
var intraTurnCounter = 0
var turnsUntilReinforcement = 10
var reinforcementModeCounter = 0
var interactionState:String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	setupMap()
	setupFactions()
	setupTerrain()
	setupUnitTypes()
	setupSpecialNames()

func setupMap():
	var mapNameAsset = "res://maps/%s/%s.tscn" % [MAP_NAME, MAP_NAME]
	mapScene = load(mapNameAsset)

func setupFactions():
	var neutral = Faction.new()
	neutral.fullName = "Neutral"
	neutral.color = Color(0,0,0,0)
	neutral.flag = load("res://icon.svg")
	factions[0] = neutral

	var file = FileAccess.open("res://maps/%s/factions.json" % [MAP_NAME], FileAccess.READ)
	if not file:
		print("Could not open factions file. Reverting to default factions.")
		file = FileAccess.open("res://maps/common_data/factions.json", FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if (parse_result != OK):
		print("Error parsing JSON: ", json.get_error_message())
		return

	for i in range(json.data.size()):
		var faction_data = json.data[i]
		var faction = Faction.new()
		faction.id = faction_data.id
		faction.fullName = faction_data.fullName
		faction.color = Color(faction_data.color[0], faction_data.color[1], faction_data.color[2])
		if FileAccess.file_exists("res://maps/%s/assets/flags/%s" % [MAP_NAME, faction_data.flag]):
			faction.flag = load("res://maps/%s/assets/flags/%s" % [MAP_NAME, faction_data.flag])
		else:
			faction.flag = load("res://maps/common_data/assets/flags/%s" % faction_data.flag)
		factions[i + 1] = faction  # Start IDs at 1 instead of 0 due to hardcoded neutral faction
	

func setupTerrain():
	terrain["plains"] = TerrainData.new("plains", "Plains", 1)
	terrain["hills"] = TerrainData.new("hills", "Hills", 2)
	terrain["desert"] = TerrainData.new("desert", "Desert", 1)
	terrain["city"] = TerrainData.new("city", "City", 0)
	terrain["forest"] = TerrainData.new("forest", "Forest", 2)
	terrain["water"] = TerrainData.new("water", "Water", 3)
	terrain["NONE"] = TerrainData.new(".", ".", 0)
	
func setupUnitTypes():
	var file = FileAccess.open("res://maps/%s/units.json" % [MAP_NAME], FileAccess.READ)
	if not file:
		print("Could not open units file. Reverting to default units.")
		file = FileAccess.open("res://maps/common_data/units.json", FileAccess.READ)

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if (parse_result != OK):
		print("Error parsing JSON: ", json.get_error_message())
		return

	for key in json.data.keys():
		var unit_data = json.data[key]

		var texturePath = ""
		if FileAccess.file_exists("res://maps/%s/assets/units/%s" % [MAP_NAME, unit_data.texture]):
			texturePath = "res://maps/%s/assets/units/%s" % [MAP_NAME, unit_data.texture]
		else:
			texturePath = "res://maps/common_data/assets/units/%s" % unit_data.texture

		unitTypes[key] = UnitType.new(texturePath, key, unit_data.hp, unit_data.advantageVersus, unit_data.movement, unit_data.uiName)

func getEmptyCell(pos):
	var emptyCell = CellData.new()
	emptyCell.pos = pos
	emptyCell.worldPos = Vector2(0,0)
	emptyCell.terrain = terrain["NONE"]
	emptyCell.feature = terrain["NONE"]
	emptyCell.faction = 0
	emptyCell.movementCost = 0
	return emptyCell
	
	
func processDeaths(combatResult:CombatResult) -> void:
	if (combatResult == null):
		return
		
	if (combatResult.attackerDead):
		destroyUnit(combatResult.attackerCell.pos)
		
	if (combatResult.defenderDead):
		destroyUnit(combatResult.defenderCell.pos)

func setupSpecialNames():
	var file = FileAccess.open("res://maps/%s/specialnames.json" % [MAP_NAME], FileAccess.READ)
	if not file:
		print("Could not open special names file.")
		return
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if (parse_result != OK):
		print("Error parsing JSON: ", json.get_error_message())
		return

	for key in json.data.keys():
		var splitCoords  = key.split(",")
		var cell = Vector2i(splitCoords[0].to_int(), splitCoords[1].to_int())
		var tileName = json.data[key]
		if (tileName != ""):
			specialNames[cell] = tileName

func getNextFactionId():
	if currentPlayer == 0 and spectatorMode and spectatorTurn:
		spectatorTurn = false
		return factionsList[0]
	currentPlayerIterator += 1
	var nextFactionId = currentPlayerIterator % factionsList.size()
	if nextFactionId == 0 and spectatorMode and not spectatorTurn:
		spectatorTurn = true
		return 0
	else:
		return factionsList[nextFactionId]


func cellAroundImportantTile(cell:Vector2i):
	if mapData[cell].important:
		return true
	
	for neighbor in hgh.getNeighbors(cell):
		if mapData[neighbor].important:
			return true
	return false

func getReinforcementCount():
	var faction:Faction = factions[currentPlayer]
	return (faction.importantTiles.size())/2 + 3

func destroyUnit(cell:Vector2i):
	if mapData[cell].unit != null:
		var unit = mapData[cell].unit
		factions[unit.faction].unitPositions.erase(cell)
		mapUnits[unit.mapUnitId].destroySelf()
		mapUnits.erase(unit.mapUnitId)
		hgh.setCellOccupied(cell, false)
		mapData[cell].unit = null

func updateUnitPosition(unit:Unit, newPos:Vector2i):
	if unit.position != newPos:
		hgh.setCellOccupied(unit.position, false)
		mapData[unit.position].unit = null
		factions[unit.faction].unitPositions.erase(unit.position)

		hgh.setCellOccupied(newPos, true)
		mapData[newPos].unit = unit
		factions[unit.faction].unitPositions[newPos] = true
		mapUnits[unit.mapUnitId].mapPosition = newPos

		unit.position = newPos
		
		
func cellContainsEnemyUnit(pos):
	return mapData.has(pos) and mapData[pos].unit != null and mapData[pos].unit.faction != currentPlayer
	
func cellContainsFriendlyUnit(pos):
	return mapData.has(pos) and mapData[pos].unit != null and mapData[pos].unit.faction == currentPlayer