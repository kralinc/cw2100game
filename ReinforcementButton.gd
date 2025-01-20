extends Button

@export var unitType:UnitType

signal set_selected_unit(type:UnitType)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _on_pressed() -> void:
	set_selected_unit.emit(unitType)
