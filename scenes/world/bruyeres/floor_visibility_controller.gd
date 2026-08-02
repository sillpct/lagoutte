class_name FloorVisibilityController
extends Node

@export var height_reference: Node3D
@export var niveau_rez: Node3D
@export var niveau_etage: Node3D
@export var escalier: Node3D
@export var toit: Node3D
@export var upper_floor_show_height := 3.8
@export var upper_floor_hide_height := 3.5

var _player: Node3D
var _is_upper_floor_visible := false
var _has_applied_state := false

func is_upper_floor_visible() -> bool:
	return _is_upper_floor_visible

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
