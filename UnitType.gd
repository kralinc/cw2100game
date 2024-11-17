extends Resource

class_name UnitType

var sprite:Texture2D
var name:String
var hp:float
var advantageVersus:String
var movementPoints:int

func _init(sprite:String, name:String, hp:float, advantageVersus:String, movementPoints:int):
	self.sprite = load(sprite)
	self.name = name
	self.hp = hp
	self.advantageVersus = advantageVersus
	self.movementPoints = movementPoints
