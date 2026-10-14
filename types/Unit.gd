extends Resource

class_name Unit

var type:UnitType
var hp:float
var movePoints:int
var faction:int
var position:Vector2i
var movePath:Array
var mapUnitId:int
var outOfSupply:bool = false

func hasAdvantageAgainst(other:Unit):
	return type.advantageVersus.has(other.type.name)
