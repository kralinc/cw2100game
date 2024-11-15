extends Resource

class_name CombatHelper

static func calculateCombatProbability(attackerCell:CellData, defenderCell:CellData) -> Dictionary:
	var result:Dictionary
	result["attackerMin"] = 1.0
	result["attackerMax"] = 60.0
	result["defenderMin"] = 1.0
	result["defenderMax"] = 75.0
	return result

static func attack(attackerCell:CellData, defenderCell:CellData) -> CombatResult:
	Global.mapUnits[attackerCell.unit.mapUnitId].doAttackAnimation()
	Global.mapUnits[defenderCell.unit.mapUnitId].doAttackAnimation()
	
	var probabilities = calculateCombatProbability(attackerCell, defenderCell)
	var result = CombatResult.new()
	result.attackerCell = attackerCell
	result.defenderCell = defenderCell
	result.attackerUnit = attackerCell.unit
	result.defenderUnit = defenderCell.unit
	
	result.attackerDamage = randf_range(probabilities["attackerMin"], probabilities["attackerMax"])
	result.defenderDamage = randf_range(probabilities["defenderMin"], probabilities["defenderMax"])
	attackerCell.unit.hp -= result.attackerDamage
	defenderCell.unit.hp -= result.defenderDamage
	
	result.attackerDead = (attackerCell.unit.hp < 0)
	result.defenderDead = (defenderCell.unit.hp < 0)
	return result