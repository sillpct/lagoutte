extends Node3D

@export var target: Node3D
@export var scripted_sequence_manager: ScriptedSequenceManager

@export var follow_speed: float = 8.0

@export var rotation_sensitivity: float = 0.01
@export var keyboard_rotation_speed: float = 1.8
@export var keyboard_pan_speed: float = 8.0
@export var zoom_step: float = 2.0
@export var min_zoom_size: float = 8.0
@export var max_zoom_size: float = 32.0

var _is_rotating := false
var _is_free := false
var _is_scripted_camera := false
var _default_basis: Basis
var _default_camera_size := 20.0

@onready var _camera: Camera3D = $IsoCamera

func _ready() -> void:
	_default_basis = basis
	if _camera != null:
		_default_camera_size = _camera.size

func _process(delta: float) -> void:

	if target != null and not _is_free and not _is_scripted_camera:
		global_position = global_position.lerp(
			target.global_position,
			follow_speed * delta
		)
	if _is_scripted_camera or _is_sequence_running():
		return
	_update_keyboard_rotation(delta)
	_update_keyboard_pan(delta)

func _unhandled_input(event: InputEvent) -> void:
	if _is_scripted_camera or _is_sequence_running():
		return

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
	_is_free = false
	_is_scripted_camera = false
	basis = _default_basis
	if target != null:
		global_position = target.global_position
	if _camera != null:
		_camera.size = _default_camera_size

func begin_scripted_camera() -> void:
	_is_rotating = false
	_is_free = true
	_is_scripted_camera = true

func set_scripted_view(pivot_position: Vector3, rotation_y: float, zoom_size: float) -> void:
	if not _is_scripted_camera:
		begin_scripted_camera()
	global_position = pivot_position
	rotation.y = rotation_y
	if _camera != null:
		_camera.size = clampf(zoom_size, min_zoom_size, max_zoom_size)

func end_scripted_camera_restore() -> void:
	_is_scripted_camera = false
	recenter_camera()

func _zoom(size_delta: float) -> void:
	if _camera == null:
		return
	_camera.size = clampf(_camera.size + size_delta, min_zoom_size, max_zoom_size)

func _update_keyboard_rotation(delta: float) -> void:
	var rotation_input := 0.0
	if Input.is_action_pressed("ui_left"):
		rotation_input += 1.0
	if Input.is_action_pressed("ui_right"):
		rotation_input -= 1.0
	if is_zero_approx(rotation_input):
		return
	rotate_y(rotation_input * keyboard_rotation_speed * delta)

func _update_keyboard_pan(delta: float) -> void:
	var pan_input := 0.0
	if Input.is_action_pressed("ui_up"):
		pan_input += 1.0
	if Input.is_action_pressed("ui_down"):
		pan_input -= 1.0
	if is_zero_approx(pan_input):
		return

	_is_free = true
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	global_position += forward * pan_input * keyboard_pan_speed * delta

func _is_sequence_running() -> bool:
	return scripted_sequence_manager != null and scripted_sequence_manager.is_sequence_active()
