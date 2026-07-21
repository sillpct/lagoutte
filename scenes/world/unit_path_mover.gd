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

	for i in range(1, path.size()):
		if _cancel_requested:
			return _finish_move(false)
		if unit == null or not is_instance_valid(unit):
			return _finish_move(false)

		var target_position := Vector3(path[i].x, unit.global_position.y, path[i].z)
		while is_instance_valid(unit):
			if _cancel_requested:
				return _finish_move(false)
			var current_position := unit.global_position
			target_position.y = current_position.y
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
	unit.global_position = Vector3(final_path_point.x, unit.global_position.y, final_path_point.z)
	return _finish_move(true)

func cancel_current_move() -> void:
	if is_moving:
		_cancel_requested = true

func _finish_move(success: bool) -> bool:
	is_moving = false
	_cancel_requested = false
	return success
