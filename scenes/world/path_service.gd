class_name PathService
extends Node

@export var navigation_region: NavigationRegion3D

func get_world_path(from_position: Vector3, to_position: Vector3) -> PackedVector3Array:
	if navigation_region == null:
		push_warning("PathService : aucun NavigationRegion3D assigné.")
		return PackedVector3Array()

	var navigation_map := navigation_region.get_navigation_map()
	if not navigation_map.is_valid():
		push_warning("PathService : la navigation map est invalide.")
		return PackedVector3Array()

	return NavigationServer3D.map_get_path(
		navigation_map,
		from_position,
		to_position,
		true
	)

func get_path_length(path: PackedVector3Array) -> float:
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length

func truncate_path_to_length(path: PackedVector3Array, max_length: float) -> PackedVector3Array:
	if path.is_empty() or max_length <= 0.0:
		return PackedVector3Array()

	var truncated := PackedVector3Array()
	truncated.append(path[0])

	var remaining_length := max_length
	for i in range(1, path.size()):
		var segment_start := path[i - 1]
		var segment_end := path[i]
		var segment_length := segment_start.distance_to(segment_end)
		if segment_length <= remaining_length:
			truncated.append(segment_end)
			remaining_length -= segment_length
			continue

		var t := remaining_length / segment_length
		truncated.append(segment_start.lerp(segment_end, t))
		return truncated

	return truncated
