extends Node2D

@export var hexColor:Color
@export var hexAlpha:float = 0.5
var mapPosition:Vector2i
var moving = false
var movePath = []
	
func _physics_process(delta: float) -> void:
	if (moving):
		moveAlongPath()

func setInfo(faction:Faction, type:UnitType):
	$Hex.modulate = faction.color
	$Hex.modulate.a = hexAlpha
	$Flag.texture = faction.flag
	$UnitSprite.texture = type.sprite

func startMove(path:PackedVector2Array) -> void:
	moving = true
	movePath = path

func moveAlongPath():
	if movePath.is_empty():
		moving = false
		return

	var targetPosition = movePath[0]

	if position.distance_to(targetPosition) > 1:
		var tween = create_tween()
		tween.tween_property(self, "position", targetPosition, 0.1)
	else:
		movePath.remove_at(0)

	if not movePath.is_empty():
		targetPosition = movePath[0]

func doAttackAnimation():
	$AttackTimer.wait_time = randf_range(0.05, 0.1)
	$AttackTimer.start()

func destroySelf():
	$AnimationPlayer.play("die")
	
func setMovementIndicatorVisible(val:bool):
	$MovementIndicator.visible = val
	
func setMovementIndicatorEmpty(val:bool):
	if val:
		$MovementIndicator.color = Color(1,0.3,0.3)
	else:
		$MovementIndicator.color = Color(0.3,1.0,0.3)

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "die":
		queue_free()


func _on_attack_timer_timeout() -> void:
	if (not $AnimationPlayer.current_animation == "die"):
		$AnimationPlayer.play("attack")
