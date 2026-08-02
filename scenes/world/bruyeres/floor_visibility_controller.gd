class_name FloorVisibilityController
extends Node

const NAVIGATION_HEIGHT_EPSILON := 0.01

@export var height_reference: Node3D
@export var niveau_rez: Node3D
@export var niveau_etage: Node3D
@export var escalier: Node3D
@export var toit: Node3D
@export var stair_foot: CollisionShape3D
@export var stair_ramp: CollisionShape3D
@export var stair_landing: CollisionShape3D
@export var upper_floor_show_height := 2.2
@export var upper_floor_hide_height := 1.8
@export var navigation_transition_margin := 0.1

var _player: Node3D
var _is_upper_floor_visible := false
var _has_applied_state := false

func is_upper_floor_visible() -> bool:
	return _is_upper_floor_visible

func is_navigation_point_clickable(world_point: Vector3) -> bool:
	if _is_upper_floor_visible or height_reference == null:
		return true
	if _is_stair_transition_point(world_point):
		return true

	var local_height := height_reference.to_local(world_point).y
	return local_height < upper_floor_hide_height - NAVIGATION_HEIGHT_EPSILON

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return

	if height_reference == null:
		return

	var player_local_y := height_reference.to_local(_player.global_position).y
	var should_show_upper_floor := _is_upper_floor_visible
	if _is_upper_floor_visible:
		if (
			player_local_y < upper_floor_hide_height
			and not is_equal_approx(player_local_y, upper_floor_hide_height)
		):
			should_show_upper_floor = false
	elif (
		player_local_y >= upper_floor_show_height
		or is_equal_approx(player_local_y, upper_floor_show_height)
	):
		should_show_upper_floor = true

	_apply_floor_visibility(should_show_upper_floor)

func _apply_floor_visibility(show_upper_floor: bool) -> void:
	if _has_applied_state and _is_upper_floor_visible == show_upper_floor:
		return

	_has_applied_state = true
	_is_upper_floor_visible = show_upper_floor

	if niveau_rez != null:
		niveau_rez.show()
	if escalier != null:
		escalier.show()
	if niveau_etage != null:
		niveau_etage.visible = show_upper_floor
	if toit != null:
		toit.hide()

func _is_stair_transition_point(world_point: Vector3) -> bool:
	return (
		_is_point_over_shape(world_point, stair_foot)
		or _is_point_over_shape(world_point, stair_ramp)
		or _is_point_over_shape(world_point, stair_landing)
	)

func _is_point_over_shape(world_point: Vector3, collision_shape: CollisionShape3D) -> bool:
	if collision_shape == null or not collision_shape.shape is BoxShape3D:
		return false

	var box_shape := collision_shape.shape as BoxShape3D
	var local_point := collision_shape.to_local(world_point)
	var half_size := box_shape.size * 0.5
	return (
		absf(local_point.x) <= half_size.x + navigation_transition_margin
		and absf(local_point.z) <= half_size.z + navigation_transition_margin
	)
