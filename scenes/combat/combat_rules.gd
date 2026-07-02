class_name CombatRules
extends RefCounted

static func get_manhattan_distance(from_cell: Vector2i, to_cell: Vector2i) -> int:
	return abs(to_cell.x - from_cell.x) + abs(to_cell.y - from_cell.y)

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

static func is_adjacent(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	return get_manhattan_distance(from_cell, to_cell) <= 1

static func get_step_toward(
	from_cell: Vector2i,
	target_cell: Vector2i,
	grid: CombatGrid,
	pm_available: int
) -> Vector2i:
	var current_cell := from_cell
	var remaining_pm := pm_available

	while remaining_pm > 0 and not is_adjacent(current_cell, target_cell):
		var best_cell := current_cell
		var best_distance := get_manhattan_distance(current_cell, target_cell)

		for candidate in _get_cardinal_neighbors(current_cell):
			if not grid.is_cell_free(candidate.x, candidate.y):
				continue
			var candidate_distance := get_manhattan_distance(candidate, target_cell)
			if candidate_distance < best_distance:
				best_cell = candidate
				best_distance = candidate_distance

		if best_cell == current_cell:
			break

		current_cell = best_cell
		remaining_pm -= 1

	return current_cell

static func _get_cardinal_neighbors(cell: Vector2i) -> Array[Vector2i]:
	return [
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x, cell.y + 1),
		Vector2i(cell.x, cell.y - 1),
	]
