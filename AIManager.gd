extends Resource

class_name AIManager

enum taskTypes {
	TAKE_IMPORTANT_TILE = 1,
	DEFEND_TERRITORY = 3,
	ATTACK_ENEMY = 2,
	RETREAT = 4
}


static func gatherTasks(faction:Faction) -> Array:
	print("============ Gathering tasks for faction: ", faction.fullName, " ============")
	var tasks:Array = []

	for cellId in Global.mapData.keys():
		#to start with I'm just going to have two really basic tasks: take important tiles and defend taken territory
		var cell = Global.mapData[cellId]
		if cell.important and cell.faction != faction.id:
			tasks.append({"type": taskTypes.TAKE_IMPORTANT_TILE, "target": cellId})
		elif cell.important and cell.faction == faction.id:
			tasks.append({"type": taskTypes.RETREAT, "target": cellId})
		elif cell.faction != faction.id and cell.unit != null and faction.visibleTiles.has(cellId):
			tasks.append({"type": taskTypes.ATTACK_ENEMY, "target": cellId})
		elif faction.tilesLostLastTurn.has(cellId):
			tasks.append({"type": taskTypes.DEFEND_TERRITORY, "target": cellId})

	return tasks

static func gatherAssignments(tasks:Array, faction:Faction) -> Array:
	var assignments:Array = []
	# Find the score for each task for each unit. Pick the highest scoring unit for each task.
	for task in tasks:
		for unitPosition in faction.unitPositions.keys():
			var distance = unitPosition.distance_to(task.target)
			var modifier = 0
			if task.type == taskTypes.RETREAT:
				modifier = taskTypes.size() - ((Global.mapData[unitPosition].unit.hp / Global.unitTypes[Global.mapData[unitPosition].unit.type.name].hp) * taskTypes.size())
			
			var score = (taskTypes.size() - task.type + modifier) / distance
			assignments.append({"task": task, "unit": unitPosition, "score": score})

	return assignments

static func assignTasks(assignments:Array) -> Array:
	var assignedTasks:Array = []
	# Sort assignments by score, highest first
	assignments.sort_custom(sortByScore)

	var assignedUnits:Dictionary = {}
	var allocatedTasks:Dictionary = {}
	for assignment in assignments:
		if (assignedUnits.has(assignment.unit) or allocatedTasks.has(assignment.task.target)):
			continue  # Skip if unit is already assigned
		assignedUnits[assignment.unit] = true
		allocatedTasks[assignment.task.target] = true
		assignedTasks.append({"task": assignment.task, "unit": assignment.unit})
		print("Assigned task: ", assignment.task.type, " at position:", assignment.task.target, " to unit: ", assignment.unit, " with score: ", assignment.score)
	return assignedTasks

static func placeReinforcements(faction:Faction):
	var importantTiles = faction.importantTiles.keys()

	var availableTiles = []
	for tile in importantTiles:
		if Global.mapData[tile].unit == null:
			availableTiles.append(tile)
		for neighbor in Global.hgh.getNeighbors(tile):
			if Global.mapData[neighbor].unit == null and Global.mapData[neighbor].faction == faction.id:
				availableTiles.append(neighbor)

	availableTiles.shuffle()
	var reinforcementCount = Global.getReinforcementCount()
	var unitsToCreate :Array = []
	for i in range(reinforcementCount):
		var numUnitTypes = Global.unitTypes.size()
		var unitType = Global.unitTypes.values()[randi() % numUnitTypes]
		var tile = availableTiles.pop_front()
		unitsToCreate.append({"position": tile, "type": unitType})
	return unitsToCreate
		


static func sortByScore(a, b):
	return a.score > b.score
