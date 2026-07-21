class_name UnitPathMover
extends Node

@export var path_service: PathService

@export var enable_debug_move := false
@export var debug_unit: Node3D
@export var debug_destination := Vector3.ZERO
@export var debug_speed := 3.0
@export var debug_action := "test_path_move"

var is_moving := false

func _unhandled_input(event: InputEvent) -> void:
	if not enable_debug_move:
		return
	if event.is_action_pressed(debug_action):
		get_viewport().set_input_as_handled()
		_start_debug_move()

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

	for i in range(1, path.size()):
		if unit == null or not is_instance_valid(unit):
			is_moving = false
			return false

		var target_position := Vector3(path[i].x, unit.global_position.y, path[i].z)
		while is_instance_valid(unit):
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
		is_moving = false
		return false

	var final_path_point := path[path.size() - 1]
	unit.global_position = Vector3(final_path_point.x, unit.global_position.y, final_path_point.z)
	is_moving = false
	return true

func _start_debug_move() -> void:
	if path_service == null:
		push_warning("UnitPathMover : aucun PathService assigné pour le test.")
		return
	if debug_unit == null or not is_instance_valid(debug_unit):
		push_warning("UnitPathMover : aucune unité de test assignée.")
		return
	if is_moving:
		print("UnitPathMover test : déplacement déjà en cours.")
		return

	var path := path_service.get_world_path(debug_unit.global_position, debug_destination)
	print(
		"UnitPathMover test — chemin = ",
		path.size(),
		" points, longueur = ",
		path_service.get_path_length(path),
		" m"
	)

	var was_physics_processing := debug_unit.is_physics_processing()
	debug_unit.set_physics_process(false)
	var moved := await move_along_path(debug_unit, path, debug_speed)
	if is_instance_valid(debug_unit):
		debug_unit.set_physics_process(was_physics_processing)
	print("UnitPathMover test — déplacement terminé : ", moved)
