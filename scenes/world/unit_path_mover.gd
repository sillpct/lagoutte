class_name UnitPathMover
extends Node

var is_moving := false
var _cancel_requested := false

func move_along_path(unit: Node3D, path: PackedVector3Array, speed: float) -> bool:
	if is_moving:
		push_warning("UnitPathMover : un déplacement est déjà en cours.")
		return false
	if unit == null or not is_instance_valid(unit):
		return false
	if path.size() < 2:
		return false
	if speed <= 0.0:
		push_warning("UnitPathMover : la vitesse doit être supérieure à 0.")
		return false

	is_moving = true
	_cancel_requested = false
	var navigation_y_offset := _get_navigation_y_offset(unit, path)

	for i in range(1, path.size()):
		if _cancel_requested:
			return _finish_move(false)
		if unit == null or not is_instance_valid(unit):
			return _finish_move(false)

		var target_position := _get_adjusted_path_point(path[i], navigation_y_offset)
		while is_instance_valid(unit):
			if _cancel_requested:
				return _finish_move(false)
			var current_position := unit.global_position
			var distance := current_position.distance_to(target_position)
			if is_zero_approx(distance):
				break

			var step := speed * get_physics_process_delta_time()
			if step >= distance:
				unit.global_position = target_position
				break

			unit.global_position = current_position.move_toward(target_position, step)
			await get_tree().physics_frame

	if unit == null or not is_instance_valid(unit):
		return _finish_move(false)

	var final_path_point := path[path.size() - 1]
	unit.global_position = _get_adjusted_path_point(final_path_point, navigation_y_offset)
	return _finish_move(true)

func get_adjusted_path_destination(unit: Node3D, path: PackedVector3Array) -> Vector3:
	if unit == null or not is_instance_valid(unit) or path.is_empty():
		return Vector3(INF, INF, INF)
	var navigation_y_offset := _get_navigation_y_offset(unit, path)
	return _get_adjusted_path_point(path[path.size() - 1], navigation_y_offset)

func cancel_current_move() -> void:
	if is_moving:
		_cancel_requested = true

func _get_navigation_y_offset(unit: Node3D, path: PackedVector3Array) -> float:
	return unit.global_position.y - path[0].y

func _get_adjusted_path_point(path_point: Vector3, navigation_y_offset: float) -> Vector3:
	return Vector3(path_point.x, path_point.y + navigation_y_offset, path_point.z)

func _finish_move(success: bool) -> bool:
	is_moving = false
	_cancel_requested = false
	return success
