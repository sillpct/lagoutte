extends Node3D

@export var target: Node3D

@export var follow_speed: float = 8.0

@export var rotation_sensitivity: float = 0.01
@export var zoom_step: float = 2.0
@export var min_zoom_size: float = 8.0
@export var max_zoom_size: float = 32.0

var _is_rotating := false
var _default_basis: Basis
var _default_camera_size := 20.0

@onready var _camera: Camera3D = $IsoCamera

func _ready() -> void:
	_default_basis = basis
	if _camera != null:
		_default_camera_size = _camera.size

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
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom(-zoom_step)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom(zoom_step)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _is_rotating:
		rotate_y(-event.relative.x * rotation_sensitivity)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("recenter_camera"):
		recenter_camera()
		get_viewport().set_input_as_handled()

func recenter_camera() -> void:
	_is_rotating = false
	basis = _default_basis
	if _camera != null:
		_camera.size = _default_camera_size

func _zoom(size_delta: float) -> void:
	if _camera == null:
		return
	_camera.size = clampf(_camera.size + size_delta, min_zoom_size, max_zoom_size)
