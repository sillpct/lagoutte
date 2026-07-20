extends Node3D

@export var target: Node3D

@export var follow_speed: float = 8.0

@export var rotation_sensitivity: float = 0.01

var _is_rotating := false

func _process(delta: float) -> void:

	if target == null:
		return
	global_position = global_position.lerp(
		target.global_position,
		follow_speed * delta
	)

func _unhandled_input(event: InputEvent) -> void:

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_is_rotating = event.pressed
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _is_rotating:
		rotate_y(-event.relative.x * rotation_sensitivity)
		get_viewport().set_input_as_handled()
