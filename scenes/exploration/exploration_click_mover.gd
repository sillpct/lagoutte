class_name ExplorationClickMover
extends Node

@export var combat_manager: CombatManager
@export var world_mouse_query: WorldMouseQuery
@export var path_service: PathService
@export var unit_path_mover: UnitPathMover
@export var player: Node3D
@export var movement_speed := 5.5

var _move_request_id := 0
var _is_click_move_active := false

func _ready() -> void:
	if (
		combat_manager == null
		or world_mouse_query == null
		or path_service == null
		or unit_path_mover == null
		or player == null
	):
		push_warning("ExplorationClickMover a besoin du combat manager, WorldMouseQuery, PathService, UnitPathMover et du joueur.")

func _unhandled_input(event: InputEvent) -> void:
	if _is_combat_running():
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var destination := world_mouse_query.get_ground_point()
			if destination == WorldMouseQuery.INVALID_WORLD_POSITION:
				return
			get_viewport().set_input_as_handled()
			_move_request_id += 1
			_start_click_move(_move_request_id, destination)

func _start_click_move(request_id: int, destination: Vector3) -> void:
	if not _has_required_references():
		return

	if unit_path_mover.is_moving:
		unit_path_mover.cancel_current_move()
		while unit_path_mover.is_moving:
			await get_tree().physics_frame
			if request_id != _move_request_id:
				return

	if request_id != _move_request_id or _is_combat_running():
		return
	if not is_instance_valid(player):
		return

	var path := path_service.get_world_path(player.global_position, destination)
	if path.size() < 2:
		return

	_is_click_move_active = true

	var moved := await unit_path_mover.move_along_path(player, path, movement_speed)

	if request_id == _move_request_id:
		_is_click_move_active = false

	if not moved and request_id == _move_request_id:
		print("Déplacement exploration interrompu.")

func _is_combat_running() -> bool:
	return combat_manager != null and combat_manager.is_combat_active()

func _has_required_references() -> bool:
	return (
		world_mouse_query != null
		and path_service != null
		and unit_path_mover != null
		and player != null
		and is_instance_valid(player)
	)
