extends Resource

class_name CombatHelper
	
static func getCombatData(attackerCell:CellData, defenderCell:CellData) -> CombatData:
	var data:CombatData = CombatData.new()
	data.attackerCell = attackerCell
	data.defenderCell = defenderCell
	
	data.attackerMinDamage = 40
	data.attackerMaxDamage = 50
	data.defenderMinDamage = 40
	data.defenderMaxDamage = 50

	data.attackerMaxDamage += ((defenderCell.movementCost - 1) * 7) #Terrain advantage for defender

	var numAdjacentAttacker = getNumAdjacentFriendlyUnits(attackerCell.unit)
	var numAdjacentDefender = getNumAdjacentFriendlyUnits(defenderCell.unit)
	
	data.attackerMaxDamage *= 1 + (numAdjacentDefender * 0.2)
	data.defenderMaxDamage *= 1 + (numAdjacentAttacker * 0.2)

	if attackerCell.unit.hasAdvantageAgainst(defenderCell.unit):
		data.defenderMinDamage *= 1.3
		data.defenderMaxDamage *= 1.3
		data.attackerMinDamage *= 0.5
	elif defenderCell.unit.hasAdvantageAgainst(attackerCell.unit):
		data.attackerMinDamage *= 1.3
		data.attackerMaxDamage *= 1.3
		data.defenderMinDamage *= 0.5

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

	Global.mapUnits[attackerCell.unit.mapUnitId].showHitNumber(result.attackerDamage)
	Global.mapUnits[defenderCell.unit.mapUnitId].showHitNumber(result.defenderDamage)

	result.attackerDead = (attackerCell.unit.hp < 0)
	result.defenderDead = (defenderCell.unit.hp < 0)
	return result
