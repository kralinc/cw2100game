extends Camera2D

var dragging = false
var prevMousePos = Vector2()
var targetPos = Vector2()
@export var camDragSpeed = 50
var zoomSpeed = 0.1
var maxZoom = 4
var minZoom = 0.2
var camLerp = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.is_pressed():
				dragging = true
				prevMousePos = event.position
			elif event.is_released():
				camLerp = 0.0
				prevMousePos = Vector2()
				dragging = false
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_out()
	elif event is InputEventMouseMotion and dragging:
		targetPos = event.position - prevMousePos
		position -= targetPos / zoom.x
		prevMousePos = event.position

func zoom_in():
	var currentZoom = zoom.x * zoomSpeed
	zoom -= Vector2(currentZoom, currentZoom)
	if zoom.x < minZoom:
		zoom = Vector2(minZoom, minZoom)

func zoom_out():
	var currentZoom = zoom.x * zoomSpeed
	zoom += Vector2(currentZoom, currentZoom)
	if zoom.x > maxZoom:
		zoom = Vector2(maxZoom,maxZoom)
