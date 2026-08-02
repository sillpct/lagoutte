class_name WorldMouseQuery
extends Node

const HOVERABLE_UNIT_COLLISION_MASK := 4
const INVALID_WORLD_POSITION := Vector3(INF, INF, INF)
const NAVMESH_INTERSECTION_EPSILON := 0.01

@export var ray_length: float = 1000.0
@export var path_service: PathService

func get_hovered_unit() -> Node3D:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null

	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_end := ray_origin + camera.project_ray_normal(mouse_position) * ray_length
	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_end,
		HOVERABLE_UNIT_COLLISION_MASK
	)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result: Dictionary = get_viewport().world_3d.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null

	return _get_unit_from_hover_collider(result.get("collider") as Node)

func get_ground_point() -> Vector3:
	return get_ground_point_at_screen_position(get_viewport().get_mouse_position())

func get_ground_point_at_screen_position(mouse_position: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null or path_service == null:
		return INVALID_WORLD_POSITION

	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_end := ray_origin + camera.project_ray_normal(mouse_position) * ray_length
	var navigation_map := path_service.get_navigation_map()
	if not navigation_map.is_valid():
		return INVALID_WORLD_POSITION

	var intersection_point := NavigationServer3D.map_get_closest_point_to_segment(
		navigation_map,
		ray_origin,
		ray_end,
		true
	)
	if (
		_distance_to_segment(intersection_point, ray_origin, ray_end)
		> NAVMESH_INTERSECTION_EPSILON
	):
		return INVALID_WORLD_POSITION

	## Dette : la projection navmesh ne tient pas encore compte de l'occlusion
	## visuelle par un toit. À ajouter lorsqu'un cas de jeu réel l'exigera.
	return intersection_point

func _distance_to_segment(
	point: Vector3,
	segment_start: Vector3,
	segment_end: Vector3
) -> float:
	var segment := segment_end - segment_start
	var segment_length_squared := segment.length_squared()
	if is_zero_approx(segment_length_squared):
		return point.distance_to(segment_start)
	var parameter := clampf(
		(point - segment_start).dot(segment) / segment_length_squared,
		0.0,
		1.0
	)
	return point.distance_to(segment_start + segment * parameter)

func _get_unit_from_hover_collider(collider: Node) -> Node3D:
	var current := collider
	while current != null:
		if current.is_in_group("hoverable_unit"):
			return current.get_parent() as Node3D
		current = current.get_parent()
	return null
