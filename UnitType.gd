extends Resource

class_name UnitType

var sprite:Texture2D
var name:String
var uiName:String
var hp:float
var advantageVersus:Array[String] # names of the unit types this unit has an advantage against
var movementPoints:int

func _init(_sprite:Texture2D, _name:String, _hp:float, _advantageVersus:Array[String], _movementPoints:int, _uiName:String):
	self.sprite = _sprite
	self.name = _name
	self.hp = _hp
	self.advantageVersus = _advantageVersus
	self.movementPoints = _movementPoints
	self.uiName = _uiName
