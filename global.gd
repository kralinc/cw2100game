extends Node

signal take_enemy_territory(cell:Vector2i)

var mapUnitsIncId = 0
var hgh:HGH
var mapData:Dictionary
var mapUnits:Dictionary
var factions:Dictionary
var terrain:Dictionary
var unitTypes:Dictionary
var currentPlayer:int = 1

var turn = 1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	setupFactions()
	setupTerrain()
	setupUnitTypes()

func setupFactions():
	var none = Faction.new()
	none.fullName = "Neutral"
	none.color = Color(0,0,0)
	none.flag = load("res://icon.svg")
	factions[0] = none
	
	var usa = Faction.new()
	usa.fullName = "United States of America"
	usa.color = Color(0,0,1)
	usa.flag = load("res://assets/usaflagtest.png")
	factions[1] = usa
	
	var csa = Faction.new()
	csa.fullName = "Kingdom of America"
	csa.color = Color(0.4, 0.4, 0.4)
	csa.flag = load("res://assets/koaflag.png")
	factions[2] = csa
	
	var wf = Faction.new()
	wf.fullName = "Western Forces"
	wf.color = Color(0,1,0.5)
	wf.flag = load("res://assets/wfflag.png")
	factions[3] = wf
	
	var can = Faction.new()
	can.fullName = "Canada"
	can.color = Color(0.83,0.15,0.1)
	can.flag = load("res://assets/canadaflag.png")
	factions[4] = can

func setupTerrain():
	terrain["plains"] = TerrainData.new("plains", "Plains", 1)
	terrain["hills"] = TerrainData.new("hills", "Hills", 2)
	terrain["desert"] = TerrainData.new("desert", "Desert", 1)
	terrain["city"] = TerrainData.new("city", "City", 0)
	terrain["forest"] = TerrainData.new("forest", "Forest", 2)
	terrain["water"] = TerrainData.new("water", "Water", 3)
	terrain["NONE"] = TerrainData.new(".", ".", 0)
	
func setupUnitTypes():
	unitTypes["infantry"] = UnitType.new("res://assets/soldier.png", "infantry", 100, "artillery", 3)
	unitTypes["tank"] = UnitType.new("res://assets/tank.png", "tank", 90, "infantry", 4)
	unitTypes["artillery"] = UnitType.new("res://assets/artillery.png", "artillery", 110, "tank", 2)

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
		factions[combatResult.attackerUnit.faction].unitPositions.erase(combatResult.attackerCell.pos)
		mapUnits[combatResult.attackerUnit.mapUnitId].destroySelf()
		mapUnits.erase(combatResult.attackerUnit.mapUnitId)
		combatResult.attackerCell.unit = null
		
	if (combatResult.defenderDead):
		factions[combatResult.defenderUnit.faction].unitPositions.erase(combatResult.defenderCell.pos)
		mapUnits[combatResult.defenderUnit.mapUnitId].destroySelf()
		mapUnits.erase(combatResult.defenderUnit.mapUnitId)
		if (combatResult.attackerDead):
			combatResult.defenderCell.unit = null
