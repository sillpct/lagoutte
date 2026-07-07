class_name WorldMouseQuery
extends Node

const HOVERABLE_UNIT_COLLISION_MASK := 4
const INVALID_WORLD_POSITION := Vector3(INF, INF, INF)

@export var ray_length: float = 1000.0
@export var ground_y: float = 0.0

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
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return INVALID_WORLD_POSITION

	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	if is_zero_approx(ray_direction.y):
		return INVALID_WORLD_POSITION

	var distance_to_ground_plane := (ground_y - ray_origin.y) / ray_direction.y
	if distance_to_ground_plane < 0.0:
		return INVALID_WORLD_POSITION

	return ray_origin + ray_direction * distance_to_ground_plane

func _get_unit_from_hover_collider(collider: Node) -> Node3D:
	var current := collider
	while current != null:
		if current.is_in_group("hoverable_unit"):
			return current.get_parent() as Node3D
		current = current.get_parent()
	return null
