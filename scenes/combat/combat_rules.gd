class_name CombatRules
extends RefCounted

static func get_world_distance(from_position: Vector3, to_position: Vector3) -> float:
	return from_position.distance_to(to_position)

static func is_within_world_range(from_position: Vector3, to_position: Vector3, max_range: float) -> bool:
	return get_world_distance(from_position, to_position) <= max_range

static func get_world_step_toward(
	from_position: Vector3,
	target_position: Vector3,
	max_distance: float,
	stop_distance: float = 0.0
) -> Vector3:
	var direction := target_position - from_position
	var distance := direction.length()
	var safe_max_distance := maxf(0.0, max_distance)
	var safe_stop_distance := maxf(0.0, stop_distance)
	var travel_distance := minf(safe_max_distance, maxf(0.0, distance - safe_stop_distance))

	if is_zero_approx(distance) or is_zero_approx(travel_distance):
		return from_position

	return from_position + direction.normalized() * travel_distance
