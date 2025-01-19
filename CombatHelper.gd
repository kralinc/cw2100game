extends Resource

class_name CombatHelper
	
static func getCombatData(attackerCell:CellData, defenderCell:CellData) -> CombatData:
	var data:CombatData = CombatData.new()
	data.attackerCell = attackerCell
	data.defenderCell = defenderCell
	
	data.attackerMinDamage = 5
	data.attackerMaxDamage = 60
	data.defenderMinDamage = 5
	data.defenderMaxDamage = 70
	
	if attackerCell.unit.hasAdvantageAgainst(defenderCell.unit):
		data.defenderMinDamage *= 1.1
		data.defenderMaxDamage *= 1.1
	elif defenderCell.unit.hasAdvantageAgainst(attackerCell.unit):
		data.attackerMinDamage *= 1.1
		data.attackerMaxDamage *= 1.1
		
	data.attackerMaxDamage *= (1 + (defenderCell.movementCost - 1 ) / 3) #Terrain advantage for defender
	
	return data

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
