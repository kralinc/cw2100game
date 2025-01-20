extends Resource

class_name CombatHelper
	
static func getCombatData(attackerCell:CellData, defenderCell:CellData) -> CombatData:
	var data:CombatData = CombatData.new()
	data.attackerCell = attackerCell
	data.defenderCell = defenderCell
	
	data.attackerMinDamage = 5
	data.attackerMaxDamage = 60
	data.defenderMinDamage = 5
	data.defenderMaxDamage = 60
		
	data.attackerMaxDamage *= (1 + (defenderCell.movementCost - 1 ) / 3) #Terrain advantage for defender

	var numAdjacentAttacker = getNumAdjacentFriendlyUnits(attackerCell.unit)
	var numAdjacentDefender = getNumAdjacentFriendlyUnits(defenderCell.unit)
	
	data.attackerMaxDamage += numAdjacentDefender * 7
	data.defenderMaxDamage += numAdjacentAttacker * 7
	
	if attackerCell.unit.hasAdvantageAgainst(defenderCell.unit):
		data.defenderMinDamage *= 1.2
		data.defenderMaxDamage *= 1.2
	elif defenderCell.unit.hasAdvantageAgainst(attackerCell.unit):
		data.attackerMinDamage *= 1.2
		data.attackerMaxDamage *= 1.2

	return data

static func getNumAdjacentFriendlyUnits(unit:Unit):
	var numAdjacent = 0
	var neighbors = Global.hgh.getNeighbors(unit.position)
	for neighbor in neighbors:
		if Global.mapData[neighbor].unit != null and Global.mapData[neighbor].unit.faction == unit.faction:
			numAdjacent = numAdjacent + 1
	return numAdjacent

static func attack(attackerCell:CellData, defenderCell:CellData) -> CombatResult:
	Global.mapUnits[attackerCell.unit.mapUnitId].doAttackAnimation()
	Global.mapUnits[defenderCell.unit.mapUnitId].doAttackAnimation()
	var combatData = getCombatData(attackerCell, defenderCell)
	
	var result = CombatResult.new()
	result.attackerCell = attackerCell
	result.defenderCell = defenderCell
	result.attackerUnit = attackerCell.unit
	result.defenderUnit = defenderCell.unit
	result.attackerDamage = randf_range(combatData.attackerMinDamage, combatData.attackerMaxDamage)
	result.defenderDamage = randf_range(combatData.defenderMinDamage, combatData.defenderMaxDamage)
	attackerCell.unit.hp -= result.attackerDamage
	defenderCell.unit.hp -= result.defenderDamage
	
	result.attackerDead = (attackerCell.unit.hp < 0)
	result.defenderDead = (defenderCell.unit.hp < 0)
	return result
