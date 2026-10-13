extends Node

signal take_enemy_territory(cell:Vector2i)

var humanPlayers:Dictionary = {}

var mapDir:String
var mapEntries:Array = []
var mapFactionEntries:Array[Dictionary] = []
var mapUnitsIncId = 0
var hgh:HGH
var mapData:Dictionary
var mapUnits:Dictionary
var factions:Dictionary
var factionsList:Array = [] # for turn-taking
var terrain:Dictionary[String, TerrainData]
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
	return

func setupGameData(dir:String, factionControlModes:Dictionary):
	setupMap(dir)
	factions = setupFactions(dir)
	setupTerrain()
	setupUnitTypes(dir)
	setupSpecialNames(dir)
	setupFactionControl(factionControlModes)

func setupMap(dir:String):
	mapDir = dir
	mapEntries = MapLoadHelper.load_map_data(dir)

func setupFactions(dir:String) -> Dictionary:
	var factionsDict:Dictionary = {}
	var neutral = Faction.new()
	neutral.fullName = "Neutral"
	neutral.color = Color(0,0,0,0)
	neutral.flag = load("res://icon.svg")
	factionsDict[0] = neutral

	mapFactionEntries = MapLoadHelper.parse_faction_data(dir)
	var mapFactions:Dictionary[int, Faction] = MapLoadHelper.create_faction_info_from_faction_data(mapFactionEntries)
	for factionId in mapFactions:
		var faction:Faction = mapFactions[factionId]
		if faction.flag == null:
			faction.flag = load("res://icon.svg")
		factionsDict[factionId] = faction
	return factionsDict
	

func setupTerrain():
	terrain["grass"] = TerrainData.new("grass", "Plains", 1)
	terrain["mountain"] = TerrainData.new("mountain", "Hills", 2)
	terrain["desert"] = TerrainData.new("desert", "Desert", 1)
	terrain["city"] = TerrainData.new("city", "City", 0)
	terrain["forest"] = TerrainData.new("forest", "Forest", 2)
	terrain["water"] = TerrainData.new("water", "Water", 3)
	terrain["snow"] = TerrainData.new("snow", "Snow", 2)
	terrain["NONE"] = TerrainData.new(".", ".", 0)
	
func setupUnitTypes(dir:String) -> void:
	var unitsPath = dir.path_join("units.json")
	if not FileAccess.file_exists(unitsPath):
		print("Could not open units file. Reverting to default units.")
		unitsPath = "res://maps/common_data/units.json"
	var file = FileAccess.open(unitsPath, FileAccess.READ)

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if (parse_result != OK):
		print("Error parsing JSON: ", json.get_error_message())
		return

	for key in json.data.keys():
		var unit_data = json.data[key]

		# TODO: custom unit textures from the map folder are pending map-editor support
		var texturePath = "res://maps/common_data/assets/units/%s" % unit_data.texture

		unitTypes[key] = UnitType.new(texturePath, key, unit_data.hp, unit_data.advantageVersus, unit_data.movement, unit_data.uiName)

func setupFactionControl(factionControlModes:Dictionary):
	humanPlayers = {}
	for factionId in factionControlModes.keys():
		if (factionControlModes[factionId] == true):
			humanPlayers[factionId] = true


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

func setupSpecialNames(dir:String) -> void:
	var file = FileAccess.open(dir.path_join("specialnames.json"), FileAccess.READ)
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
	return floor(faction.importantTiles.size()/2.0) + 3

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
