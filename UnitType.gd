extends Resource

class_name UnitType

var sprite:Texture2D
var name:String
var uiName:String
var hp:float
var advantageVersus:String
var movementPoints:int

func _init(_sprite:String, _name:String, _hp:float, _advantageVersus:String, _movementPoints:int, _uiName:String):
	self.sprite = load(_sprite)
	self.name = _name
	self.hp = _hp
	self.advantageVersus = _advantageVersus
	self.movementPoints = _movementPoints
	self.uiName = _uiName
